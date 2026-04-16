package com.resh.studymateaibackend.controller;

import com.resh.studymateaibackend.auth.CustomUserDetails;
import com.resh.studymateaibackend.entity.*;
import com.resh.studymateaibackend.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api/tracking")
@RequiredArgsConstructor
public class TrackingController {

    private final TrackedMaterialRepository trackedRepo;
    private final MaterialRepository materialRepo;

    /** List all materials with isTracked flag */
    @GetMapping
    @Transactional(readOnly = true)
    public ResponseEntity<List<Map<String, Object>>> getAll(
            @AuthenticationPrincipal CustomUserDetails u) {

        Long userId = u.getUser().getId();
        List<Material> materials = materialRepo.findByUserIdOrderByCreatedAtDesc(userId);
        Set<Long> tracked = new HashSet<>();
        trackedRepo.findByUserId(userId)
                .forEach(t -> tracked.add(t.getMaterial().getId()));

        List<Map<String, Object>> result = new ArrayList<>();
        for (Material m : materials) {
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("id", m.getId());
            item.put("title", m.getTitle());
            item.put("fileType", m.getFileType());
            item.put("processingStatus", m.getProcessingStatus());
            item.put("isTracked", tracked.contains(m.getId()));
            result.add(item);
        }
        return ResponseEntity.ok(result);
    }

    /** Toggle tracking for a material */
    @PostMapping("/{materialId}/toggle")
    @Transactional
    public ResponseEntity<Map<String, Object>> toggle(
            @PathVariable Long materialId,
            @AuthenticationPrincipal CustomUserDetails u) {

        Long userId = u.getUser().getId();
        Material material = materialRepo.findById(materialId)
                .orElseThrow(() -> new RuntimeException("Material not found"));

        if (!material.getUser().getId().equals(userId)) {
            return ResponseEntity.status(403).body(Map.of("error", "Access denied"));
        }

        boolean wasTracked = trackedRepo.existsByUserIdAndMaterialId(userId, materialId);
        if (wasTracked) {
            trackedRepo.deleteByUserIdAndMaterialId(userId, materialId);
        } else {
            trackedRepo.save(TrackedMaterial.builder()
                    .user(u.getUser()).material(material).build());
        }

        return ResponseEntity.ok(Map.of(
                "materialId", materialId,
                "isTracked", !wasTracked
        ));
    }
}