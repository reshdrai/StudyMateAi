package com.resh.studymateaibackend.service;

import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.time.Duration;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class AiModelClient {

    private final RestTemplate restTemplate;

    @Value("${ai.service.base-url:http://127.0.0.1:8000}")
    private String baseUrl;

    /**
     * POST /generate_keypoints
     * Body: { "text": "..." }
     * Returns: { "key_points": [...], "flashcards": [...] }
     */
    public Map<String, Object> generateKeyPoints(String text) {
        return post("/generate_keypoints", Map.of("text", truncate(text)));
    }

    /**
     * POST /rank_importance
     * Body: { "text": "..." }
     * Returns: { "important_topics": [...], "important_subtopics": [...] }
     */
    public Map<String, Object> rankImportance(String text) {
        return post("/rank_importance", Map.of("text", truncate(text)));
    }

    /**
     * POST /generate_quiz
     * Body matches QuizRequest pydantic model
     */
    public Map<String, Object> generateQuiz(
            String extractedText,
            Object chunks,
            String topicLabel,
            String subtopicLabel,
            int maxQuestions
    ) {
        Map<String, Object> body = new HashMap<>();
        body.put("extracted_text", truncate(extractedText));
        body.put("topic_label", topicLabel != null ? topicLabel : "General Topic");
        body.put("subtopic_label", subtopicLabel);
        body.put("max_questions", maxQuestions);

        // chunks can be null - the FastAPI endpoint handles this
        if (chunks != null) {
            body.put("chunks", chunks);
        }

        return post("/generate_quiz", body);
    }

    /**
     * POST /process_notes
     * Body: { "text": "..." }
     * Returns structured notes with chunks and topics
     */
    public Map<String, Object> processNotes(String text) {
        return post("/process_notes", Map.of("text", truncate(text)));
    }

    /**
     * Health check
     */
    public boolean isHealthy() {
        try {
            ResponseEntity<Map<String, Object>> response = restTemplate.exchange(
                    baseUrl + "/health",
                    HttpMethod.GET,
                    null,
                    new ParameterizedTypeReference<>() {}
            );
            return response.getStatusCode().is2xxSuccessful();
        } catch (Exception e) {
            return false;
        }
    }

    private Map<String, Object> post(String path, Map<String, Object> body) {
        try {
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            HttpEntity<Map<String, Object>> entity = new HttpEntity<>(body, headers);

            System.out.println("AI REQUEST: POST " + baseUrl + path);

            ResponseEntity<Map<String, Object>> response = restTemplate.exchange(
                    baseUrl + path,
                    HttpMethod.POST,
                    entity,
                    new ParameterizedTypeReference<>() {}
            );

            Map<String, Object> result = response.getBody();
            System.out.println("AI RESPONSE STATUS: " + response.getStatusCode());

            return result == null ? Map.of() : result;

        } catch (Exception e) {
            System.out.println("AI SERVICE ERROR for " + path + ": " + e.getMessage());
            e.printStackTrace();
            return Map.of();
        }
    }

    private String truncate(String text) {
        if (text == null) return "";
        return text.length() > 50000 ? text.substring(0, 50000) : text;
    }
}
