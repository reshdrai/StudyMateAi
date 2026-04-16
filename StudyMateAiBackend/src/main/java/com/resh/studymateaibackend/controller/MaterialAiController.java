package com.resh.studymateaibackend.controller;

import com.resh.studymateaibackend.auth.CustomUserDetails;
import com.resh.studymateaibackend.dto.study.*;
import com.resh.studymateaibackend.entity.User;
import com.resh.studymateaibackend.service.MaterialAiService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/materials")
@RequiredArgsConstructor
public class MaterialAiController {

    private final MaterialAiService materialAiService;

    @PostMapping("/{id}/overview")
    public ResponseEntity<OverviewResponseDto> generateOverview(
            @PathVariable Long id,
            @AuthenticationPrincipal CustomUserDetails userDetails
    ) throws Exception {
        return ResponseEntity.ok(materialAiService.generateOverview(id, userDetails.getUser()));
    }

    /** Generate quiz from ALL topics */
    @PostMapping("/{id}/quiz")
    public ResponseEntity<QuizResponseDto> generateQuiz(
            @PathVariable Long id,
            @AuthenticationPrincipal CustomUserDetails userDetails
    ) throws Exception {
        return ResponseEntity.ok(materialAiService.generateQuiz(id, userDetails.getUser()));
    }

    /** Generate quiz for a SPECIFIC topic, supports attemptNumber for different questions */
    @PostMapping("/{id}/quiz/topic")
    public ResponseEntity<QuizResponseDto> generateQuizForTopic(
            @PathVariable Long id,
            @RequestBody Map<String, Object> body,
            @AuthenticationPrincipal CustomUserDetails userDetails
    ) throws Exception {
        String topicLabel = body.getOrDefault("topicLabel", "ALL").toString();
        String subtopicLabel = body.containsKey("subtopicLabel") ? body.get("subtopicLabel").toString() : null;
        int maxQuestions = body.containsKey("maxQuestions") ? Integer.parseInt(body.get("maxQuestions").toString()) : 5;
        int attemptNumber = body.containsKey("attemptNumber") ? Integer.parseInt(body.get("attemptNumber").toString()) : 1;

        return ResponseEntity.ok(
                materialAiService.generateQuizForTopic(
                        id, userDetails.getUser(), topicLabel, subtopicLabel, maxQuestions, attemptNumber
                )
        );
    }

    @PostMapping("/{id}/quiz/submit")
    public ResponseEntity<QuizResultDto> submitQuiz(
            @PathVariable Long id,
            @RequestBody QuizSubmitRequestDto request,
            @AuthenticationPrincipal CustomUserDetails userDetails
    ) throws Exception {
        return ResponseEntity.ok(materialAiService.submitQuiz(id, userDetails.getUser(), request));
    }

    @PostMapping("/{id}/study-plan")
    public ResponseEntity<StudyPlanResponseDto> generateStudyPlan(
            @PathVariable Long id,
            @AuthenticationPrincipal CustomUserDetails userDetails
    ) throws Exception {
        return ResponseEntity.ok(materialAiService.generateStudyPlan(id, userDetails.getUser()));
    }
}