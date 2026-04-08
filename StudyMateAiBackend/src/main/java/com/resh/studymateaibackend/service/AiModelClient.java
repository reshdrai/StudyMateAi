package com.resh.studymateaibackend.service;

import lombok.RequiredArgsConstructor;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.HashMap;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class AiModelClient {

    private final RestTemplate restTemplate;

    private final String baseUrl = "http://127.0.0.1:8000";

    public Map<String, Object> generateKeyPoints(String text) {
        return post("/generate_keypoints", Map.of("text", text));
    }

    public Map<String, Object> rankImportance(String text) {
        return post("/rank_importance", Map.of("text", text));
    }

    public Map<String, Object> generateQuiz(String text, Object chunks, String topicLabel, String subtopicLabel, int numQuestions) {
        Map<String, Object> body = new HashMap<>();
        body.put("text", text);
        body.put("chunks", chunks);
        body.put("topic_label", topicLabel);
        body.put("subtopic_label", subtopicLabel);
        body.put("num_questions", numQuestions);
        return post("/generate_quiz", body);
    }

    private Map<String, Object> post(String path, Map<String, Object> body) {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        HttpEntity<Map<String, Object>> entity = new HttpEntity<>(body, headers);

        ResponseEntity<Map<String, Object>> response = restTemplate.exchange(
                baseUrl + path,
                HttpMethod.POST,
                entity,
                new ParameterizedTypeReference<>() {}
        );

        return response.getBody() == null ? Map.of() : response.getBody();
    }
}