package com.resh.studymateaibackend.entity;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "material_study_tasks")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MaterialStudyTask {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "study_plan_id", nullable = false)
    private MaterialStudyPlan studyPlan;

    @Column(nullable = false)
    private String dayLabel;

    @Column(nullable = false)
    @Builder.Default
    private String title = "Study Task";

    @Column(columnDefinition = "TEXT")
    @Builder.Default
    private String description = "";

    @Column(nullable = false)
    @Builder.Default
    private boolean completed = false;

    @Column(name = "task_type")
    @Builder.Default
    private String taskType = "READ";

    @Column(name = "estimated_minutes")
    @Builder.Default
    private int estimatedMinutes = 25;
}