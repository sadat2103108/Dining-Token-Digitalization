package dsi.ruet.backend.services;

import dsi.ruet.backend.dto.ApiResponse;
import dsi.ruet.backend.dto.manager.SalesReportResponse;
import dsi.ruet.backend.dto.manager.WalletTopupReportResponse;
import dsi.ruet.backend.exception.ResourceNotFoundException;
import dsi.ruet.backend.models.CoinTransaction;
import dsi.ruet.backend.models.Meal;
import dsi.ruet.backend.models.User;
import dsi.ruet.backend.models.enums.TokenStatus;
import dsi.ruet.backend.repositories.CoinTransactionRepository;
import dsi.ruet.backend.repositories.MealRepository;
import dsi.ruet.backend.repositories.TokenRepository;
import dsi.ruet.backend.repositories.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;


@Service
public class ReportService {

    @Autowired
    private MealRepository mealRepository;

    @Autowired
    private TokenRepository tokenRepository;

    @Autowired
    private CoinTransactionRepository coinTransactionRepository;

    @Autowired
    private UserRepository userRepository;

    /**
     * GET /reports/sales?date=YYYY-MM-DD — Sales report for a given date
     */
    public ApiResponse<SalesReportResponse> getSalesReport(String email, String dateStr) {
        User manager = getManager(email);
        Long hallId = manager.getHall().getId();
        LocalDate date = LocalDate.parse(dateStr);

        List<Meal> meals = mealRepository.findByHallIdAndMealDate(hallId, date);

        List<SalesReportResponse.MealSalesDetail> details = new ArrayList<>();
        long totalTokens = 0;
        long totalRevenue = 0L;

        for (Meal meal : meals) {
            long sold = tokenRepository.countByMealId(meal.getId());
            long used = tokenRepository.countByMealIdAndStatus(meal.getId(), TokenStatus.USED);
            long active = tokenRepository.countByMealIdAndStatus(meal.getId(), TokenStatus.AVAILABLE);
            Long price = meal.getPrice();
            long revenue = price * sold;

            totalTokens += sold;
            totalRevenue += revenue;

            SalesReportResponse.MealSalesDetail detail = new SalesReportResponse.MealSalesDetail();
            detail.setMealId(meal.getId());
            detail.setMealType(meal.getMealType().name());
            detail.setMenu(meal.getMenu());
            detail.setPrice(price);
            detail.setTokensSold(sold);
            detail.setTokensUsed(used);
            detail.setTokensActive(active);
            detail.setRevenue(revenue);
            details.add(detail);
        }

        SalesReportResponse response = new SalesReportResponse();
        response.setDate(dateStr);
        response.setHallId(hallId);
        response.setMeals(details);
        response.setTotalTokensSold(totalTokens);
        response.setTotalRevenue(totalRevenue);

        return new ApiResponse<>("Sales report for " + dateStr, response);
    }

    /**
     * GET /reports/wallet-topups?date=YYYY-MM-DD — Wallet top-up report for a given date
     */
    public ApiResponse<WalletTopupReportResponse> getWalletTopupReport(String email, String dateStr) {
        User manager = getManager(email);
        Long hallId = manager.getHall().getId();
        LocalDate date = LocalDate.parse(dateStr);

        // Get all users in this hall
        List<User> hallUsers = userRepository.findAll().stream()
                .filter(u -> u.getHall() != null && hallId.equals(u.getHall().getId()))
                .collect(Collectors.toList());

        List<Long> hallUserIds = hallUsers.stream()
                .map(User::getId)
                .collect(Collectors.toList());

        // Build a map for quick user lookup
        Map<Long, User> userMap = hallUsers.stream()
                .collect(Collectors.toMap(User::getId, u -> u));

        LocalDateTime startOfDay = date.atStartOfDay();
        LocalDateTime endOfDay = date.plusDays(1).atStartOfDay();

        List<CoinTransaction> topups = List.of();
        Long totalAmount = 0L;

        if (!hallUserIds.isEmpty()) {
            topups = coinTransactionRepository.findTopUpsByReceiverIdsAndDate(
                    hallUserIds, startOfDay, endOfDay);
            Long sumResult = coinTransactionRepository.sumTopUpsByReceiverIdsAndDate(
                    hallUserIds, startOfDay, endOfDay);
            totalAmount = sumResult != null ? sumResult : 0L;
        }

        List<WalletTopupReportResponse.TopupDetail> topupDetails = new ArrayList<>();
        for (CoinTransaction tx : topups) {
            WalletTopupReportResponse.TopupDetail detail = new WalletTopupReportResponse.TopupDetail();
            detail.setTransactionId(tx.getId());
            detail.setSenderId(tx.getSender() != null ? tx.getSender().getId() : null);
            detail.setReceiverId(tx.getReceiver() != null ? tx.getReceiver().getId() : null);
            detail.setAmount(tx.getAmount());
            detail.setCreatedAt(tx.getCreatedAt());

            Long receiverId = tx.getReceiver() != null ? tx.getReceiver().getId() : null;
            User receiver = receiverId != null ? userMap.get(receiverId) : null;
            if (receiver != null) {
                detail.setReceiverName(receiver.getName());
                detail.setReceiverEmail(receiver.getEmail());
            }
            topupDetails.add(detail);
        }

        WalletTopupReportResponse response = new WalletTopupReportResponse();
        response.setDate(dateStr);
        response.setHallId(hallId);
        response.setTotalTopups(topupDetails.size());
        response.setTotalAmount(totalAmount);
        response.setTopups(topupDetails);

        return new ApiResponse<>("Wallet top-up report for " + dateStr, response);
    }

    private User getManager(String email) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new ResourceNotFoundException("User not found with email: " + email));
        if (!"MEAL_MANAGER".equals(user.getRole().name())) {
            throw new IllegalStateException("User is not a Meal Manager");
        }
        return user;
    }
}
