package com.resh.studymateaibackend.controller;

import com.resh.studymateaibackend.auth.CustomUserDetails;
import com.resh.studymateaibackend.entity.*;
import com.resh.studymateaibackend.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.*;

@RestController
@RequestMapping("/api/progress")
@RequiredArgsConstructor
public class ProgressController {

    private final MaterialRepository materialRepository;
    private final MaterialStudyPlanRepository materialStudyPlanRepository;
    private final QuizAttemptRepository quizAttemptRepository;
    private final TrackedMaterialRepository trackedMaterialRepository;

    @GetMapping("/analytics")
    @Transactional
    public ResponseEntity<Map<String, Object>> getAnalytics(
            @AuthenticationPrincipal CustomUserDetails userDetails) {

        Long userId = userDetails.getUser().getId();

        // Tracked materials — fallback to all if none selected
        List<Long> trackedIds = trackedMaterialRepository.findByUserId(userId)
                .stream().map(t -> t.getMaterial().getId()).toList();

        List<Material> materials = trackedIds.isEmpty()
                ? materialRepository.findByUserId(userId)
                : materialRepository.findAllById(trackedIds);

        int totalTasks = 0, completedTasks = 0;
        Map<String, int[]> subjectMap = new LinkedHashMap<>();

        for (Material material : materials) {
            Optional<MaterialStudyPlan> planOpt =
                    materialStudyPlanRepository.findByMaterialId(material.getId());
            if (planOpt.isEmpty() || planOpt.get().getTasks() == null) continue;

            String subject = "General";
            try {
                if (material.getSubject() != null && material.getSubject().getName() != null)
                    subject = material.getSubject().getName();
            } catch (Exception ignored) {}
            // fallback to material title for grouping
            if ("General".equals(subject)) subject = material.getTitle();

            for (MaterialStudyTask task : planOpt.get().getTasks()) {
                totalTasks++;
                subjectMap.putIfAbsent(subject, new int[]{0, 0});
                subjectMap.get(subject)[0]++;
                if (task.isCompleted()) { completedTasks++; subjectMap.get(subject)[1]++; }
            }
        }

        int streakDays = calculateStreak(materials);
        double studyHours = Math.round(completedTasks * 25.0 / 60.0 * 10) / 10.0;
        double overallMastery = totalTasks > 0
                ? Math.round(completedTasks * 100.0 / totalTasks * 10) / 10.0 : 0;

        // Quiz scores
        List<QuizAttempt> attempts =
                quizAttemptRepository.findByUserIdOrderByStartedAtDesc(userId);
        double avgScore = 0, scoreChange = 0;
        List<Double> weekly = new ArrayList<>(Collections.nCopies(7, 0.0));

        if (!attempts.isEmpty()) {
            double sum = 0; int cnt = 0;
            List<Double> recent = new ArrayList<>();
            for (QuizAttempt a : attempts) {
                if (a.getScore() == null) continue;
                sum += a.getScore().doubleValue(); cnt++;
                if (recent.size() < 7) recent.add(a.getScore().doubleValue());
            }
            if (cnt > 0) avgScore = Math.round(sum / cnt * 10) / 10.0;
            Collections.reverse(recent);
            for (int i = 0; i < Math.min(recent.size(), 7); i++) weekly.set(i, recent.get(i));
            if (attempts.size() >= 4) {
                double r = attempts.subList(0, 3).stream().filter(a -> a.getScore() != null)
                        .mapToDouble(a -> a.getScore().doubleValue()).average().orElse(0);
                double o = attempts.subList(3, Math.min(6, attempts.size())).stream()
                        .filter(a -> a.getScore() != null)
                        .mapToDouble(a -> a.getScore().doubleValue()).average().orElse(0);
                scoreChange = Math.round((r - o) * 10) / 10.0;
            }
        }

        // Subject list
        List<Map<String, Object>> subjects = new ArrayList<>();
        for (Map.Entry<String, int[]> e : subjectMap.entrySet()) {
            int tot = e.getValue()[0], comp = e.getValue()[1];
            double prog = tot > 0 ? Math.round(comp * 100.0 / tot * 10) / 1000.0 : 0;
            String level = prog >= 0.8 ? "Advanced" : prog >= 0.4 ? "Proficient" : "Beginner";
            subjects.add(Map.of("name", e.getKey(), "progress", prog,
                    "level", level, "totalTasks", tot, "completedTasks", comp));
        }

        return ResponseEntity.ok(Map.of(
                "streakDays", streakDays, "studyHours", studyHours,
                "overallMastery", overallMastery, "totalTasks", totalTasks,
                "completedTasks", completedTasks, "avgQuizScore", avgScore,
                "quizScoreChange", scoreChange, "weeklyScores", weekly,
                "subjects", subjects, "totalMaterials", materials.size()
        ));
    }

    private int calculateStreak(List<Material> materials) {
        Set<LocalDate> dates = new HashSet<>();
        for (Material m : materials) {
            materialStudyPlanRepository.findByMaterialId(m.getId()).ifPresent(plan -> {
                if (plan.getTasks() == null) return;
                for (MaterialStudyTask t : plan.getTasks()) {
                    if (!t.isCompleted() || t.getDayLabel() == null) continue;
                    try { dates.add(LocalDate.parse(t.getDayLabel())); } catch (Exception ignored) {}
                }
            });
        }
        if (dates.isEmpty()) return 0;
        int streak = 0;
        LocalDate d = LocalDate.now();
        if (!dates.contains(d) && dates.contains(d.minusDays(1))) d = d.minusDays(1);
        while (dates.contains(d)) { streak++; d = d.minusDays(1); }
        return streak;
    }
}