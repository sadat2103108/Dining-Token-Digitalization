package dsi.ruet.backend.services.impl;

import dsi.ruet.backend.dto.token.*;
import dsi.ruet.backend.exception.ResourceNotFoundException;
import dsi.ruet.backend.models.*;
import dsi.ruet.backend.models.enums.TokenStatus;
import dsi.ruet.backend.repositories.*;
import dsi.ruet.backend.services.TokenService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Implementation of {@link TokenService}.
 * Handles all token-related business logic including purchase,
 * QR generation/validation, usage tracking, and transfers.
 */
@Service
public class TokenServiceImpl implements TokenService {

    @Autowired
    private TokenRepository tokenRepository;

    @Autowired
    private MealRepository mealRepository;

    @Autowired
    private WalletRepository walletRepository;

    @Autowired
    private TokenTransactionRepository tokenTransactionRepository;

    /* ==================== 1. Purchase Token ==================== */

    @Override
    @Transactional
    public TokenResponse purchaseToken(PurchaseTokenRequest request, User currentUser) {
        // 1. Fetch the meal
        Meal meal = mealRepository.findById(request.getMealId())
                .orElseThrow(() -> new ResourceNotFoundException("Meal not found with ID: " + request.getMealId()));

        // 2. Check purchase deadline (use purchaseEndTime as fallback)
        LocalDateTime deadline = meal.getPurchaseDeadline() != null
                ? meal.getPurchaseDeadline()
                : meal.getPurchaseEndTime();
        if (deadline != null && LocalDateTime.now().isAfter(deadline)) {
            throw new IllegalStateException("Purchase deadline has passed for this meal.");
        }

        // 3. Prevent duplicate token purchase (one token per meal per user)
        if (tokenRepository.existsByOwnerAndMeal(currentUser, meal)) {
            throw new IllegalStateException("You have already purchased a token for this meal.");
        }

        // 4. Fetch wallet and check balance
        Wallet wallet = walletRepository.findByUserId(currentUser.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Wallet not found. Please contact admin."));

        if (wallet.getBalance() < meal.getPrice()) {
            throw new IllegalStateException("Insufficient wallet balance. Required: " + meal.getPrice()
                    + ", Available: " + wallet.getBalance());
        }

        // 5. Deduct wallet balance
        wallet.deduct(meal.getPrice());
        walletRepository.save(wallet);

        // 6. Create the token
        Token token = new Token();
        token.setMeal(meal);
        token.setOwner(currentUser);
        token.setStatus(TokenStatus.AVAILABLE);
        token = tokenRepository.save(token);

        // 7. Generate a unique QR code string and save it
        String qrCode = "TOKEN:" + token.getId() + ":" + UUID.randomUUID();
        token.setQrCode(qrCode);
        token = tokenRepository.save(token);

        // 8. Record the purchase as a transaction (sender = receiver = buyer for purchases)
        TokenTransaction transaction = new TokenTransaction();
        transaction.setSender(currentUser);
        transaction.setReceiver(currentUser);
        transaction.setToken(token);
        tokenTransactionRepository.save(transaction);

        // 9. Return token info
        return mapToTokenResponse(token);
    }

    /* ==================== 2. View My Tokens ==================== */

    /**
     * Returns only AVAILABLE (not yet used) tokens for the student panel.
     * Used tokens are excluded so they no longer appear in the student's view.
     */
    @Override
    public List<TokenResponse> getMyTokens(User currentUser) {
        List<Token> tokens = tokenRepository.findByOwnerOrderByCreatedAtDesc(currentUser);
        return tokens.stream()
                .filter(t -> t.getStatus() == TokenStatus.AVAILABLE)
                .map(this::mapToTokenResponse)
                .collect(Collectors.toList());
    }

    /* ==================== 3. Generate QR Code ==================== */

    @Override
    @Transactional
    public QrResponse generateQr(Long tokenId, User currentUser) {
        Token token = tokenRepository.findById(tokenId)
                .orElseThrow(() -> new ResourceNotFoundException("Token not found with ID: " + tokenId));

        // Verify token belongs to the current user
        if (!token.getOwner().getId().equals(currentUser.getId())) {
            throw new IllegalStateException("You can only generate QR codes for your own tokens.");
        }

        // Token must be ACTIVE
        if (token.getStatus() != TokenStatus.AVAILABLE) {
            throw new IllegalStateException("QR code can only be generated for AVAILABLE tokens. Current status: " + token.getStatus());
        }

        // Generate QR code string if not already generated
        if (token.getQrCode() == null || token.getQrCode().isEmpty()) {
            String qrCode = "TOKEN:" + token.getId() + ":" + UUID.randomUUID();
            token.setQrCode(qrCode);
            token = tokenRepository.save(token);
        }

        return QrResponse.builder()
                .tokenId(token.getId())
                .qrCode(token.getQrCode())
                .build();
    }

    /* ==================== 5. Validate QR Code ==================== */

    /**
     * Validates a scanned QR code.
     * Rules:
     *   - Token must have been bought the previous day (meal date = today).
     *   - LUNCH tokens are only valid from 12:01 PM to 3:00 PM.
     *   - DINNER tokens are only valid from 7:00 PM to 10:00 PM.
     *   - On successful validation the token is automatically marked as USED.
     */
    @Override
    @Transactional
    public QrValidationResponse validateQr(ValidateQrRequest request) {
        String qrData = request.getQrData();

        // Parse the QR data format: TOKEN:<id>:<uuid>
        if (qrData == null || !qrData.startsWith("TOKEN:")) {
            return QrValidationResponse.builder()
                    .valid(false)
                    .message("Invalid QR code format.")
                    .build();
        }

        // Find the token by QR code
        Token token = tokenRepository.findByQrCode(qrData).orElse(null);

        if (token == null) {
            return QrValidationResponse.builder()
                    .valid(false)
                    .message("Token not found for this QR code.")
                    .build();
        }

        // Check if already used
        if (token.getStatus() == TokenStatus.USED) {
            return QrValidationResponse.builder()
                    .valid(false)
                    .tokenId(token.getId())
                    .ownerName(token.getOwner().getName())
                    .mealType(token.getMeal().getMealType().name())
                    .mealDate(token.getMeal().getMealDate())
                    .status(token.getStatus().name())
                    .message("Token has already been used.")
                    .build();
        }

        // Check if token is active
        if (token.getStatus() != TokenStatus.AVAILABLE) {
            return QrValidationResponse.builder()
                    .valid(false)
                    .tokenId(token.getId())
                    .ownerName(token.getOwner().getName())
                    .mealType(token.getMeal().getMealType().name())
                    .mealDate(token.getMeal().getMealDate())
                    .status(token.getStatus().name())
                    .message("Token is not active. Status: " + token.getStatus())
                    .build();
        }

        Meal meal = token.getMeal();
        LocalDate today = LocalDate.now();
        LocalTime currentTime = LocalTime.now();

        // Token must be for today's meal (i.e. bought the previous day for today)
        if (!meal.getMealDate().equals(today)) {
            return QrValidationResponse.builder()
                    .valid(false)
                    .tokenId(token.getId())
                    .ownerName(token.getOwner().getName())
                    .mealType(meal.getMealType().name())
                    .mealDate(meal.getMealDate())
                    .status(token.getStatus().name())
                    .message("Token is not for today's meal. Meal date: " + meal.getMealDate())
                    .build();
        }

        // Enforce meal-type serving windows
        // LUNCH  : 12:01 PM – 3:00 PM
        // DINNER : 7:00 PM  – 10:00 PM
        if (meal.getMealType() == dsi.ruet.backend.models.enums.MealType.LUNCH) {
            LocalTime lunchStart = LocalTime.of(12, 1);   // 12:01 PM
            LocalTime lunchEnd   = LocalTime.of(15, 0);   // 3:00 PM
            if (currentTime.isBefore(lunchStart) || currentTime.isAfter(lunchEnd)) {
                return QrValidationResponse.builder()
                        .valid(false)
                        .tokenId(token.getId())
                        .ownerName(token.getOwner().getName())
                        .mealType(meal.getMealType().name())
                        .mealDate(meal.getMealDate())
                        .status(token.getStatus().name())
                        .message("Lunch tokens can only be used between 12:01 PM and 3:00 PM.")
                        .build();
            }
        } else if (meal.getMealType() == dsi.ruet.backend.models.enums.MealType.DINNER) {
            LocalTime dinnerStart = LocalTime.of(19, 0);  // 7:00 PM
            LocalTime dinnerEnd   = LocalTime.of(22, 0);  // 10:00 PM
            if (currentTime.isBefore(dinnerStart) || currentTime.isAfter(dinnerEnd)) {
                return QrValidationResponse.builder()
                        .valid(false)
                        .tokenId(token.getId())
                        .ownerName(token.getOwner().getName())
                        .mealType(meal.getMealType().name())
                        .mealDate(meal.getMealDate())
                        .status(token.getStatus().name())
                        .message("Dinner tokens can only be used between 7:00 PM and 10:00 PM.")
                        .build();
            }
        }

        // ---- Validation passed — automatically mark the token as USED ----
        token.setStatus(TokenStatus.USED);
        token.setUsedAt(LocalDateTime.now());
        tokenRepository.save(token);

        // Token is valid and has been consumed
        return QrValidationResponse.builder()
                .valid(true)
                .tokenId(token.getId())
                .ownerName(token.getOwner().getName())
                .mealType(meal.getMealType().name())
                .mealDate(meal.getMealDate())
                .status(TokenStatus.USED.name())
                .message("Token is valid. Meal served — token has been used.")
                .build();
    }

    /* ==================== 6. Mark Token as Used ==================== */

    @Override
    @Transactional
    public TokenResponse markTokenUsed(Long tokenId) {
        Token token = tokenRepository.findById(tokenId)
                .orElseThrow(() -> new ResourceNotFoundException("Token not found with ID: " + tokenId));

        // Prevent reuse
        if (token.getStatus() == TokenStatus.USED) {
            throw new IllegalStateException("Token has already been used.");
        }

        if (token.getStatus() != TokenStatus.AVAILABLE) {
            throw new IllegalStateException("Only AVAILABLE tokens can be marked as used. Current status: " + token.getStatus());
        }

        token.setStatus(TokenStatus.USED);
        token.setUsedAt(LocalDateTime.now());
        token = tokenRepository.save(token);

        return mapToTokenResponse(token);
    }

    /* ==================== Helper Methods ==================== */

    /**
     * Maps a Token entity to a TokenResponse DTO.
     */
    private TokenResponse mapToTokenResponse(Token token) {
        Meal meal = token.getMeal();
        return TokenResponse.builder()
                .id(token.getId())
                .mealId(meal.getId())
                .mealType(meal.getMealType().name())
                .mealDate(meal.getMealDate())
                .price(meal.getPrice())
                .menu(meal.getMenu())
                .status(token.getStatus().name())
                .ownerName(token.getOwner().getName())
                .createdAt(token.getCreatedAt())
                .usedAt(token.getUsedAt())
                .build();
    }

}
