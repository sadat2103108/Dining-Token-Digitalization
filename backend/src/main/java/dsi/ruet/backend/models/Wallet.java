package dsi.ruet.backend.models;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "wallets")
@Data
@NoArgsConstructor
public class Wallet {

    /** Primary key — maps to the "user_id" column (the actual PK in PostgreSQL). */
    @Id
    @Column(name = "user_id")
    private Long userId;

    /** The "id" column — also an FK to users.id, must equal userId. */
    @Column(name = "id", nullable = false)
    private Long id;

    @Column(nullable = false)
    private Long balance = 0L;

    /** Convenience: set both userId (PK) and id from a User object. */
    public void setUser(User user) {
        if (user != null) {
            this.userId = user.getId();
            this.id = user.getId();
        }
    }

    /** Deduct amount from balance */
    public void deduct(Long amount) {
        this.balance = this.balance - amount;
    }

    /** Credit amount to balance */
    public void credit(Long amount) {
        this.balance = this.balance + amount;
    }
}
