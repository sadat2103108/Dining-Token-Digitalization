package dsi.ruet.backend.dto.mealmanager;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class TopUpHistoryResponse {
    private Long transactionId;
    private Long studentId;
    private String studentName;
    private String studentEmail;
    private Long amount;
    private LocalDateTime createdAt;
}
