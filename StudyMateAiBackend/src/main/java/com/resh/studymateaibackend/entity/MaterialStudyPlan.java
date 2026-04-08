package com.resh.studymateaibackend.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "material_study_plans")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MaterialStudyPlan {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "material_id", nullable = false, unique = true)
    private Material material;

    @Column(name = "month_label")
    private String monthLabel;

    @Column(name = "generated_at")
    private LocalDateTime generatedAt;

    @Column(columnDefinition = "TEXT")
    private String tasksJson;

    @OneToMany(mappedBy = "studyPlan", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<MaterialStudyTask> tasks = new ArrayList<>();
}