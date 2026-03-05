package dsi.ruet.backend.controllers;

import dsi.ruet.backend.dto.ApiResponse;
import dsi.ruet.backend.dto.token.*;
import dsi.ruet.backend.models.User;
import dsi.ruet.backend.services.TokenService;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * REST controller for meal-token operations.
 * Exposes endpoints for purchasing tokens, viewing owned tokens,
 * generating/validating QR codes, marking tokens as used, and
 * transferring tokens between users.
 *
 * Base path: {@code /tokens}
 * Access control is enforced at the method level via {@code @PreAuthorize}.
 */
@RestController
@RequestMapping("/tokens")
public class TokenController {

    /** Service handling all token-related business logic */
    @Autowired
    private TokenService tokenService;

    /* ==================== 1. Purchase Token ==================== */

    /**
     * Purchases a meal token for the authenticated student.
     * Debits the student's wallet and creates a new ACTIVE token.
     * Restricted to users with the STUDENT role.
     *
     * @param request     the purchase request containing the meal ID
     * @param currentUser the authenticated student (injected from JWT)
     * @return the created TokenResponse (HTTP 201 Created)
     */
    @PostMapping("/purchase")
    @PreAuthorize("hasRole('STUDENT')")
    public ResponseEntity<ApiResponse<TokenResponse>> purchaseToken(
            @Valid @RequestBody PurchaseTokenRequest request,
            @AuthenticationPrincipal User currentUser) {

        TokenResponse token = tokenService.purchaseToken(request, currentUser);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(new ApiResponse<>("Token purchased successfully.", token));
    }

    /* ==================== 2. View My Tokens ==================== */

    /**
     * Retrieves all tokens owned by the authenticated student,
     * ordered by creation date (most recent first).
     * Restricted to users with the STUDENT role.
     *
     * @param currentUser the authenticated student (injected from JWT)
     * @return list of TokenResponse objects (HTTP 200 OK)
     */
    @GetMapping("/me")
    @PreAuthorize("hasRole('STUDENT')")
    public ResponseEntity<ApiResponse<List<TokenResponse>>> getMyTokens(
            @AuthenticationPrincipal User currentUser) {

        List<TokenResponse> tokens = tokenService.getMyTokens(currentUser);
        return ResponseEntity.ok(new ApiResponse<>("Tokens retrieved successfully.", tokens));
    }

    /* ==================== 3. Generate QR Code ==================== */

    /**
     * Generates a Base64-encoded QR code image for a specific token.
     * Only the token owner (STUDENT) can generate QR codes for their tokens.
     *
     * @param id          the token's unique ID
     * @param currentUser the authenticated student (injected from JWT)
     * @return QrResponse containing the Base64 QR image (HTTP 200 OK)
     */
    @PostMapping("/{id}/generate-qr")
    @PreAuthorize("hasRole('STUDENT')")
    public ResponseEntity<ApiResponse<QrResponse>> generateQr(
            @PathVariable Long id,
            @AuthenticationPrincipal User currentUser) {

        QrResponse qr = tokenService.generateQr(id, currentUser);
        return ResponseEntity.ok(new ApiResponse<>("QR code generated successfully.", qr));
    }

    /* ==================== 5. Validate QR Code ==================== */

    /**
     * Validates a scanned QR code payload and returns token details.
     * Used by meal/dining managers when a student presents their QR code.
     * Restricted to MEAL_MANAGER and DINING_MANAGER roles.
     *
     * @param request the QR payload to validate
     * @return QrValidationResponse with validation result and token info (HTTP 200 OK)
     */
    @PostMapping("/validate-qr")
    @PreAuthorize("hasAnyRole('MEAL_MANAGER', 'DINING_MANAGER')")
    public ResponseEntity<ApiResponse<QrValidationResponse>> validateQr(
            @Valid @RequestBody ValidateQrRequest request) {

        QrValidationResponse result = tokenService.validateQr(request);
        return ResponseEntity.ok(new ApiResponse<>("QR validation completed.", result));
    }

    /* ==================== 6. Mark Token as Used ==================== */

    /**
     * Marks a token as USED after the student has been served their meal.
     * Restricted to MEAL_MANAGER and DINING_MANAGER roles.
     *
     * @param id the token's unique ID
     * @return the updated TokenResponse (HTTP 200 OK)
     */
    @PostMapping("/{id}/mark-used")
    @PreAuthorize("hasAnyRole('MEAL_MANAGER', 'DINING_MANAGER')")
    public ResponseEntity<ApiResponse<TokenResponse>> markTokenUsed(
            @PathVariable Long id) {

        TokenResponse token = tokenService.markTokenUsed(id);
        return ResponseEntity.ok(new ApiResponse<>("Token marked as used.", token));
    }

}
