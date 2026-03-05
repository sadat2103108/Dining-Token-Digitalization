package dsi.ruet.backend.services;

import dsi.ruet.backend.dto.ApiResponse;
import dsi.ruet.backend.dto.mealmanager.*;
import dsi.ruet.backend.exception.ResourceNotFoundException;
import dsi.ruet.backend.models.*;
import dsi.ruet.backend.models.enums.MealType;
import dsi.ruet.backend.models.enums.Role;
import dsi.ruet.backend.models.enums.TransactionType;
import dsi.ruet.backend.repositories.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Service layer for all Meal Manager operations.
 *
 * Covers:
 *  - Wallet top-up & balance lookup
 *  - Meal configuration (create / update / get)
 *  - Reports (sales, wallet top-ups)
 *  - Dashboard aggregation
 *  - History (credit history)
 */
@Service
public class MealManagerService {

    @Autowired
    private WalletRepository walletRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private MealRepository mealRepository;

    @Autowired
    private TokenRepository tokenRepository;

    @Autowired
    private CoinTransactionRepository coinTransactionRepository;

    @Autowired
    private HallRepository hallRepository;

    @Autowired
    private StudentInfoRepository studentInfoRepository;

    // Date formatters
    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter.ofPattern("yyyy-MM-dd");
    private static final DateTimeFormatter DISPLAY_DATE_FMT = DateTimeFormatter.ofPattern("MMMM d, yyyy");
    private static final DateTimeFormatter TIME_FMT = DateTimeFormatter.ofPattern("hh:mm a");

    // ==================== WALLET / TOP-UP ====================

    /**
     * POST /api/v1/wallet/topup
     * Top up a student's wallet by roll number.
     * Only the meal manager of the same hall can perform this.
     * Records a CoinTransaction (manager → student, type=TOPUP).
     */
    @Transactional
    public ApiResponse<StudentBalanceResponse> topUpWallet(TopUpRequest request, Long managerId) {
        // Validate amount
        if (request.getAmount() == null || request.getAmount() <= 0) {
            throw new IllegalArgumentException("Top-up amount must be positive");
        }

        User manager = findUserById(managerId);

        // Look up student by roll number
        StudentInfo studentInfo = studentInfoRepository.findByRoll(request.getStudentId())
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Student not found with roll: " + request.getStudentId()));
        User student = studentInfo.getUser();

        // Prevent manager from topping up their own wallet
        if (manager.getId().equals(student.getId())) {
            throw new IllegalArgumentException("You cannot top up your own wallet");
        }

        // Ensure manager and student belong to the same hall
        verifySameHall(manager, student);

        // Credit the student's wallet
        Wallet wallet = getOrCreateWallet(student);
        wallet.setBalance(wallet.getBalance() + request.getAmount());
        wallet = walletRepository.save(wallet);

        // Record coin transaction: manager → student
        recordCoinTransaction(manager, student, request.getAmount(), "TOPUP");

        // Return updated balance
        StudentBalanceResponse balanceResp = new StudentBalanceResponse(
                student.getId(), student.getName(), wallet.getBalance());
        return new ApiResponse<>("Wallet topped up successfully", balanceResp);
    }

    /**
     * GET /api/v1/wallet/student/{studentId}
     * Returns the current wallet balance for a student (by roll number).
     */
    public ApiResponse<StudentBalanceResponse> getStudentBalance(String rollNumber, Long managerId) {
        User manager = findUserById(managerId);

        // Look up student by roll
        StudentInfo studentInfo = studentInfoRepository.findByRoll(rollNumber)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Student not found with roll: " + rollNumber));
        User student = studentInfo.getUser();
        verifySameHall(manager, student);

        // Fetch or default wallet balance
        Wallet wallet = getOrCreateWallet(student);
        StudentBalanceResponse resp = new StudentBalanceResponse(
                student.getId(), student.getName(), wallet.getBalance());
        return new ApiResponse<>("Student balance retrieved", resp);
    }

