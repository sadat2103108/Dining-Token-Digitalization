package dsi.ruet.backend.dto.admin;

import dsi.ruet.backend.models.User;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class UserResponse {

    // ---- User fields ----
    private Long id;
    private String email;
    private String name;
    private Long hallId;
    private Boolean isVerified;
    private String role;

    // ---- Student-specific fields (null for DINING_MANAGER, ADMIN) ----
    private String roll;
    private String phoneNo;
    private String roomNo;

    /** Build from a User entity */
    public static UserResponse from(User user) {
        UserResponse r = new UserResponse();
        r.setId(user.getId());
        r.setEmail(user.getEmail());
        r.setName(user.getName());
        r.setHallId(user.getHall() != null ? user.getHall().getId() : null);
        r.setIsVerified(user.getIsVerified());
        r.setRole(user.getRole() != null ? user.getRole().name() : null);
        r.setRoll(user.getRoll());
        r.setPhoneNo(user.getPhoneNo());
        r.setRoomNo(user.getRoomNo());
        return r;
    }
}
