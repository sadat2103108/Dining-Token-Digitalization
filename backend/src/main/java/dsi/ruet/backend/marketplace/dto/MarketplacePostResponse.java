package dsi.ruet.backend.marketplace.dto;

import lombok.*;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MarketplacePostResponse {
    private Long id;
    private Long tokenId;
    private String mealType;
    private String mealDate;
    private String mealMenu;
    private Long mealPrice;
    private Long sellerId;
    private String sellerName;
    private String sellerRoll;
    private String sellerPhone;
    private String sellerHall;
    private String sellerRoom;
    private Long buyerId;
    private String buyerName;
    private String status;
    private String paymentType;
    private String createdAt;
    private String buyerRequestedAt;
}