    /**
     * GET /api/v1/wallet/history?date=YYYY-MM-DD
     * Returns all TOPUP transactions made by this manager on the given date.
     */
    public ApiResponse<List<CreditTransactionResponse>> getWalletHistory(Long managerId, LocalDate date) {
        LocalDateTime dayStart = date.atStartOfDay();
        LocalDateTime dayEnd = date.plusDays(1).atStartOfDay();

        // Fetch top-up transactions for this manager on the date
        List<CoinTransaction> transactions = coinTransactionRepository
                .findTopUpsBySenderAndDateRange(managerId, dayStart, dayEnd);

        List<CreditTransactionResponse> result = transactions.stream().map(tx -> {
            // Get student roll from StudentInfo (if available)
            Long receiverId = tx.getReceiver().getId();
            String roll = studentInfoRepository.findById(receiverId)
                    .map(StudentInfo::getRoll).orElse(receiverId.toString());
            String receiverName = userRepository.findById(receiverId)
                    .map(User::getName).orElse(receiverId.toString());

            return new CreditTransactionResponse(
                    tx.getId().toString(),
                    roll,
                    receiverName,
                    tx.getAmount(),
                    tx.getCreatedAt()
            );
        }).toList();

        return new ApiResponse<>("Wallet history for " + date, result);
    }

    // ==================== MEAL CONFIGURATION ====================

    /**
     * POST /api/v1/meals/config
     * Create a new meal config for tomorrow.
     * If a config already exists for that hall+date+mealType, throws an error.
     */
    @Transactional
    public ApiResponse<MealConfigResponse> createMealConfig(SetMenuRequest request, Long managerId) {
        MealType mealType = parseMealType(request.getMealType());

        User manager = findUserById(managerId);
        Hall hall = manager.getHall();
        LocalDate tomorrow = LocalDate.now().plusDays(1);

        // Check if config already exists
        Optional<Meal> existing = mealRepository.findByHallIdAndMealDateAndMealType(
                hall.getId(), tomorrow, mealType);
        if (existing.isPresent()) {
            throw new IllegalArgumentException(
                    request.getMealType() + " config already exists for " + tomorrow +
                    ". Use PUT to update.");
        }

        // Create new meal record
        Meal meal = new Meal();
        meal.setHall(hall);
        meal.setMealDate(tomorrow);
        meal.setMealType(mealType);
        meal.setMenu(request.getMenu());
        meal.setPrice(request.getPrice());
        meal.setPurchaseStartTime(request.getPurchaseStartTime());
        meal.setPurchaseEndTime(request.getPurchaseEndTime());
        meal.setIsClosed(false);
        meal = mealRepository.save(meal);

        return new ApiResponse<>("Meal config created", toMealConfigResponse(meal));
    }

    /**
     * PUT /api/v1/meals/config/{id}
     * Update an existing meal config by its ID.
     */
    @Transactional
    public ApiResponse<MealConfigResponse> updateMealConfig(Long mealId, SetMenuRequest request,
                                                            Long managerId) {
        User manager = findUserById(managerId);
        Meal meal = findMealById(mealId);

        // Ensure meal belongs to manager's hall
        if (!meal.getHall().getId().equals(manager.getHall().getId())) {
            throw new IllegalArgumentException("You can only update meals for your own hall");
        }

        // Update fields
        if (request.getMenu() != null) meal.setMenu(request.getMenu());
        if (request.getPrice() != null) meal.setPrice(request.getPrice());
        if (request.getMealType() != null) {
            MealType mealType = parseMealType(request.getMealType());
            meal.setMealType(mealType);
        }
        if (request.getPurchaseStartTime() != null) meal.setPurchaseStartTime(request.getPurchaseStartTime());
        if (request.getPurchaseEndTime() != null) meal.setPurchaseEndTime(request.getPurchaseEndTime());

        meal = mealRepository.save(meal);
        return new ApiResponse<>("Meal config updated", toMealConfigResponse(meal));
    }

    /**
     * GET /api/v1/meals/config/tomorrow
     * Returns all meal configs for tomorrow for the manager's hall.
     */
    public ApiResponse<List<MealConfigResponse>> getTomorrowConfig(Long managerId) {
        User manager = findUserById(managerId);
        LocalDate tomorrow = LocalDate.now().plusDays(1);

        List<Meal> meals = mealRepository.findByHallIdAndMealDate(manager.getHall().getId(), tomorrow);
        List<MealConfigResponse> configs = meals.stream()
                .map(this::toMealConfigResponse).toList();

        return new ApiResponse<>("Tomorrow's meal configs", configs);
    }

    /**
     * GET /api/v1/meals/config/{date}
     * Returns all meal configs for a specific date for the manager's hall.
     */
    public ApiResponse<List<MealConfigResponse>> getMealConfigByDate(String dateStr, Long managerId) {
        User manager = findUserById(managerId);
        LocalDate date = LocalDate.parse(dateStr, DATE_FMT);

        List<Meal> meals = mealRepository.findByHallIdAndMealDate(manager.getHall().getId(), date);
        List<MealConfigResponse> configs = meals.stream()
                .map(this::toMealConfigResponse).toList();

        return new ApiResponse<>("Meal configs for " + dateStr, configs);
    }

