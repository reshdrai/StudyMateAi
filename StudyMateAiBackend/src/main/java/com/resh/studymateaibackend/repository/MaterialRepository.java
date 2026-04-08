package com.resh.studymateaibackend.repository;

import com.resh.studymateaibackend.entity.Material;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface MaterialRepository extends JpaRepository<Material, Long> {

    List<Material> findByUserIdOrderByCreatedAtDesc(Long userId);

    List<Material> findByUserIdAndSubject_NameContainingIgnoreCaseOrderByCreatedAtDesc(
            Long userId,
            String subjectName
    );

    List<Material> findByUserIdAndTitleContainingIgnoreCaseOrderByCreatedAtDesc(
            Long userId,
            String title
    );
    List<Material> findByUserId(Long userId);
}