package com.resh.studymateaibackend.controller;

import com.resh.studymateaibackend.auth.CustomUserDetails;
import com.resh.studymateaibackend.entity.*;
import com.resh.studymateaibackend.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/progress")
@RequiredArgsConstructor
public class ProgressController {

    private final MaterialRepository materialRepository;
    private final MaterialStudyPlanRepository materialStudyPlanRepository;
    private final QuizAttemptRepository quizAttemptRepository;

    @GetMapping("/analytics")
    public ResponseEntity<Map<String, Object>> getAnalytics(
            @AuthenticationPrincipal CustomUserDetails userDetails
    ) {
        User user = userDetails.getUser();
        Long userId = user.getId();

        // ── Study plan progress ──
        int totalTasks = 0;
        int completedTasks = 0;
        Map<String, int[]> subjectProgress = new LinkedHashMap<>(); // name -> [total, completed]

        List<Material> materials = materialRepository.findByUserId(userId);
        for (Material material : materials) {
            Optional<MaterialStudyPlan> planOpt = materialStudyPlanRepository.findByMaterialId(material.getId());
            if (planOpt.isEmpty()) continue;

            MaterialStudyPlan plan = planOpt.get();
            if (plan.getTasks() == null) continue;

            String subjectName = material.getSubject() != null ? material.getSubject().getName() : "General";

            for (MaterialStudyTask task : plan.getTasks()) {
                totalTasks++;
                subjectProgress.putIfAbsent(subjectName, new int[]{0, 0});
                subjectProgress.get(subjectName)[0]++;

                if (task.isCompleted()) {
                    completedTasks++;
                    subjectProgress.get(subjectName)[1]++;
                }
            }
        }

        // ── Streak (consecutive days with completed tasks) ──
        int streakDays = calculateStreak(materials);

        // ── Study hours estimate (completed tasks * avg 25 min) ──
        double studyHours = (completedTasks * 25.0) / 60.0;

        // ── Overall mastery ──
        double overallMastery = totalTasks > 0 ? (completedTasks * 100.0 / totalTasks) : 0;

        // ── Quiz scores ──
        List<QuizAttempt> attempts = quizAttemptRepository.findByUserIdOrderByStartedAtDesc(userId);
        double avgQuizScore = 0;
        double quizScoreChange = 0;
        List<Double> recentScores = new ArrayList<>();

        if (!attempts.isEmpty()) {
            double totalScore = 0;
            int scoreCount = 0;
            for (QuizAttempt attempt : attempts) {
                if (attempt.getScore() != null) {
                    totalScore += attempt.getScore().doubleValue();
                    scoreCount++;
                    if (recentScores.size() < 7) {
                        recentScores.add(attempt.getScore().doubleValue());
                    }
                }
            }
            avgQuizScore = scoreCount > 0 ? totalScore / scoreCount : 0;

            // Calculate change: compare latest 3 vs previous 3
            if (attempts.size() >= 4) {
                double recent = attempts.subList(0, Math.min(3, attempts.size())).stream()
                        .filter(a -> a.getScore() != null)
                        .mapToDouble(a -> a.getScore().doubleValue())
                        .average().orElse(0);
                double older = attempts.subList(Math.min(3, attempts.size()), Math.min(6, attempts.size())).stream()
                        .filter(a -> a.getScore() != null)
                        .mapToDouble(a -> a.getScore().doubleValue())
                        .average().orElse(0);
                quizScoreChange = recent - older;
            }
        }

        // Pad weekly scores to 7 entries
        while (recentScores.size() < 7) {
            recentScores.add(0.0);
        }
        Collections.reverse(recentScores); // oldest first

        // ── Subject progress list ──
        List<Map<String, Object>> subjects = new ArrayList<>();
        for (Map.Entry<String, int[]> entry : subjectProgress.entrySet()) {
            int total = entry.getValue()[0];
            int completed = entry.getValue()[1];
            double progress = total > 0 ? (double) completed / total : 0;
            String level = progress >= 0.8 ? "Advanced" : progress >= 0.4 ? "Proficient" : "Beginner";

            subjects.add(Map.of(
                    "name", entry.getKey(),
                    "progress", Math.round(progress * 100.0) / 100.0,
                    "level", level,
                    "totalTasks", total,
                    "completedTasks", completed
            ));
        }

        // ── Build response ──
        Map<String, Object> response = new LinkedHashMap<>();
        response.put("streakDays", streakDays);
        response.put("studyHours", Math.round(studyHours * 10.0) / 10.0);
        response.put("overallMastery", Math.round(overallMastery * 10.0) / 10.0);
        response.put("totalTasks", totalTasks);
        response.put("completedTasks", completedTasks);
        response.put("avgQuizScore", Math.round(avgQuizScore * 10.0) / 10.0);
        response.put("quizScoreChange", Math.round(quizScoreChange * 10.0) / 10.0);
        response.put("weeklyScores", recentScores);
        response.put("subjects", subjects);
        response.put("totalMaterials", materials.size());

        return ResponseEntity.ok(response);
    }

    /**
     * Calculate streak: count consecutive days (going backward from today)
     * that have at least one completed task.
     */
    private int calculateStreak(List<Material> materials) {
        Set<LocalDate> completedDates = new HashSet<>();

        for (Material material : materials) {
            Optional<MaterialStudyPlan> planOpt = materialStudyPlanRepository.findByMaterialId(material.getId());
            if (planOpt.isEmpty()) continue;

            MaterialStudyPlan plan = planOpt.get();
            if (plan.getTasks() == null) continue;

            for (MaterialStudyTask task : plan.getTasks()) {
                if (task.isCompleted() && task.getDayLabel() != null) {
                    try {
                        completedDates.add(LocalDate.parse(task.getDayLabel()));
                    } catch (Exception ignored) {}
                }
            }
        }

        if (completedDates.isEmpty()) return 0;

        int streak = 0;
        LocalDate date = LocalDate.now();
        while (completedDates.contains(date)) {
            streak++;
            date = date.minusDays(1);
        }

        return Math.max(streak, completedDates.isEmpty() ? 0 : 1);
    }
}