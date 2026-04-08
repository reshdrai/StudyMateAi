package com.resh.studymateaibackend.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.resh.studymateaibackend.dto.study.*;
import com.resh.studymateaibackend.entity.Material;
import com.resh.studymateaibackend.entity.MaterialAnalysis;
import com.resh.studymateaibackend.entity.User;
import com.resh.studymateaibackend.repository.MaterialAnalysisRepository;
import com.resh.studymateaibackend.repository.MaterialRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class MaterialAiService {

    private final MaterialRepository materialRepository;
    private final MaterialAnalysisRepository materialAnalysisRepository;
    private final AiModelClient aiModelClient;
    private final ObjectMapper objectMapper;

    public OverviewResponseDto generateOverview(Long materialId, User user) throws Exception {
        try {
            System.out.println("STEP 1: Entered generateOverview");
            System.out.println("MATERIAL ID = " + materialId);

            Material material = getOwnedMaterial(materialId, user);
            System.out.println("STEP 2: Material loaded");

            String cleanedText = getCleanMaterialText(material);
            System.out.println("STEP 3: Cleaned text length = " + (cleanedText == null ? "null" : cleanedText.length()));

            if (cleanedText == null || cleanedText.isBlank()) {
                throw new RuntimeException("Material text is empty. Cannot generate overview.");
            }

            Map<String, Object> keyPointsResponse = aiModelClient.generateKeyPoints(cleanedText);
            System.out.println("STEP 4: Key points generated");

            Map<String, Object> importanceResponse = aiModelClient.rankImportance(cleanedText);
            System.out.println("STEP 5: Importance generated");

            List<FlashcardDto> flashcards = normalizeFlashcards(keyPointsResponse);
            List<TopicPriorityDto> topics = normalizeTopics(importanceResponse);
            System.out.println("STEP 6: Responses normalized");

            MaterialAnalysis analysis = getOrCreateAnalysis(material);
            analysis.setRawOutput(objectMapper.writeValueAsString(
                    Map.of(
                            "keyPointsResponse", keyPointsResponse,
                            "importanceResponse", importanceResponse
                    )
            ));
            analysis.setKeyPoints(objectMapper.writeValueAsString(flashcards));
            analysis.setImportantTopics(objectMapper.writeValueAsString(topics));
            analysis.setAnalyzedAt(LocalDateTime.now());
            materialAnalysisRepository.save(analysis);
            System.out.println("STEP 7: Analysis saved");

            material.setProcessingStatus("OVERVIEW_READY");
            materialRepository.save(material);
            System.out.println("STEP 8: Material saved");

            return OverviewResponseDto.builder()
                    .materialId(material.getId())
                    .flashcards(flashcards)
                    .importantTopics(topics)
                    .build();

        } catch (Exception e) {
            System.out.println("ERROR INSIDE generateOverview = " + e.getMessage());
            e.printStackTrace();
            throw e;
        }
    }

    public QuizResponseDto generateQuiz(Long materialId, User user) throws Exception {
        Material material = getOwnedMaterial(materialId, user);
        String cleanedText = getCleanMaterialText(material);

        MaterialAnalysis analysis = getOrCreateAnalysis(material);

        List<TopicPriorityDto> topics = readTopics(analysis);
        if (topics.isEmpty()) {
            OverviewResponseDto overview = generateOverview(materialId, user);
            topics = overview.getImportantTopics();
        }

        String topicLabel = "General Topic";
        String subtopicLabel = "General Subtopic";

        if (!topics.isEmpty()) {
            TopicPriorityDto mainTopic = topics.get(0);
            topicLabel = mainTopic.getTopic();
            if (mainTopic.getSubtopics() != null && !mainTopic.getSubtopics().isEmpty()) {
                subtopicLabel = mainTopic.getSubtopics().get(0);
            } else {
                subtopicLabel = topicLabel;
            }
        }

        Map<String, Object> quizResponse = aiModelClient.generateQuiz(
                cleanedText,
                null,
                topicLabel,
                subtopicLabel,
                5
        );

        List<QuizQuestionDto> questions = normalizeQuestions(quizResponse, topicLabel);

        analysis.setQuestions(objectMapper.writeValueAsString(questions));
        analysis.setAnalyzedAt(LocalDateTime.now());
        materialAnalysisRepository.save(analysis);

        material.setProcessingStatus("QUIZ_READY");
        materialRepository.save(material);

        return QuizResponseDto.builder()
                .materialId(material.getId())
                .questions(questions)
                .build();
    }

    public QuizResultDto submitQuiz(Long materialId, User user, QuizSubmitRequestDto request) throws Exception {
        Material material = getOwnedMaterial(materialId, user);
        MaterialAnalysis analysis = getOrCreateAnalysis(material);

        List<QuizQuestionDto> savedQuestions = readQuestions(analysis);
        if (savedQuestions.isEmpty()) {
            throw new IllegalStateException("No quiz found. Generate quiz first.");
        }

        Map<String, String> userAnswers = new HashMap<>();
        if (request.getAnswers() != null) {
            for (QuizAnswerDto answer : request.getAnswers()) {
                userAnswers.put(
                        safe(answer.getQuestion()).trim().toLowerCase(),
                        safe(answer.getUserAnswer()).trim().toLowerCase()
                );
            }
        }

        int correct = 0;
        Map<String, int[]> topicStats = new HashMap<>();

        for (QuizQuestionDto q : savedQuestions) {
            String qKey = safe(q.getQuestion()).trim().toLowerCase();
            String expected = safe(q.getAnswer()).trim().toLowerCase();
            String actual = userAnswers.getOrDefault(qKey, "");

            boolean isCorrect = !expected.isBlank() && actual.equals(expected);
            if (isCorrect) {
                correct++;
            }

            String topic = safe(q.getTopic()).isBlank() ? "General" : q.getTopic();
            topicStats.putIfAbsent(topic, new int[]{0, 0});
            topicStats.get(topic)[0]++;

            if (isCorrect) {
                topicStats.get(topic)[1]++;
            }
        }

        List<String> weakTopics = new ArrayList<>();
        for (Map.Entry<String, int[]> entry : topicStats.entrySet()) {
            int total = entry.getValue()[0];
            int right = entry.getValue()[1];
            double ratio = total == 0 ? 0 : (double) right / total;

            if (ratio < 0.6) {
                weakTopics.add(entry.getKey());
            }
        }

        analysis.setWeakTopics(objectMapper.writeValueAsString(weakTopics));
        analysis.setAnalyzedAt(LocalDateTime.now());
        materialAnalysisRepository.save(analysis);

        material.setProcessingStatus("QUIZ_DONE");
        materialRepository.save(material);

        int totalQuestions = savedQuestions.size();
        double scorePercent = totalQuestions == 0 ? 0 : (correct * 100.0 / totalQuestions);

        return QuizResultDto.builder()
                .totalQuestions(totalQuestions)
                .correctAnswers(correct)
                .scorePercent(scorePercent)
                .weakTopics(weakTopics)
                .build();
    }

    public StudyPlanResponseDto generateStudyPlan(Long materialId, User user) throws Exception {
        Material material = getOwnedMaterial(materialId, user);
        MaterialAnalysis analysis = getOrCreateAnalysis(material);

        List<String> weakTopics = readWeakTopics(analysis);
        List<TopicPriorityDto> importantTopics = readTopics(analysis);

        List<StudyPlanDayDto> days = buildStudyPlan(weakTopics, importantTopics);

        analysis.setStudyPlan(objectMapper.writeValueAsString(days));
        analysis.setAnalyzedAt(LocalDateTime.now());
        materialAnalysisRepository.save(analysis);

        material.setProcessingStatus("PLAN_READY");
        materialRepository.save(material);

        return StudyPlanResponseDto.builder()
                .materialId(material.getId())
                .days(days)
                .build();
    }

    private Material getOwnedMaterial(Long materialId, User user) {
        Material material = materialRepository.findById(materialId)
                .orElseThrow(() -> new RuntimeException("Material not found"));

        if (material.getUser() == null || user == null || !material.getUser().getId().equals(user.getId())) {
            throw new AccessDeniedException("User cannot access the material");
        }

        return material;
    }

    private MaterialAnalysis getOrCreateAnalysis(Material material) {
        return materialAnalysisRepository.findByMaterialId(material.getId())
                .orElse(MaterialAnalysis.builder().material(material).build());
    }

    private String getCleanMaterialText(Material material) {
        String extractedText = material.getExtractedText();
        if (!StringUtils.hasText(extractedText)) {
            throw new IllegalStateException("Material extracted text is empty.");
        }

        return extractedText
                .replace("\u0000", "")
                .replaceAll("[\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F\\x7F]", "")
                .replaceAll("[^\\p{Print}\\r\\n\\t]", " ")
                .replaceAll("\\s+", " ")
                .trim();
    }

    private List<StudyPlanDayDto> buildStudyPlan(List<String> weakTopics, List<TopicPriorityDto> importantTopics) {
        List<String> priorityOrderedTopics = importantTopics.stream()
                .sorted((a, b) -> Integer.compare(priorityWeight(b.getPriority()), priorityWeight(a.getPriority())))
                .map(TopicPriorityDto::getTopic)
                .distinct()
                .collect(Collectors.toList());

        LinkedHashSet<String> ordered = new LinkedHashSet<>();
        ordered.addAll(weakTopics);
        ordered.addAll(priorityOrderedTopics);

        List<String> finalTopics = new ArrayList<>(ordered);
        if (finalTopics.isEmpty()) {
            finalTopics.add("General Revision");
        }

        List<StudyPlanDayDto> plan = new ArrayList<>();
        int day = 1;

        for (String topic : finalTopics) {
            plan.add(StudyPlanDayDto.builder()
                    .day("Day " + day++)
                    .tasks(List.of(
                            "Read notes for " + topic,
                            "Review flashcards for " + topic,
                            "Practice quiz again for " + topic
                    ))
                    .build());
        }

        return plan;
    }

    private List<FlashcardDto> normalizeFlashcards(Map<String, Object> response) {
        Object flashcardsObj = response.get("flashcards");

        if (flashcardsObj instanceof List<?> list && !list.isEmpty()) {
            List<FlashcardDto> result = new ArrayList<>();
            for (Object item : list) {
                if (item instanceof Map<?, ?> map) {
                    result.add(FlashcardDto.builder()
                            .front(safe(map.get("front")))
                            .back(safe(map.get("back")))
                            .build());
                }
            }
            if (!result.isEmpty()) return result;
        }

        Object keyPointsObj = response.get("key_points");
        if (keyPointsObj instanceof List<?> list && !list.isEmpty()) {
            List<FlashcardDto> result = new ArrayList<>();
            for (Object item : list) {
                String text = safe(item);
                if (!text.isBlank()) {
                    result.add(FlashcardDto.builder()
                            .front(text)
                            .back("Review this key point.")
                            .build());
                }
            }
            return result;
        }

        return new ArrayList<>();
    }

    private List<TopicPriorityDto> normalizeTopics(Map<String, Object> response) {
        Object topicsObj = response.get("topics");
        if (!(topicsObj instanceof List<?> list)) {
            return new ArrayList<>();
        }

        List<TopicPriorityDto> result = new ArrayList<>();

        for (Object item : list) {
            if (!(item instanceof Map<?, ?> map)) continue;

            String topic = safe(firstNonNull(map.get("topic"), map.get("topic_label")));
            String priority = safe(firstNonNull(map.get("priority"), map.get("importance"), "MEDIUM"));
            Double score = parseDouble(firstNonNull(map.get("score"), map.get("importance_score")));

            List<String> subtopics = new ArrayList<>();
            Object subtopicsObj = map.get("subtopics");
            if (subtopicsObj instanceof List<?> subList) {
                for (Object sub : subList) {
                    subtopics.add(safe(sub));
                }
            }

            if (!topic.isBlank()) {
                result.add(TopicPriorityDto.builder()
                        .topic(topic)
                        .priority(priority.toUpperCase())
                        .score(score)
                        .subtopics(subtopics)
                        .build());
            }
        }

        result.sort((a, b) -> Integer.compare(priorityWeight(b.getPriority()), priorityWeight(a.getPriority())));
        return result;
    }

    private List<QuizQuestionDto> normalizeQuestions(Map<String, Object> response, String defaultTopic) {
        Object questionsObj = response.get("questions");
        if (!(questionsObj instanceof List<?> list)) {
            return new ArrayList<>();
        }

        List<QuizQuestionDto> result = new ArrayList<>();

        for (Object item : list) {
            if (!(item instanceof Map<?, ?> map)) continue;

            List<String> options = new ArrayList<>();
            Object optionsObj = map.get("options");
            if (optionsObj instanceof List<?> optionList) {
                for (Object option : optionList) {
                    options.add(safe(option));
                }
            }

            result.add(QuizQuestionDto.builder()
                    .question(safe(firstNonNull(map.get("question"), map.get("text"))))
                    .answer(safe(map.get("answer")))
                    .topic(safe(firstNonNull(map.get("topic"), defaultTopic)))
                    .options(options)
                    .build());
        }

        return result;
    }

    private List<TopicPriorityDto> readTopics(MaterialAnalysis analysis) {
        try {
            if (!StringUtils.hasText(analysis.getImportantTopics())) return new ArrayList<>();
            return objectMapper.readValue(analysis.getImportantTopics(), new TypeReference<List<TopicPriorityDto>>() {});
        } catch (Exception e) {
            return new ArrayList<>();
        }
    }

    private List<QuizQuestionDto> readQuestions(MaterialAnalysis analysis) {
        try {
            if (!StringUtils.hasText(analysis.getQuestions())) return new ArrayList<>();
            return objectMapper.readValue(analysis.getQuestions(), new TypeReference<List<QuizQuestionDto>>() {});
        } catch (Exception e) {
            return new ArrayList<>();
        }
    }

    private List<String> readWeakTopics(MaterialAnalysis analysis) {
        try {
            if (!StringUtils.hasText(analysis.getWeakTopics())) return new ArrayList<>();
            return objectMapper.readValue(analysis.getWeakTopics(), new TypeReference<List<String>>() {});
        } catch (Exception e) {
            return new ArrayList<>();
        }
    }

    private int priorityWeight(String priority) {
        if (priority == null) return 0;
        return switch (priority.toUpperCase()) {
            case "HIGH" -> 3;
            case "MEDIUM" -> 2;
            case "LOW" -> 1;
            default -> 0;
        };
    }

    private String safe(Object value) {
        return value == null ? "" : value.toString();
    }

    private Object firstNonNull(Object... values) {
        for (Object value : values) {
            if (value != null) return value;
        }
        return null;
    }

    private Double parseDouble(Object value) {
        if (value == null) return null;
        try {
            return Double.parseDouble(value.toString());
        } catch (Exception e) {
            return null;
        }
    }
}