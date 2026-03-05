package dsi.ruet.backend.controllers;

import dsi.ruet.backend.dto.ApiResponse;
import dsi.ruet.backend.dto.mealmanager.*;
import dsi.ruet.backend.models.User;
import dsi.ruet.backend.services.MealManagerService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

/**
 * REST controller for all Meal Manager operations.
 * All endpoints require MEAL_MANAGER role.
 * Maps 1-to-1 with the frontend MealManagerService in dummy_api.md.
 */
@RestController
@RequestMapping
@PreAuthorize("hasRole('MEAL_MANAGER')")
public class MealManagerController {

    @Autowired
    private MealManagerService mealManagerService;

    // ==================== WALLET / TOP-UP ====================

    /**
     * POST /api/v1/wallet/topup
     * Top up a student's wallet.
     * Body: { "studentId": "S2021001", "amount": 500.00 }
     */
    @PostMapping("/wallet/topup")
    public ResponseEntity<ApiResponse<StudentBalanceResponse>> topUpWallet(
            @RequestBody TopUpRequest request,
            Authentication authentication) {

        Long managerId = getAuthenticatedUserId(authentication);
        ApiResponse<StudentBalanceResponse> response = mealManagerService.topUpWallet(request, managerId);
        return ResponseEntity.ok(response);
    }

    /**
     * GET /api/v1/wallet/student/{studentId}
     * Get a student's current wallet balance by roll number.
     */
    @GetMapping("/wallet/student/{studentId}")
    public ResponseEntity<ApiResponse<StudentBalanceResponse>> getStudentBalance(
            @PathVariable String studentId,
            Authentication authentication) {

        Long managerId = getAuthenticatedUserId(authentication);
        ApiResponse<StudentBalanceResponse> response = mealManagerService.getStudentBalance(studentId, managerId);
        return ResponseEntity.ok(response);
    }

    /**
     * GET /api/v1/wallet/history?date=2026-03-01
     * Get all top-up transactions for a specific date.
     */
    @GetMapping("/wallet/history")
    public ResponseEntity<ApiResponse<List<CreditTransactionResponse>>> getWalletHistory(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
            Authentication authentication) {

        Long managerId = getAuthenticatedUserId(authentication);
        ApiResponse<List<CreditTransactionResponse>> response = mealManagerService.getWalletHistory(managerId, date);
        return ResponseEntity.ok(response);
    }

    // ==================== MEAL CONFIGURATION ====================

    /**
     * POST /api/v1/meals/config
     * Create a new meal configuration for tomorrow.
     * Body: { "mealType": "LUNCH", "menu": "Rice, Dal, Fish", "price": 55.0,
     *         "purchaseStartTime": "...", "purchaseEndTime": "..." }
     */
    @PostMapping("/meals/config")
    public ResponseEntity<ApiResponse<MealConfigResponse>> createMealConfig(
            @RequestBody SetMenuRequest request,
            Authentication authentication) {

        Long managerId = getAuthenticatedUserId(authentication);
        ApiResponse<MealConfigResponse> response = mealManagerService.createMealConfig(request, managerId);
        return ResponseEntity.ok(response);
    }

    /**
     * PUT /api/v1/meals/config/{id}
     * Update an existing meal configuration.
     */
    @PutMapping("/meals/config/{id}")
    public ResponseEntity<ApiResponse<MealConfigResponse>> updateMealConfig(
            @PathVariable Long id,
            @RequestBody SetMenuRequest request,
            Authentication authentication) {

        Long managerId = getAuthenticatedUserId(authentication);
        ApiResponse<MealConfigResponse> response = mealManagerService.updateMealConfig(id, request, managerId);
        return ResponseEntity.ok(response);
    }

    /**
     * GET /api/v1/meals/config/tomorrow
     * Get all meal configs for tomorrow.
     */
    @GetMapping("/meals/config/tomorrow")
    public ResponseEntity<ApiResponse<List<MealConfigResponse>>> getTomorrowConfig(
            Authentication authentication) {

        Long managerId = getAuthenticatedUserId(authentication);
        ApiResponse<List<MealConfigResponse>> response = mealManagerService.getTomorrowConfig(managerId);
        return ResponseEntity.ok(response);
    }

    /**
     * GET /api/v1/meals/config/{date}
     * Get all meal configs for a specific date (YYYY-MM-DD).
     */
    @GetMapping("/meals/config/{date}")
    public ResponseEntity<ApiResponse<List<MealConfigResponse>>> getMealConfigByDate(
            @PathVariable String date,
            Authentication authentication) {

        Long managerId = getAuthenticatedUserId(authentication);
        ApiResponse<List<MealConfigResponse>> response = mealManagerService.getMealConfigByDate(date, managerId);
        return ResponseEntity.ok(response);
    }

    // ==================== DASHBOARD ====================

    /**
     * GET /api/v1/dashboard
     * Get aggregated dashboard data for today.
     */
    @GetMapping("/dashboard")
    public ResponseEntity<ApiResponse<DashboardResponse>> getDashboardData(
            Authentication authentication) {

        Long managerId = getAuthenticatedUserId(authentication);
        ApiResponse<DashboardResponse> response = mealManagerService.getDashboardData(managerId);
        return ResponseEntity.ok(response);
    }

    // ==================== HISTORY ====================

    /**
     * GET /api/v1/history/credits
     * Get daily credit (top-up) history (last 30 days).
     */
    @GetMapping("/history/credits")
    public ResponseEntity<ApiResponse<List<DailyCreditHistoryResponse>>> getCreditHistory(
            Authentication authentication) {

        Long managerId = getAuthenticatedUserId(authentication);
        ApiResponse<List<DailyCreditHistoryResponse>> response = mealManagerService.getCreditHistory(managerId);
        return ResponseEntity.ok(response);
    }

    // ==================== HELPER ====================

    /**
     * Extract the authenticated user's ID from the security context.
     */
    private Long getAuthenticatedUserId(Authentication authentication) {
        User user = (User) authentication.getPrincipal();
        return user.getId();
    }
}
