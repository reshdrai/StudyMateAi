package com.resh.studymateaibackend.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "subjects")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Subject {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false, length = 120)
    private String name;

    @Column(length = 50)
    private String code;

    @Column(length = 20)
    private String color;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @OneToMany(mappedBy = "subject")
    @Builder.Default
    private List<StudyTask> studyTasks = new ArrayList<>();

    @OneToMany(mappedBy = "subject")
    @Builder.Default
    private List<StudyGoal> studyGoals = new ArrayList<>();

    @OneToMany(mappedBy = "subject")
    @Builder.Default
    private List<Material> materials = new ArrayList<>();

    @OneToMany(mappedBy = "subject")
    @Builder.Default
    private List<Quiz> quizzes = new ArrayList<>();

    @OneToMany(mappedBy = "subject")
    @Builder.Default
    private List<AiTip> aiTips = new ArrayList<>();
}