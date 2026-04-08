package com.resh.studymateaibackend.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "material_analyses")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MaterialAnalysis {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne
    @JoinColumn(name = "material_id", nullable = false, unique = true)
    private Material material;

    @Lob
    @Column(columnDefinition = "TEXT")
    private String rawOutput;

    @Lob
    @Column(columnDefinition = "TEXT")
    private String keyPoints;

    @Lob
    @Column(columnDefinition = "TEXT")
    private String importantTopics;

    @Lob
    @Column(columnDefinition = "TEXT")
    private String questions;

    @Lob
    @Column(columnDefinition = "TEXT")
    private String weakTopics;

    @Lob
    @Column(columnDefinition = "TEXT")
    private String studyPlan;

    private LocalDateTime analyzedAt;
}