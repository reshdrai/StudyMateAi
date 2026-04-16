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
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional
public class MaterialAiService {

    private final MaterialRepository materialRepository;
    private final MaterialAnalysisRepository materialAnalysisRepository;
    private final AiModelClient aiModelClient;
    private final ObjectMapper objectMapper;

    // ========== OVERVIEW ==========

    public OverviewResponseDto generateOverview(Long materialId, User user) throws Exception {
        Material material = getOwnedMaterial(materialId, user);
        String cleanedText = getCleanMaterialText(material);

        if (cleanedText.startsWith("%PDF") || cleanedText.startsWith("JVBERi")) {
            throw new RuntimeException("Raw PDF data detected. Please re-upload the file.");
        }
        if (cleanedText.length() < 20) {
            throw new RuntimeException("Text too short (" + cleanedText.length() + " chars). PDF may need OCR.");
        }

        System.out.println("AI: Calling keypoints for text length=" + cleanedText.length());
        Map<String, Object> keyPointsResponse = aiModelClient.generateKeyPoints(cleanedText);
        System.out.println("AI: keypoints keys=" + keyPointsResponse.keySet());

        System.out.println("AI: Calling rank_importance...");
        Map<String, Object> importanceResponse = aiModelClient.rankImportance(cleanedText);
        System.out.println("AI: importance keys=" + importanceResponse.keySet());

        if (keyPointsResponse.isEmpty() && importanceResponse.isEmpty()) {
            throw new RuntimeException("AI service returned empty. Python server may still be starting.");
        }

        List<FlashcardDto> flashcards = parseFlashcards(keyPointsResponse);
        List<TopicPriorityDto> topics = parseImportantTopics(importanceResponse);

        System.out.println("AI: Parsed " + flashcards.size() + " flashcards, " + topics.size() + " topics");

        MaterialAnalysis analysis = getOrCreateAnalysis(material);
        analysis.setRawOutput(objectMapper.writeValueAsString(Map.of(
                "keyPointsResponse", keyPointsResponse,
                "importanceResponse", importanceResponse
        )));
        analysis.setKeyPoints(objectMapper.writeValueAsString(flashcards));
        analysis.setImportantTopics(objectMapper.writeValueAsString(topics));
        analysis.setAnalyzedAt(LocalDateTime.now());
        materialAnalysisRepository.save(analysis);

        material.setProcessingStatus("OVERVIEW_READY");
        materialRepository.save(material);

        return OverviewResponseDto.builder()
                .materialId(material.getId())
                .flashcards(flashcards)
                .importantTopics(topics)
                .build();
    }



    public QuizResponseDto generateQuiz(Long materialId, User user) throws Exception {
        return generateQuizForTopic(materialId, user, "ALL", null, 5, 1);
    }

