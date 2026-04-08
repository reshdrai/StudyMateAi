package com.resh.studymateaibackend.controller;

import com.resh.studymateaibackend.auth.CustomUserDetails;
import com.resh.studymateaibackend.dto.study.*;
import com.resh.studymateaibackend.entity.User;
import com.resh.studymateaibackend.service.MaterialAiService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/materials")
@RequiredArgsConstructor
public class MaterialAiController {

    private final MaterialAiService materialAiService;

    @PostMapping("/{id}/overview")
    public ResponseEntity<OverviewResponseDto> generateOverview(
            @PathVariable Long id,
            @AuthenticationPrincipal CustomUserDetails userDetails
    )  throws Exception {
        System.out.println("ENTERED /overview FOR ID = " + id);
        User user = userDetails.getUser();
        return ResponseEntity.ok(materialAiService.generateOverview(id, user));
    }

    @PostMapping("/{id}/quiz")
    public ResponseEntity<QuizResponseDto> generateQuiz(
            @PathVariable Long id,
            @AuthenticationPrincipal CustomUserDetails userDetails
    ) throws Exception {
        User user = userDetails.getUser();
        return ResponseEntity.ok(materialAiService.generateQuiz(id, user));
    }

    @PostMapping("/{id}/quiz/submit")
    public ResponseEntity<QuizResultDto> submitQuiz(
            @PathVariable Long id,
            @RequestBody QuizSubmitRequestDto request,
            @AuthenticationPrincipal CustomUserDetails userDetails
    ) throws Exception {
        User user = userDetails.getUser();
        return ResponseEntity.ok(materialAiService.submitQuiz(id, user, request));
    }

    @PostMapping("/{id}/study-plan")
    public ResponseEntity<StudyPlanResponseDto> generateStudyPlan(
            @PathVariable Long id,
            @AuthenticationPrincipal CustomUserDetails userDetails
    ) throws Exception {
        User user = userDetails.getUser();
        return ResponseEntity.ok(materialAiService.generateStudyPlan(id, user));
    }
}