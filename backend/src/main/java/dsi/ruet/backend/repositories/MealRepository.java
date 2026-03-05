package dsi.ruet.backend.repositories;

import dsi.ruet.backend.models.Meal;
import dsi.ruet.backend.models.enums.MealType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

/**
 * Repository for Meal (meal_config) entity.
 * Provides lookups by hall, date, and meal type.
 */
@Repository
public interface MealRepository extends JpaRepository<Meal, Long> {

    /** All meals for a hall on a specific date */
    List<Meal> findByHallIdAndMealDate(Long hallId, LocalDate mealDate);

    /** Single meal for hall + date + type (unique combo) - with enum */
    Optional<Meal> findByHallIdAndMealDateAndMealType(Long hallId, LocalDate mealDate, MealType mealType);

    /** All meals for a hall */
    List<Meal> findByHallId(Long hallId);

    /** All meals for a hall within a date range (for history) */
    List<Meal> findByHallIdAndMealDateBetweenOrderByMealDateDesc(
            Long hallId, LocalDate startDate, LocalDate endDate);

}
