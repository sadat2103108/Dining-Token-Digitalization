package dsi.ruet.backend.controllers;

import dsi.ruet.backend.dto.ApiResponse;
import dsi.ruet.backend.models.*;
import dsi.ruet.backend.models.enums.TransactionType;
import dsi.ruet.backend.repositories.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

/**
 * REST controller for student-facing read endpoints.
 * Provides wallet balance, today's meals, available meals, and transaction history.
 *
 * All endpoints require STUDENT role.
 */
@RestController
@PreAuthorize("hasRole('STUDENT')")
@Transactional(readOnly = true)
public class StudentController {

    @Autowired
    private WalletRepository walletRepository;

    @Autowired
    private MealRepository mealRepository;

    @Autowired
    private CoinTransactionRepository coinTransactionRepository;

    @Autowired
    private TokenRepository tokenRepository;

    @Autowired
    private HallRepository hallRepository;

    @Autowired
    private UserRepository userRepository;

    // ==================== WALLET ====================

    /**
     * GET /students/wallet
     * Returns the authenticated student's wallet balance.
     */
    @GetMapping("/students/wallet")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getMyWallet(
            @AuthenticationPrincipal User currentUser) {

        Wallet wallet = walletRepository.findByUserId(currentUser.getId())
                .orElse(null);

        BigDecimal balance = wallet != null ? wallet.getBalance() : BigDecimal.ZERO;

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("balance", balance);

        return ResponseEntity.ok(new ApiResponse<>("Wallet retrieved successfully.", data));
    }

    // ==================== MEALS ====================

    /**
     * GET /meals/today
     * Returns today's meal configurations for the student's hall.
     */
    @GetMapping("/meals/today")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getTodayMeals(
            @AuthenticationPrincipal User currentUser) {

        User user = userRepository.findById(currentUser.getId()).orElseThrow();
        Long hallId = user.getHall().getId();
        List<Meal> meals = mealRepository.findByHallIdAndMealDate(hallId, LocalDate.now());

        List<Map<String, Object>> data = meals.stream()
                .map(this::mealToMap)
                .collect(Collectors.toList());

        return ResponseEntity.ok(new ApiResponse<>("Today's meals retrieved successfully.", data));
    }

    /**
     * GET /meals/available
     * Returns available (purchasable, non-closed) meals for the student's hall today.
     */
    @GetMapping("/meals/available")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getAvailableMeals(
            @AuthenticationPrincipal User currentUser) {

        User user = userRepository.findById(currentUser.getId()).orElseThrow();
        Long hallId = user.getHall().getId();
        List<Meal> meals = mealRepository.findByHallIdAndMealDate(hallId, LocalDate.now());

        LocalDateTime now = LocalDateTime.now();

        List<Map<String, Object>> data = meals.stream()
                .filter(m -> !Boolean.TRUE.equals(m.getIsClosed()))
                .filter(m -> m.getPurchaseDeadline() == null || now.isBefore(m.getPurchaseDeadline()))
                .map(this::mealToMap)
                .collect(Collectors.toList());

        return ResponseEntity.ok(new ApiResponse<>("Available meals retrieved successfully.", data));
    }

    // ==================== TRANSACTIONS ====================

    /**
     * GET /students/transactions
     * Returns the student's transaction history combining token purchases and wallet top-ups.
     */
    @GetMapping("/students/transactions")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getMyTransactions(
            @AuthenticationPrincipal User currentUser) {

        Long userId = currentUser.getId();
        User user = userRepository.findById(userId).orElseThrow();
        Hall hall = user.getHall();
        String hallName = hall != null ? hall.getName() : "Unknown";

        List<Map<String, Object>> transactions = new ArrayList<>();

        // --- Token-based transactions (purchases / sales) ---
        List<Token> tokens = tokenRepository.findByOwnerOrderByCreatedAtDesc(currentUser);
        for (Token token : tokens) {
            Meal meal = token.getMeal();
            String mealType = meal.getMealType() != null ? meal.getMealType().name() : "UNKNOWN";
            String tokenType = capitalize(mealType) + " Token";
            int price = meal.getPrice() != null ? meal.getPrice().intValue() : 0;

            Map<String, Object> tx = new LinkedHashMap<>();
            tx.put("status", "Purchased");
            tx.put("tokenType", tokenType);
            tx.put("date", token.getCreatedAt().toLocalDate().toString());
            tx.put("hall", hallName);
            tx.put("time", token.getCreatedAt().format(DateTimeFormatter.ofPattern("hh:mm a")));
            tx.put("amount", -price);
            tx.put("tag", "Purchased");
            tx.put("paymentMethod", "credit");
            transactions.add(tx);
        }

        // --- Wallet top-ups (received) ---
        List<CoinTransaction> topUps = coinTransactionRepository
                .findBySenderIdOrReceiverId(userId, userId);
        for (CoinTransaction ct : topUps) {
            if (ct.getType() == TransactionType.TOPUP && ct.getReceiver() != null
                    && ct.getReceiver().getId().equals(userId)) {
                Map<String, Object> tx = new LinkedHashMap<>();
                tx.put("status", "Top Up");
                tx.put("tokenType", "Wallet Top Up");
                tx.put("date", ct.getCreatedAt().toLocalDate().toString());
                tx.put("hall", hallName);
                tx.put("time", ct.getCreatedAt().format(DateTimeFormatter.ofPattern("hh:mm a")));
                tx.put("amount", ct.getAmount().intValue());
                tx.put("tag", "Top Up");
                tx.put("paymentMethod", "cash");
                transactions.add(tx);
            }
        }

        // Sort by date descending
        transactions.sort((a, b) -> {
            String dateA = (String) a.get("date");
            String dateB = (String) b.get("date");
            int cmp = dateB.compareTo(dateA);
            if (cmp != 0) return cmp;
            String timeA = (String) a.get("time");
            String timeB = (String) b.get("time");
            return timeB.compareTo(timeA);
        });

        return ResponseEntity.ok(new ApiResponse<>("Transactions retrieved successfully.", transactions));
    }

    // ==================== HELPERS ====================

    private Map<String, Object> mealToMap(Meal meal) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("id", meal.getId());
        map.put("mealType", meal.getMealType() != null ? meal.getMealType().name() : "UNKNOWN");
        map.put("menu", meal.getMenu());
        map.put("price", meal.getPrice());
        map.put("purchaseStartTime", formatDateTime(meal.getPurchaseStartTime()));
        map.put("purchaseEndTime", formatDateTime(meal.getPurchaseEndTime()));
        map.put("purchaseDeadline", formatDateTime(meal.getPurchaseDeadline()));
        map.put("date", meal.getMealDate() != null ? meal.getMealDate().toString() : null);
        map.put("isClosed", meal.getIsClosed());
        return map;
    }

    private String formatDateTime(LocalDateTime dt) {
        if (dt == null) return null;
        return dt.format(DateTimeFormatter.ofPattern("hh:mm a"));
    }

    private String capitalize(String s) {
        if (s == null || s.isEmpty()) return s;
        return s.substring(0, 1).toUpperCase() + s.substring(1).toLowerCase();
    }
}