    public QuizResponseDto generateQuizForTopic(Long materialId, User user,
                                                String topicLabel, String subtopicLabel,
                                                int maxQuestions, int attemptNumber) throws Exception {
        Material material = getOwnedMaterial(materialId, user);
        String cleanedText = getCleanMaterialText(material);

        MaterialAnalysis analysis = getOrCreateAnalysis(material);

        // Ensure overview exists
        if (readTopics(analysis).isEmpty()) {
            generateOverview(materialId, user);
            analysis = getOrCreateAnalysis(material);
        }

        // Always fall back to ALL if no specific topic given
        String effectiveTopic = (topicLabel == null || topicLabel.isBlank()
                || topicLabel.equalsIgnoreCase("general topic"))
                ? "ALL" : topicLabel;

        Map<String, Object> quizResponse = aiModelClient.generateQuiz(
                cleanedText, null, effectiveTopic, subtopicLabel, maxQuestions
        );

        List<QuizQuestionDto> questions = parseQuizQuestions(quizResponse);

        if (attemptNumber > 1 && questions.size() > 1) {
            questions = shuffleQuestionsForAttempt(questions, attemptNumber, materialId);
        }

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

    /**
     * Shuffle and rotate questions based on attempt number so each attempt
     * gets a different set/order of questions.
     */
    private List<QuizQuestionDto> shuffleQuestionsForAttempt(
            List<QuizQuestionDto> questions, int attemptNumber, Long materialId) {

        // Use materialId + attemptNumber as seed for deterministic but different shuffles
        long seed = materialId * 1000L + attemptNumber * 37L;
        Random rng = new Random(seed);

        List<QuizQuestionDto> shuffled = new ArrayList<>(questions);
        Collections.shuffle(shuffled, rng);

        // Also rotate options within each question for variety
        List<QuizQuestionDto> result = new ArrayList<>();
        for (QuizQuestionDto q : shuffled) {
            List<String> opts = new ArrayList<>(q.getOptions());
            String correctAnswer = q.getAnswer();

            // Shuffle options
            Collections.shuffle(opts, rng);

            result.add(QuizQuestionDto.builder()
                    .question(q.getQuestion())
                    .answer(correctAnswer)
                    .topic(q.getTopic())
                    .options(opts)
                    .build());
        }

        return result;
    }

    // ========== QUIZ SUBMIT ==========

    public QuizResultDto submitQuiz(Long materialId, User user, QuizSubmitRequestDto request) throws Exception {
        Material material = getOwnedMaterial(materialId, user);
        MaterialAnalysis analysis = getOrCreateAnalysis(material);

        List<QuizQuestionDto> saved = readQuestions(analysis);
        if (saved.isEmpty()) throw new IllegalStateException("No quiz found. Generate quiz first.");

        Map<String, String> answers = new HashMap<>();
        if (request.getAnswers() != null) {
            for (QuizAnswerDto a : request.getAnswers()) {
                answers.put(safe(a.getQuestion()).trim().toLowerCase(),
                        safe(a.getUserAnswer()).trim().toLowerCase());
            }
        }

        int correct = 0;
        Map<String, int[]> stats = new HashMap<>();

        for (QuizQuestionDto q : saved) {
            String key = safe(q.getQuestion()).trim().toLowerCase();
            String expected = safe(q.getAnswer()).trim().toLowerCase();
            String actual = answers.getOrDefault(key, "");
            boolean ok = !expected.isBlank() && actual.equals(expected);
            if (ok) correct++;

            String topic = safe(q.getTopic()).isBlank() ? "General" : q.getTopic();
            stats.putIfAbsent(topic, new int[]{0, 0});
            stats.get(topic)[0]++;
            if (ok) stats.get(topic)[1]++;
        }

        List<String> weak = stats.entrySet().stream()
                .filter(e -> e.getValue()[0] > 0 && (double) e.getValue()[1] / e.getValue()[0] < 0.6)
                .map(Map.Entry::getKey)
                .collect(Collectors.toList());

        analysis.setWeakTopics(objectMapper.writeValueAsString(weak));
        analysis.setAnalyzedAt(LocalDateTime.now());
        materialAnalysisRepository.save(analysis);

        material.setProcessingStatus("QUIZ_DONE");
        materialRepository.save(material);

        double pct = saved.isEmpty() ? 0 : (correct * 100.0 / saved.size());
        return QuizResultDto.builder()
                .totalQuestions(saved.size()).correctAnswers(correct)
                .scorePercent(pct).weakTopics(weak).build();
    }

    // ========== STUDY PLAN ==========

    public StudyPlanResponseDto generateStudyPlan(Long materialId, User user) throws Exception {
        Material material = getOwnedMaterial(materialId, user);
        MaterialAnalysis analysis = getOrCreateAnalysis(material);

        List<String> weak = readWeakTopics(analysis);
        List<TopicPriorityDto> topics = readTopics(analysis);

        LinkedHashSet<String> ordered = new LinkedHashSet<>(weak);
        topics.stream()
                .sorted((a, b) -> Integer.compare(pw(b.getPriority()), pw(a.getPriority())))
                .map(TopicPriorityDto::getTopic)
                .forEach(ordered::add);

        List<String> finalTopics = new ArrayList<>(ordered);
        if (finalTopics.isEmpty()) finalTopics.add("General Revision");

        List<StudyPlanDayDto> days = new ArrayList<>();
        int d = 1;
        for (String t : finalTopics) {
            days.add(StudyPlanDayDto.builder().day("Day " + d++)
                    .tasks(List.of("Read notes for " + t, "Review flashcards for " + t, "Practice quiz for " + t))
                    .build());
        }

        analysis.setStudyPlan(objectMapper.writeValueAsString(days));
        materialAnalysisRepository.save(analysis);
        material.setProcessingStatus("PLAN_READY");
        materialRepository.save(material);

        return StudyPlanResponseDto.builder().materialId(material.getId()).days(days).build();
    }

    // ═══════════════════════════════════════
    // RESPONSE PARSING
    // ═══════════════════════════════════════

    private List<FlashcardDto> parseFlashcards(Map<String, Object> resp) {
        List<FlashcardDto> result = new ArrayList<>();

        if (resp.get("flashcards") instanceof List<?> list) {
            for (Object item : list) {
                if (item instanceof Map<?, ?> m) {
                    String f = safe(m.get("front")), b = safe(m.get("back"));
                    if (!f.isBlank() && !b.isBlank())
                        result.add(FlashcardDto.builder().front(f).back(b).build());
                }
            }
        }

        if (result.isEmpty() && resp.get("key_points") instanceof List<?> list) {
            for (Object item : list) {
                if (item instanceof Map<?, ?> m) {
                    String text = safe(m.get("text"));
                    String topic = safe(m.get("topic_label"));
                    if (!text.isBlank())
                        result.add(FlashcardDto.builder()
                                .front("Key: " + (topic.isBlank() ? "Study" : topic))
                                .back(text).build());
                }
            }
        }

        return result;
    }

    private List<TopicPriorityDto> parseImportantTopics(Map<String, Object> resp) {
        List<TopicPriorityDto> result = new ArrayList<>();

        List<String> topicNames = new ArrayList<>();
        if (resp.get("important_topics") instanceof List<?> list) {
            for (Object item : list) {
                String s = safe(item);
                if (!s.isBlank()) topicNames.add(s);
            }
        }

        List<String> subtopicNames = new ArrayList<>();
        if (resp.get("important_subtopics") instanceof List<?> list) {
            for (Object item : list) {
                String s = safe(item);
                if (!s.isBlank()) subtopicNames.add(s);
            }
        }

        int total = topicNames.size();
        for (int i = 0; i < total; i++) {
            String name = topicNames.get(i);

            String priority;
            if (total <= 2) {
                priority = "HIGH";
            } else if (i < total / 3.0) {
                priority = "HIGH";
            } else if (i < total * 2.0 / 3.0) {
                priority = "MEDIUM";
            } else {
                priority = "LOW";
            }

            double score = (total - i) * 2.0;

            List<String> matchedSubs = new ArrayList<>();
            String nameLower = name.toLowerCase();
            for (String sub : subtopicNames) {
                if (sub.toLowerCase().contains(nameLower) || nameLower.contains(sub.toLowerCase())) {
                    matchedSubs.add(sub);
                }
            }
            if (matchedSubs.isEmpty()) {
                matchedSubs.add(name);
            }

            result.add(TopicPriorityDto.builder()
                    .topic(name)
                    .priority(priority)
                    .score(score)
                    .subtopics(matchedSubs)
                    .build());
        }

        return result;
    }

    private List<QuizQuestionDto> parseQuizQuestions(Map<String, Object> resp) {
        List<QuizQuestionDto> result = new ArrayList<>();
        if (!(resp.get("questions") instanceof List<?> list)) return result;

        for (Object item : list) {
            if (!(item instanceof Map<?, ?> m)) continue;

            List<String> opts = new ArrayList<>();
            String a = safe(m.get("option_a")), b = safe(m.get("option_b")), c = safe(m.get("option_c"));
            if (!a.isBlank()) opts.add(a);
            if (!b.isBlank()) opts.add(b);
            if (!c.isBlank()) opts.add(c);

            String correct = safe(m.get("correct_option")).toUpperCase();
            String answer = switch (correct) {
                case "B" -> b;
                case "C" -> c;
                default -> a;
            };

            String q = safe(m.get("question"));
            String topic = safe(m.get("topic_label"));

            if (!q.isBlank()) {
                result.add(QuizQuestionDto.builder()
                        .question(q).answer(answer).topic(topic).options(opts).build());
            }
        }
        return result;
    }

    // ═══════════════════════════════════════
    // HELPERS
    // ═══════════════════════════════════════

    private Material getOwnedMaterial(Long materialId, User user) {
        Material m = materialRepository.findById(materialId)
                .orElseThrow(() -> new RuntimeException("Material not found"));
        if (m.getUser() == null || user == null || !m.getUser().getId().equals(user.getId()))
            throw new AccessDeniedException("Access denied");
        return m;
    }

    private MaterialAnalysis getOrCreateAnalysis(Material m) {
        return materialAnalysisRepository.findByMaterialId(m.getId())
                .orElse(MaterialAnalysis.builder().material(m).build());
    }

    private String getCleanMaterialText(Material m) {
        String t = m.getExtractedText();
        if (!StringUtils.hasText(t)) throw new IllegalStateException("No extracted text.");
        return t.replace("\u0000", "")
                .replaceAll("[\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F\\x7F]", "")
                .replaceAll("[^\\p{Print}\\r\\n\\t]", " ")
                .trim();
    }

    private List<TopicPriorityDto> readTopics(MaterialAnalysis a) {
        try {
            if (a == null || !StringUtils.hasText(a.getImportantTopics())) return new ArrayList<>();
            return objectMapper.readValue(a.getImportantTopics(), new TypeReference<>() {});
        } catch (Exception e) { return new ArrayList<>(); }
    }

    private List<QuizQuestionDto> readQuestions(MaterialAnalysis a) {
        try {
            if (a == null || !StringUtils.hasText(a.getQuestions())) return new ArrayList<>();
            return objectMapper.readValue(a.getQuestions(), new TypeReference<>() {});
        } catch (Exception e) { return new ArrayList<>(); }
    }

    private List<String> readWeakTopics(MaterialAnalysis a) {
        try {
            if (a == null || !StringUtils.hasText(a.getWeakTopics())) return new ArrayList<>();
            return objectMapper.readValue(a.getWeakTopics(), new TypeReference<>() {});
        } catch (Exception e) { return new ArrayList<>(); }
    }

    private int pw(String p) {
        if (p == null) return 0;
        return switch (p.toUpperCase()) { case "HIGH" -> 3; case "MEDIUM" -> 2; case "LOW" -> 1; default -> 0; };
    }

    private String safe(Object v) { return v == null ? "" : v.toString(); }
}