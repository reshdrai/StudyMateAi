package com.resh.studymateaibackend.service;

import com.resh.studymateaibackend.dto.AiTipResponse;
import com.resh.studymateaibackend.dto.HomeSummaryResponse;
import com.resh.studymateaibackend.dto.NextTaskResponse;
import com.resh.studymateaibackend.entity.*;
import com.resh.studymateaibackend.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.*;

@Service
@RequiredArgsConstructor
public class HomeService {

    private final AiTipRepository aiTipRepository;
    private final MaterialRepository materialRepository;
    private final MaterialStudyPlanRepository materialStudyPlanRepository;
    private final TrackedMaterialRepository trackedMaterialRepository;

    @Transactional
    public HomeSummaryResponse getHomeSummary(User user) {
        LocalDate today = LocalDate.now();
        DateTimeFormatter display = DateTimeFormatter.ofPattern("EEE, MMM d");

        // Use tracked materials; fallback to ALL if user hasn't tracked anything
        List<Long> trackedIds = trackedMaterialRepository.findByUserId(user.getId())
                .stream().map(t -> t.getMaterial().getId()).toList();

        List<Material> materials = trackedIds.isEmpty()
                ? materialRepository.findByUserId(user.getId())
                : materialRepository.findAllById(trackedIds);

        int totalTasks = 0, completedTasks = 0;
        List<NextTaskResponse> upcomingList = new ArrayList<>();
        NextTaskResponse nextTask = null;
        LocalDate nextDate = null;

        for (Material material : materials) {
            Optional<MaterialStudyPlan> planOpt =
                    materialStudyPlanRepository.findByMaterialId(material.getId());
            if (planOpt.isEmpty() || planOpt.get().getTasks() == null) continue;

            Long materialId = material.getId();

            for (MaterialStudyTask task : planOpt.get().getTasks()) {
                totalTasks++;
                if (task.isCompleted()) { completedTasks++; continue; }
                if (task.getDayLabel() == null) continue;

                LocalDate taskDate;
                try { taskDate = LocalDate.parse(task.getDayLabel()); }
                catch (Exception e) { continue; }

                if (taskDate.isBefore(today) || taskDate.isAfter(today.plusDays(6))) continue;

                NextTaskResponse dto = buildDto(task, taskDate, today, display, materialId);
                upcomingList.add(dto);

                if (nextDate == null || taskDate.isBefore(nextDate)) {
                    nextDate = taskDate; nextTask = dto;
                }
            }
        }

        // Sort: by date, QUIZ first on same day
        upcomingList.sort((a, b) -> {
            int cmp = a.getTimeLabel().compareTo(b.getTimeLabel());
            if (cmp != 0) return cmp;
            boolean aQ = "QUIZ".equalsIgnoreCase(a.getTaskType());
            boolean bQ = "QUIZ".equalsIgnoreCase(b.getTaskType());
            return aQ == bQ ? 0 : aQ ? -1 : 1;
        });

        int percent = totalTasks > 0 ? (completedTasks * 100) / totalTasks : 0;

        AiTip aiTip = aiTipRepository
                .findFirstByUserIdOrderByCreatedAtDesc(user.getId()).orElse(null);

        HomeSummaryResponse response = new HomeSummaryResponse();
        response.setUserName(user.getFullName() != null ? user.getFullName() : "Student");
        response.setCompletedTasks(completedTasks);
        response.setTotalTasks(totalTasks);
        response.setProgressText(percent + "% Done");

        if (nextTask != null) {
            response.setNextTask(nextTask);
        } else {
            NextTaskResponse empty = new NextTaskResponse();
            empty.setId(0L); empty.setSubjectTag("GENERAL");
            empty.setTitle(totalTasks == 0 ? "No study plan yet" : "All tasks done! 🎉");
            empty.setTimeLabel("");
            empty.setDescription(totalTasks == 0
                    ? "Select a note to track from the Library."
                    : "Great work! Check Analytics for your progress.");
            response.setNextTask(empty);
        }

        response.setUpcomingTasks(upcomingList.stream().limit(5).toList());

        AiTipResponse tip = new AiTipResponse();
        tip.setMessage(aiTip != null && aiTip.getMessage() != null
                ? aiTip.getMessage() : "Track a note from Library to see progress here!");
        response.setAiTip(tip);

        return response;
    }

    private NextTaskResponse buildDto(MaterialStudyTask task, LocalDate taskDate,
                                      LocalDate today, DateTimeFormatter fmt, Long materialId) {
        String type = task.getTaskType() != null ? task.getTaskType().toUpperCase() : "READ";
        String when = taskDate.equals(today) ? "Today"
                : taskDate.equals(today.plusDays(1)) ? "Tomorrow"
                : taskDate.format(fmt);
        String desc = switch (type) {
            case "QUIZ" -> when + " • " + task.getEstimatedMinutes() + " min quiz";
            case "REVIEW" -> when + " • Review flashcards · " + task.getEstimatedMinutes() + " min";
            case "DEEP_REVIEW" -> when + " • Deep focus · " + task.getEstimatedMinutes() + " min";
            default -> when + " • Read & study · " + task.getEstimatedMinutes() + " min";
        };
        NextTaskResponse dto = new NextTaskResponse();
        dto.setId(task.getId());
        dto.setTitle(task.getTitle() != null ? task.getTitle() : "Study Task");
        dto.setDescription(desc);
        dto.setSubjectTag(type);
        dto.setTimeLabel(when);
        dto.setTaskType(type);
        dto.setMaterialId(materialId);
        return dto;
    }
}