package com.resh.studymateaibackend.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/**
 * Tracks which MaterialStudyTask reminders have already been sent,
 * so the scheduler doesn't spam the same notification repeatedly.
 */
@Entity
@Table(name = "notification_logs", uniqueConstraints = {
        @UniqueConstraint(columnNames = {"task_id", "notification_type"})
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class NotificationLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "task_id", nullable = false)
    private Long taskId;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "notification_type", nullable = false, length = 50)
    private String notificationType; // "DAILY_REMINDER", "OVERDUE", "STREAK_ALERT"

    @Column(nullable = false)
    private LocalDateTime sentAt;

    @PrePersist
    void onCreate() {
        if (sentAt == null) sentAt = LocalDateTime.now();
    }
}