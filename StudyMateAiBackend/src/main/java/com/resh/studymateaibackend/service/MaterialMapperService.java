//package com.resh.studymateaibackend.service;
//
//import com.fasterxml.jackson.core.type.TypeReference;
//import com.fasterxml.jackson.databind.JsonNode;
//import com.fasterxml.jackson.databind.ObjectMapper;
//import com.resh.studymateaibackend.dto.material.*;
//import com.resh.studymateaibackend.entity.Material;
//import com.resh.studymateaibackend.entity.MaterialAnalysis;
//import com.resh.studymateaibackend.entity.MaterialStudyPlan;
//import com.resh.studymateaibackend.entity.MaterialStudyTask;
//import lombok.RequiredArgsConstructor;
//import org.springframework.stereotype.Service;
//
//import java.time.format.DateTimeFormatter;
//import java.util.*;
//import java.util.stream.Collectors;
//
//@Service
//@RequiredArgsConstructor
//public class MaterialMapperService {
//
//    private final ObjectMapper objectMapper;
//
//    public MaterialCardResponse toCardResponse(Material material) {
//        return MaterialCardResponse.builder()
//                .id(material.getId())
//                .title(material.getTitle())
//                .subjectName(material.getSubject() != null ? material.getSubject().getName() : "General")
//                .fileType(material.getFileType())
//                .createdDate(material.getCreatedAt() != null
//                        ? material.getCreatedAt().format(DateTimeFormatter.ISO_LOCAL_DATE)
//                        : null)
//                .processingStatus(material.getProcessingStatus() != null
//                        ? material.getProcessingStatus().toString().toLowerCase()
//                        : null)
//                .build();
//    }
//
//    public MaterialDetailsResponse toDetailsResponse(
//            Material material,
//            MaterialAnalysis analysis,
//            MaterialStudyPlan studyPlan
//    ) {
//        return MaterialDetailsResponse.builder()
//                .id(material.getId())
//                .title(material.getTitle())
//                .subjectName(material.getSubject() != null ? material.getSubject().getName() : "General")
//                .fileType(material.getFileType())
//                .createdDate(material.getCreatedAt() != null
//                        ? material.getCreatedAt().format(DateTimeFormatter.ISO_LOCAL_DATE)
//                        : null)
//                .processingStatus(material.getProcessingStatus() != null
//                        ? material.getProcessingStatus().toString().toLowerCase()
//                        : null)
//                .analyzed(analysis != null && analysis.getAnalyzedAt() != null)
//                .keyPoints(parseKeyPoints(analysis))
//                .flashcards(parseFlashcards(analysis))
//                .importantTopics(parseImportantTopics(analysis))
//                .importantSubtopics(parseImportantSubtopics(analysis))
//                .questions(parseQuestions(analysis))
//                .studyPlan(mapStudyPlan(studyPlan))
//                .build();
//    }
//
//    private List<KeyPointDto> parseKeyPoints(MaterialAnalysis analysis) {
//        if (analysis == null || analysis.getKeyPoints() == null || analysis.getKeyPoints().isBlank()) {
//            return Collections.emptyList();
//        }
//
//        try {
//            JsonNode root = objectMapper.readTree(analysis.getKeyPoints());
//
//            if (root.isArray()) {
//                return objectMapper.convertValue(root, new TypeReference<List<KeyPointDto>>() {});
//            }
//
//            JsonNode keyPointsNode = root.get("key_points");
//            if (keyPointsNode != null && keyPointsNode.isArray()) {
//                return objectMapper.convertValue(keyPointsNode, new TypeReference<List<KeyPointDto>>() {});
//            }
//
//            return Collections.emptyList();
//        } catch (Exception e) {
//            return Collections.emptyList();
//        }
//    }
//
//    private List<FlashcardDto> parseFlashcards(MaterialAnalysis analysis) {
//        if (analysis == null || analysis.getKeyPoints() == null || analysis.getKeyPoints().isBlank()) {
//            return Collections.emptyList();
//        }
//
//        try {
//            JsonNode root = objectMapper.readTree(analysis.getKeyPoints());
//
//            JsonNode flashcardsNode = root.get("flashcards");
//            if (flashcardsNode != null && flashcardsNode.isArray()) {
//                return objectMapper.convertValue(flashcardsNode, new TypeReference<List<FlashcardDto>>() {});
//            }
//
//            return Collections.emptyList();
//        } catch (Exception e) {
//            return Collections.emptyList();
//        }
//    }
//
//    private List<String> parseImportantTopics(MaterialAnalysis analysis) {
//        if (analysis == null || analysis.getImportantTopics() == null || analysis.getImportantTopics().isBlank()) {
//            return Collections.emptyList();
//        }
//
//        try {
//            JsonNode root = objectMapper.readTree(analysis.getImportantTopics());
//
//            JsonNode topicsNode = root.get("important_topics");
//            if (topicsNode != null && topicsNode.isArray()) {
//                return objectMapper.convertValue(topicsNode, new TypeReference<List<String>>() {});
//            }
//
//            return Collections.emptyList();
//        } catch (Exception e) {
//            return Collections.emptyList();
//        }
//    }
//
//    private List<String> parseImportantSubtopics(MaterialAnalysis analysis) {
//        if (analysis == null || analysis.getImportantTopics() == null || analysis.getImportantTopics().isBlank()) {
//            return Collections.emptyList();
//        }
//
//        try {
//            JsonNode root = objectMapper.readTree(analysis.getImportantTopics());
//
//            JsonNode subtopicsNode = root.get("important_subtopics");
//            if (subtopicsNode != null && subtopicsNode.isArray()) {
//                return objectMapper.convertValue(subtopicsNode, new TypeReference<List<String>>() {});
//            }
//
//            return Collections.emptyList();
//        } catch (Exception e) {
//            return Collections.emptyList();
//        }
//    }
//
//    private List<QuestionDto> parseQuestions(MaterialAnalysis analysis) {
//        if (analysis == null || analysis.getQuestions() == null || analysis.getQuestions().isBlank()) {
//            return Collections.emptyList();
//        }
//
//        try {
//            JsonNode root = objectMapper.readTree(analysis.getQuestions());
//
//            if (root.isArray()) {
//                return objectMapper.convertValue(root, new TypeReference<List<QuestionDto>>() {});
//            }
//
//            JsonNode questionsNode = root.get("questions");
//            if (questionsNode != null && questionsNode.isArray()) {
//                return objectMapper.convertValue(questionsNode, new TypeReference<List<QuestionDto>>() {});
//            }
//
//            return Collections.emptyList();
//        } catch (Exception e) {
//            return Collections.emptyList();
//        }
//    }
//
//    private List<StudyPlanDayDto> mapStudyPlan(MaterialStudyPlan studyPlan) {
//        if (studyPlan == null || studyPlan.getTasks() == null || studyPlan.getTasks().isEmpty()) {
//            return Collections.emptyList();
//        }
//
//        Map<String, List<MaterialStudyTask>> grouped = studyPlan.getTasks().stream()
//                .collect(Collectors.groupingBy(
//                        MaterialStudyTask::getDayLabel,
//                        LinkedHashMap::new,
//                        Collectors.toList()
//                ));
//
//        return grouped.entrySet().stream()
//                .map(entry -> StudyPlanDayDto.builder()
//                        .day(entry.getKey())
//                        .tasks(entry.getValue().stream()
//                                .map(task -> StudyPlanTaskDto.builder()
//                                        .id(task.getId())
//                                        .title(task.getTitle())
//                                        .description(task.getDescription())
//                                        .completed(task.isCompleted())
//                                        .build())
//                                .toList())
//                        .build())
//                .toList();
//    }
//}