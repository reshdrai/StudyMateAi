package com.resh.studymateaibackend.controller;

import com.resh.studymateaibackend.auth.CustomUserDetails;
import com.resh.studymateaibackend.entity.User;
import com.resh.studymateaibackend.service.StudyPlanService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/materials")
@RequiredArgsConstructor
public class StudyPlanController {

    private final StudyPlanService studyPlanService;

    /**
     * Generate a new study plan using genetic algorithm.
     * Auto-reschedules any missed tasks from previous plan.
     */
    @PostMapping("/{id}/study-plan/generate")
    public ResponseEntity<Map<String, Object>> generateStudyPlan(
            @PathVariable Long id,
            @AuthenticationPrincipal CustomUserDetails userDetails
    ) throws Exception {
        User user = userDetails.getUser();
        Map<String, Object> plan = studyPlanService.generatePlan(id, user);
        return ResponseEntity.ok(plan);
    }

    /**
     * Get existing study plan without regenerating.
     */
    @GetMapping("/{id}/study-plan")
    public ResponseEntity<Map<String, Object>> getStudyPlan(
            @PathVariable Long id,
            @AuthenticationPrincipal CustomUserDetails userDetails
    ) {
        User user = userDetails.getUser();
        Map<String, Object> plan = studyPlanService.getExistingPlan(id, user);
        return ResponseEntity.ok(plan);
    }

    /**
     * Reschedule: regenerate plan, moving missed tasks to upcoming days.
     */
    @PostMapping("/{id}/study-plan/reschedule")
    public ResponseEntity<Map<String, Object>> reschedule(
            @PathVariable Long id,
            @AuthenticationPrincipal CustomUserDetails userDetails
    ) throws Exception {
        User user = userDetails.getUser();
        Map<String, Object> plan = studyPlanService.reschedule(id, user);
        return ResponseEntity.ok(plan);
    }

    /**
     * Mark a task as completed or uncompleted.
     */
    @PatchMapping("/study-plan/tasks/{taskId}")
    public ResponseEntity<Map<String, Object>> toggleTask(
            @PathVariable Long taskId,
            @RequestBody Map<String, Boolean> body,
            @AuthenticationPrincipal CustomUserDetails userDetails
    ) {
        User user = userDetails.getUser();
        boolean completed = body.getOrDefault("completed", false);
        studyPlanService.markTaskCompleted(taskId, completed, user);
        return ResponseEntity.ok(Map.of("taskId", taskId, "completed", completed));
    }
}
