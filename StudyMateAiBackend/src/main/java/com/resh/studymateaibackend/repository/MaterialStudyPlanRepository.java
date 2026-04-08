package com.resh.studymateaibackend.repository;

import com.resh.studymateaibackend.entity.MaterialStudyPlan;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface MaterialStudyPlanRepository extends JpaRepository<MaterialStudyPlan, Long> {
    Optional<MaterialStudyPlan> findByMaterialId(Long materialId);
}