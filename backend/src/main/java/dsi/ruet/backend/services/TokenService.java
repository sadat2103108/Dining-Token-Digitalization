package dsi.ruet.backend.services;

import dsi.ruet.backend.dto.token.*;
import dsi.ruet.backend.models.User;

import java.util.List;

/**
 * Service interface for meal-token operations.
 */
public interface TokenService {

    /**
     * Purchase a meal token for the authenticated student.
     * Validates deadline, wallet balance, and duplicate purchase.
     */
    TokenResponse purchaseToken(PurchaseTokenRequest request, User currentUser);

    /**
     * Get all tokens owned by the authenticated user.
     */
    List<TokenResponse> getMyTokens(User currentUser);

    /**
     * Generate a QR code for a token owned by the authenticated student.
     */
    QrResponse generateQr(Long tokenId, User currentUser);

    /**
     * Validate a scanned QR code and return token details.
     */
    QrValidationResponse validateQr(ValidateQrRequest request);

    /**
     * Mark a token as used after serving the meal.
     */
    TokenResponse markTokenUsed(Long tokenId);
}
