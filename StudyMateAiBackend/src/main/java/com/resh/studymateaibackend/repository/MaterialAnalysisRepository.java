package com.resh.studymateaibackend.repository;

import com.resh.studymateaibackend.entity.MaterialAnalysis;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface MaterialAnalysisRepository extends JpaRepository<MaterialAnalysis, Long> {
    Optional<MaterialAnalysis> findByMaterialId(Long materialId);
}