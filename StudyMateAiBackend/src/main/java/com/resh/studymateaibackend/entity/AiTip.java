package com.resh.studymateaibackend.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "ai_tips")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AiTip {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "subject_id")
    private Subject subject;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String message;

    @Column(name = "tip_type", length = 30)
    @Builder.Default
    private String tipType = "weak_topic";

    @Column(name = "generated_for_date")
    private LocalDate generatedForDate;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;
}