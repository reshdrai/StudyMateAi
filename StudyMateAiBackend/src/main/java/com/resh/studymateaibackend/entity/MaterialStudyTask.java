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
    private String title;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(nullable = false)
    private boolean completed;
}