    // ==================== REPORTS ====================

    /**
     * GET /api/v1/reports/sales?date=YYYY-MM-DD
     * Returns lunch/dinner token counts sold on the given date.
     */
    public ApiResponse<SalesReportResponse> getSalesReport(String dateStr, Long managerId) {
        User manager = findUserById(managerId);
        LocalDate date = LocalDate.parse(dateStr, DATE_FMT);

        List<Meal> meals = mealRepository.findByHallIdAndMealDate(manager.getHall().getId(), date);

        int lunchSold = 0;
        int dinnerSold = 0;

        for (Meal meal : meals) {
            long count = tokenRepository.countByMealId(meal.getId());
            if (meal.getMealType() == MealType.LUNCH) {
                lunchSold = (int) count;
            } else if (meal.getMealType() == MealType.DINNER) {
                dinnerSold = (int) count;
            }
        }

        SalesReportResponse resp = new SalesReportResponse(lunchSold, dinnerSold);
        return new ApiResponse<>("Sales report for " + dateStr, resp);
    }



    /**
     * GET /api/v1/reports/wallet-topups?date=YYYY-MM-DD
     * Returns all wallet top-up transactions on the given date.
     * (Same data as wallet history, but used by the reports screen.)
     */
    public ApiResponse<List<CreditTransactionResponse>> getWalletTopups(String dateStr, Long managerId) {
        LocalDate date = LocalDate.parse(dateStr, DATE_FMT);
        return getWalletHistory(managerId, date);
    }

    // ==================== DASHBOARD ====================

    /**
     * GET /api/v1/dashboard
     * Returns aggregated dashboard data for today:
     *  - lunch/dinner token counts
     *  - total students in hall
     *  - today's top-up count
     *  - meal availability status
     */
    public ApiResponse<DashboardResponse> getDashboardData(Long managerId) {
        User manager = findUserById(managerId);
        LocalDate tomorrow = LocalDate.now().plusDays(1);

        List<Meal> meals = mealRepository.findByHallIdAndMealDate(manager.getHall().getId(), tomorrow);

        int lunchCount = 0;
        int dinnerCount = 0;
        boolean lunchAvailable = false;
        boolean dinnerAvailable = false;

        for (Meal meal : meals) {
            long count = tokenRepository.countByMealId(meal.getId());
            if (meal.getMealType() == MealType.LUNCH) {
                lunchCount = (int) count;
                lunchAvailable = !Boolean.TRUE.equals(meal.getIsClosed());
            } else if (meal.getMealType() == MealType.DINNER) {
                dinnerCount = (int) count;
                dinnerAvailable = !Boolean.TRUE.equals(meal.getIsClosed());
            }
        }

        // Total students in this hall
        int totalStudents = (int) userRepository.countByHallIdAndRole(manager.getHall().getId(), Role.STUDENT);

        // Today's top-up count
        LocalDate today = LocalDate.now();
        LocalDateTime dayStart = today.atStartOfDay();
        LocalDateTime dayEnd = today.plusDays(1).atStartOfDay();
        int todayTopUps = (int) coinTransactionRepository.countTopUpsBySenderAndDay(
                managerId, dayStart, dayEnd);

        DashboardResponse resp = new DashboardResponse(
                lunchCount, dinnerCount,
                totalStudents, todayTopUps,
                lunchAvailable, dinnerAvailable
        );
        return new ApiResponse<>("Dashboard data", resp);
    }

    // ==================== HISTORY ====================

