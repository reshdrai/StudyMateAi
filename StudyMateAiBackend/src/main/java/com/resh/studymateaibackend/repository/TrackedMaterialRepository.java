package com.resh.studymateaibackend.repository;

import com.resh.studymateaibackend.entity.TrackedMaterial;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface TrackedMaterialRepository extends JpaRepository<TrackedMaterial, Long> {
    List<TrackedMaterial> findByUserId(Long userId);
    Optional<TrackedMaterial> findByUserIdAndMaterialId(Long userId, Long materialId);
    boolean existsByUserIdAndMaterialId(Long userId, Long materialId);
    void deleteByUserIdAndMaterialId(Long userId, Long materialId);
}