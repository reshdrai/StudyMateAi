package com.resh.studymateaibackend.controller;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.resh.studymateaibackend.auth.CustomUserDetails;
import com.resh.studymateaibackend.dto.study.FlashcardDto;
import com.resh.studymateaibackend.entity.Material;
import com.resh.studymateaibackend.entity.MaterialAnalysis;
import com.resh.studymateaibackend.repository.MaterialAnalysisRepository;
import com.resh.studymateaibackend.repository.MaterialRepository;
import com.resh.studymateaibackend.service.MaterialAiService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;

import java.util.*;

/**
 * Endpoint for the flashcard-study-page feature.
 * Returns only flashcards relevant to a specific topic label
 * so the frontend can present big topic-focused flashcards
 * before launching the quiz.
 */
@RestController
@RequestMapping("/api/materials")
@RequiredArgsConstructor
public class TopicFlashcardsController {

    private final MaterialRepository materialRepository;
    private final MaterialAnalysisRepository materialAnalysisRepository;
    private final MaterialAiService materialAiService;
    private final ObjectMapper objectMapper;

    /**
     * GET /api/materials/{id}/flashcards?topic=<topic_label>
     * Returns flashcards for the specified topic, or all flashcards if topic is absent or "ALL".
     */
    @GetMapping("/{id}/flashcards")
    public ResponseEntity<Map<String, Object>> getFlashcardsForTopic(
            @PathVariable Long id,
            @RequestParam(required = false) String topic,
            @AuthenticationPrincipal CustomUserDetails userDetails
    ) throws Exception {
        Material material = materialRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Material not found"));

        if (material.getUser() == null ||
                !material.getUser().getId().equals(userDetails.getUser().getId())) {
            throw new AccessDeniedException("Access denied");
        }

        MaterialAnalysis analysis = materialAnalysisRepository
                .findByMaterialId(material.getId())
                .orElse(null);

        // If no analysis yet, trigger overview generation
        if (analysis == null || !StringUtils.hasText(analysis.getKeyPoints())) {
            materialAiService.generateOverview(material.getId(), userDetails.getUser());
            analysis = materialAnalysisRepository
                    .findByMaterialId(material.getId())
                    .orElse(null);
        }

        List<FlashcardDto> allFlashcards = new ArrayList<>();
        if (analysis != null && StringUtils.hasText(analysis.getKeyPoints())) {
            try {
                allFlashcards = objectMapper.readValue(
                        analysis.getKeyPoints(),
                        new TypeReference<List<FlashcardDto>>() {});
            } catch (Exception e) {
                // fall through
            }
        }

        List<FlashcardDto> filtered;
        if (topic == null || topic.isBlank() || "ALL".equalsIgnoreCase(topic)) {
            filtered = allFlashcards;
        } else {
            String topicLower = topic.toLowerCase().trim();

            // Match flashcards whose front or back contains the topic
            filtered = allFlashcards.stream()
                    .filter(fc -> {
                        String f = fc.getFront() != null ? fc.getFront().toLowerCase() : "";
                        String b = fc.getBack() != null ? fc.getBack().toLowerCase() : "";
                        return f.contains(topicLower) || b.contains(topicLower);
                    })
                    .toList();

            // If no matches, fall back to first 5 flashcards rather than empty
            if (filtered.isEmpty() && !allFlashcards.isEmpty()) {
                filtered = allFlashcards.subList(0, Math.min(5, allFlashcards.size()));
            }
        }

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("materialId", material.getId());
        response.put("topic", topic != null ? topic : "ALL");
        response.put("flashcards", filtered);
        response.put("totalCount", filtered.size());

        return ResponseEntity.ok(response);
    }
}