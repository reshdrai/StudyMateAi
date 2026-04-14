package com.resh.studymateaibackend.service;

import com.resh.studymateaibackend.dto.material.MaterialCardResponse;
import com.resh.studymateaibackend.dto.material.MaterialDetailsResponse;
import com.resh.studymateaibackend.dto.material.UploadMaterialResponse;
import com.resh.studymateaibackend.entity.Material;
import com.resh.studymateaibackend.entity.MaterialAnalysis;
import com.resh.studymateaibackend.entity.MaterialStudyPlan;
import com.resh.studymateaibackend.entity.User;
import com.resh.studymateaibackend.repository.MaterialAnalysisRepository;
import com.resh.studymateaibackend.repository.MaterialRepository;
import com.resh.studymateaibackend.repository.MaterialStudyPlanRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class MaterialService {

    private final MaterialRepository materialRepository;
    private final MaterialAnalysisRepository materialAnalysisRepository;
    private final MaterialStudyPlanRepository materialStudyPlanRepository;
    private final FileStorageService fileStorageService;
    private final TextExtractionService textExtractionService;

    private String cleanExtractedText(String text) {
        if (text == null) return null;
        return text
                .replace("\u0000", "")
                .replaceAll("[\\p{Cntrl}&&[^\r\n\t]]", "")
                .trim();
    }

    @Transactional
    public UploadMaterialResponse uploadMaterial(User user, MultipartFile file, String title, Long subjectId) throws IOException {
        if (file == null || file.isEmpty()) {
            throw new RuntimeException("File is empty");
        }

        String fileUrl = fileStorageService.store(file);
        String extractedText = textExtractionService.extract(file);
        String cleanExtractedText = cleanExtractedText(extractedText);

        Material material = Material.builder()
                .user(user)
                .title(title != null && !title.isBlank() ? title : file.getOriginalFilename())
                .fileType(file.getContentType())
                .fileUrl(fileUrl)
                .extractedText(cleanExtractedText)
                .processingStatus("UPLOADED")
                .createdAt(LocalDateTime.now())
                .build();

        materialRepository.save(material);

        return UploadMaterialResponse.builder()
                .id(material.getId())
                .title(material.getTitle())
                .processingStatus(material.getProcessingStatus())
                .build();
    }

    /**
     * Get materials list.
     * IMPORTANT: This only reads basic Material fields.
     * It does NOT touch MaterialAnalysis lob fields.
     */
    @Transactional(readOnly = true)
    public List<MaterialCardResponse> getMaterials(User user, String category, String q) {
        List<Material> materials;

        if (q != null && !q.isBlank()) {
            materials = materialRepository.findByUserIdAndTitleContainingIgnoreCaseOrderByCreatedAtDesc(
                    user.getId(), q
            );
        } else if (category != null && !category.equalsIgnoreCase("All") && !category.isBlank()) {
            materials = materialRepository.findByUserIdAndSubject_NameContainingIgnoreCaseOrderByCreatedAtDesc(
                    user.getId(), category
            );
        } else {
            materials = materialRepository.findByUserIdOrderByCreatedAtDesc(user.getId());
        }

        List<MaterialCardResponse> response = new ArrayList<>();

        for (Material material : materials) {
            // Build response from basic fields only — no lob access
            String subjectName = null;
            try {
                if (material.getSubject() != null) {
                    subjectName = material.getSubject().getName();
                }
            } catch (Exception e) {
                // Subject lazy load failed, that's okay
                subjectName = "General";
            }

            response.add(MaterialCardResponse.builder()
                    .id(material.getId())
                    .title(material.getTitle())
                    .subjectName(subjectName)
                    .fileType(material.getFileType())
                    .fileUrl(material.getFileUrl())
                    .processingStatus(material.getProcessingStatus())
                    .createdAt(material.getCreatedAt())
                    .build());
        }

        return response;
    }

    /**
     * Get material details including analysis data.
     * Uses @Transactional to keep session open while reading lob fields.
     */
    @Transactional(readOnly = true)
    public MaterialDetailsResponse getMaterialDetails(Long materialId, User user) {
        Material material = getOwnedMaterial(materialId, user);

        // Explicitly query analysis and study plan (not through material.getAnalysis())
        MaterialAnalysis analysis = materialAnalysisRepository
                .findByMaterialId(materialId)
                .orElse(null);

        MaterialStudyPlan studyPlan = materialStudyPlanRepository
                .findByMaterialId(materialId)
                .orElse(null);

        return MaterialDetailsResponse.builder()
                .id(material.getId())
                .title(material.getTitle())
                .fileType(material.getFileType())
                .fileUrl(material.getFileUrl())
                .extractedText(material.getExtractedText())
                .processingStatus(material.getProcessingStatus())
                .createdAt(material.getCreatedAt())
                .updatedAt(material.getUpdatedAt())
                .keyPoints(analysis != null ? analysis.getKeyPoints() : null)
                .importantTopics(analysis != null ? analysis.getImportantTopics() : null)
                .questions(analysis != null ? analysis.getQuestions() : null)
                .studyPlan(studyPlan != null ? studyPlan.getTasksJson() : null)
                .build();
    }

    @Transactional(readOnly = true)
    public Material getOwnedMaterial(Long materialId, User user) {
        Material material = materialRepository.findById(materialId)
                .orElseThrow(() -> new RuntimeException("Material not found"));

        if (material.getUser() == null || user == null || !material.getUser().getId().equals(user.getId())) {
            throw new AccessDeniedException("User cannot access the material");
        }

        return material;
    }
}