    /**
     * GET /api/v1/history/credits
     * Returns daily credit (top-up) history, grouped by date.
     */
    public ApiResponse<List<DailyCreditHistoryResponse>> getCreditHistory(Long managerId) {
        // Fetch last 30 days of top-ups
        LocalDate endDate = LocalDate.now();
        LocalDate startDate = endDate.minusDays(30);
        LocalDateTime start = startDate.atStartOfDay();
        LocalDateTime end = endDate.plusDays(1).atStartOfDay();

        List<CoinTransaction> transactions = coinTransactionRepository
                .findTopUpsBySenderAndDateRange(managerId, start, end);

        // Group by date
        Map<LocalDate, List<CoinTransaction>> txByDate = transactions.stream()
                .collect(Collectors.groupingBy(
                        tx -> tx.getCreatedAt().toLocalDate(),
                        LinkedHashMap::new, Collectors.toList()));

        List<DailyCreditHistoryResponse> history = new ArrayList<>();
        for (Map.Entry<LocalDate, List<CoinTransaction>> entry : txByDate.entrySet()) {
            LocalDate date = entry.getKey();
            List<CoinTransaction> dayTx = entry.getValue();

            List<DailyCreditHistoryResponse.CreditTransactionItem> items = dayTx.stream().map(tx -> {
                // Resolve student roll number
                Long receiverId = tx.getReceiver().getId();
                String roll = studentInfoRepository.findById(receiverId)
                        .map(StudentInfo::getRoll).orElse(receiverId.toString());
                String receiverName = userRepository.findById(receiverId)
                        .map(User::getName).orElse(receiverId.toString());

                return new DailyCreditHistoryResponse.CreditTransactionItem(
                        tx.getId().toString(),
                        roll,
                        receiverName,
                        (double) tx.getAmount(),
                        tx.getCreatedAt().format(TIME_FMT)
                );
            }).toList();

            history.add(new DailyCreditHistoryResponse(
                    date.format(DISPLAY_DATE_FMT), items));
        }

        return new ApiResponse<>("Credit history (last 30 days)", history);
    }

    // ==================== HELPER METHODS ====================

    /** Find user by ID or throw 404 */
    private User findUserById(Long userId) {
        return userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found with id: " + userId));
    }

    /** Find hall by ID or throw 404 */
    private Hall findHallById(Long hallId) {
        return hallRepository.findById(hallId)
                .orElseThrow(() -> new ResourceNotFoundException("Hall not found with id: " + hallId));
    }

    /** Find meal by ID or throw 404 */
    private Meal findMealById(Long mealId) {
        return mealRepository.findById(mealId)
                .orElseThrow(() -> new ResourceNotFoundException("Meal not found with id: " + mealId));
    }

    /** Ensure manager and student belong to the same hall */
    private void verifySameHall(User manager, User student) {
        if (!manager.getHall().getId().equals(student.getHall().getId())) {
            throw new IllegalArgumentException("Student does not belong to your hall");
        }
    }

    /** Parse meal type string to enum */
    private MealType parseMealType(String mealType) {
        try {
            return MealType.valueOf(mealType.toUpperCase());
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException("Meal type must be LUNCH or DINNER");
        }
    }

    /** Get existing wallet or create a new one with zero balance */
    private Wallet getOrCreateWallet(User user) {
        return walletRepository.findByUserId(user.getId()).orElseGet(() -> {
            Wallet w = new Wallet();
            w.setUser(user);
            w.setBalance(0L);
            return walletRepository.save(w);
        });
    }

    /** Record a coin transaction between two users */
    private void recordCoinTransaction(User sender, User receiver, Long amount, String typeStr) {
        CoinTransaction tx = new CoinTransaction();
        tx.setSender(sender);
        tx.setReceiver(receiver);
        tx.setAmount(amount);
        TransactionType type;
        switch (typeStr.toUpperCase()) {
            case "TOPUP":
                type = TransactionType.TOPUP;
                break;
            case "REFUND":
                type = TransactionType.REFUND;
                break;
            default:
                type = TransactionType.TRANSACTION;
                break;
        }
        tx.setType(type);
        tx.setCreatedAt(LocalDateTime.now());
        coinTransactionRepository.save(tx);
    }

    /** Convert Meal entity to MealConfigResponse DTO */
    private MealConfigResponse toMealConfigResponse(Meal meal) {
        String deadline = meal.getPurchaseEndTime() != null
                ? meal.getPurchaseEndTime().toLocalTime().format(DateTimeFormatter.ofPattern("HH:mm"))
                : null;
        String startTime = meal.getPurchaseStartTime() != null
                ? meal.getPurchaseStartTime().toString()
                : null;
        String endTime = meal.getPurchaseEndTime() != null
                ? meal.getPurchaseEndTime().toString()
                : null;

        return new MealConfigResponse(
                meal.getId(),
                meal.getMealDate().format(DATE_FMT),
                meal.getMealType().name(),
                meal.getPrice(),
                meal.getMenu(),
                deadline,
                startTime,
                endTime,
                Boolean.TRUE.equals(meal.getIsClosed()),
                (int) tokenRepository.countByMealId(meal.getId())
        );
    }

}
