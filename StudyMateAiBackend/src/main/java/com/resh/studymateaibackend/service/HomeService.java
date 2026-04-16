package com.resh.studymateaibackend.service;

import com.resh.studymateaibackend.dto.AiTipResponse;
import com.resh.studymateaibackend.dto.HomeSummaryResponse;
import com.resh.studymateaibackend.dto.NextTaskResponse;
import com.resh.studymateaibackend.entity.*;
import com.resh.studymateaibackend.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.*;

@Service
@RequiredArgsConstructor
public class HomeService {

    private final StudyTaskRepository studyTaskRepository;
    private final AiTipRepository aiTipRepository;
    private final MaterialRepository materialRepository;
    private final MaterialStudyPlanRepository materialStudyPlanRepository;

    public HomeSummaryResponse getHomeSummary(User user) {
        LocalDate today = LocalDate.now();

        // ─── 1. Count progress from MaterialStudyTask (GA scheduler tasks) ───
        int planTotalTasks = 0;
        int planCompletedTasks = 0;
        MaterialStudyTask nextPlanTask = null;
        LocalDate nextPlanTaskDate = null;

        // Also: collect today's-plus-tomorrow tasks as upcoming
        List<MaterialStudyTask> upcomingTasks = new ArrayList<>();

        List<Material> userMaterials = materialRepository.findByUserId(user.getId());
        for (Material material : userMaterials) {
            Optional<MaterialStudyPlan> planOpt =
                    materialStudyPlanRepository.findByMaterialId(material.getId());
            if (planOpt.isEmpty()) continue;

            MaterialStudyPlan plan = planOpt.get();
            if (plan.getTasks() == null) continue;

            for (MaterialStudyTask task : plan.getTasks()) {
                planTotalTasks++;
                if (task.isCompleted()) {
                    planCompletedTasks++;
                    continue;
                }

                // Not completed — process for next-task & upcoming
                if (task.getDayLabel() == null) continue;

                LocalDate taskDate;
                try {
                    taskDate = LocalDate.parse(task.getDayLabel());
                } catch (Exception e) {
                    continue;
                }

                // Add to upcoming list if today or within next 2 days
                if (!taskDate.isBefore(today) &&
                        !taskDate.isAfter(today.plusDays(2))) {
                    upcomingTasks.add(task);
                }

                // Find the nearest next task
                if (!taskDate.isBefore(today)) {
                    if (nextPlanTask == null ||
                            (nextPlanTaskDate != null && taskDate.isBefore(nextPlanTaskDate))) {
                        nextPlanTask = task;
                        nextPlanTaskDate = taskDate;
                    }
                }
            }
        }

        // Sort upcoming tasks by date
        upcomingTasks.sort((a, b) -> {
            try {
                LocalDate da = LocalDate.parse(a.getDayLabel());
                LocalDate db = LocalDate.parse(b.getDayLabel());
                return da.compareTo(db);
            } catch (Exception e) {
                return 0;
            }
        });

        // ─── 2. Legacy StudyTask table counts ───
        int legacyTotal = studyTaskRepository.countByUserIdAndDueDate(user.getId(), today);
        int legacyCompleted = studyTaskRepository.countByUserIdAndDueDateAndStatus(
                user.getId(), today, "completed");

        int totalTasks = planTotalTasks + legacyTotal;
        int completedTasks = planCompletedTasks + legacyCompleted;
        int percent = totalTasks == 0 ? 0 : (completedTasks * 100) / totalTasks;

        // ─── 3. Legacy fallback next task ───
        StudyTask legacyNextTask = studyTaskRepository
                .findFirstByUserIdAndStatusInOrderByStartTimeAsc(
                        user.getId(),
                        List.of("pending", "in_progress"))
                .orElse(null);

        // ─── 4. AI Tip ───
        AiTip aiTip = aiTipRepository
                .findFirstByUserIdOrderByCreatedAtDesc(user.getId())
                .orElse(null);

        // ─── 5. Build response ───
        HomeSummaryResponse response = new HomeSummaryResponse();
        response.setUserName(
                user.getFullName() != null && !user.getFullName().isBlank()
                        ? user.getFullName()
                        : "Student");
        response.setCompletedTasks(completedTasks);
        response.setTotalTasks(totalTasks);
        response.setProgressText(percent + "% Done");

        // Upcoming tasks list (3-5 items max)
        List<NextTaskResponse> upcomingList = new ArrayList<>();
        int limit = Math.min(upcomingTasks.size(), 5);
        for (int i = 0; i < limit; i++) {
            MaterialStudyTask t = upcomingTasks.get(i);
            upcomingList.add(buildTaskResponse(t));
        }
        response.setUpcomingTasks(upcomingList);

        // Next task
        NextTaskResponse nextTaskResponse;
        if (nextPlanTask != null) {
            nextTaskResponse = buildTaskResponse(nextPlanTask);
        } else if (legacyNextTask != null) {
            nextTaskResponse = buildLegacyTaskResponse(legacyNextTask);
        } else {
            nextTaskResponse = new NextTaskResponse();
            nextTaskResponse.setId(0L);
            nextTaskResponse.setSubjectTag("GENERAL");
            nextTaskResponse.setTitle("No upcoming task");
            nextTaskResponse.setTimeLabel("");
            nextTaskResponse.setDescription("Start by adding a goal or uploading notes.");
        }
        response.setNextTask(nextTaskResponse);

        // AI Tip
        AiTipResponse tipResponse = new AiTipResponse();
        tipResponse.setMessage(
                aiTip != null && aiTip.getMessage() != null && !aiTip.getMessage().isBlank()
                        ? aiTip.getMessage()
                        : "Upload notes or create goals to get personalized study tips.");
        response.setAiTip(tipResponse);

        return response;
    }

    private NextTaskResponse buildTaskResponse(MaterialStudyTask task) {
        NextTaskResponse r = new NextTaskResponse();
        r.setId(task.getId());
        r.setTitle(task.getTitle() != null ? task.getTitle() : "Study Task");
        r.setDescription(task.getDescription() != null ? task.getDescription() : "");
        r.setSubjectTag("STUDY");

        String timeLabel = task.getDayLabel() != null ? task.getDayLabel() : "";
        r.setTimeLabel(timeLabel);

        if (task.getStudyPlan() != null && task.getStudyPlan().getMaterial() != null) {
            r.setMaterialId(task.getStudyPlan().getMaterial().getId());
        }

        r.setTaskType("STUDY");
        return r;
    }

    private NextTaskResponse buildLegacyTaskResponse(StudyTask legacy) {
        NextTaskResponse r = new NextTaskResponse();
        r.setId(legacy.getId());
        r.setTitle(legacy.getTitle() != null ? legacy.getTitle() : "No upcoming task");
        r.setDescription(legacy.getDescription() != null ? legacy.getDescription() : "");

        if (legacy.getSubject() != null) {
            if (legacy.getSubject().getCode() != null &&
                    !legacy.getSubject().getCode().isBlank()) {
                r.setSubjectTag(legacy.getSubject().getCode().toUpperCase());
            } else {
                r.setSubjectTag(legacy.getSubject().getName().toUpperCase());
            }
        } else {
            r.setSubjectTag("GENERAL");
        }

        if (legacy.getStartTime() != null && legacy.getEndTime() != null) {
            String start = legacy.getStartTime().format(DateTimeFormatter.ofPattern("HH:mm"));
            String end = legacy.getEndTime().format(DateTimeFormatter.ofPattern("HH:mm"));
            int mins = legacy.getEstimatedMinutes() != null ? legacy.getEstimatedMinutes() : 0;
            r.setTimeLabel(start + " - " + end + " (" + mins + " min)");
        } else {
            r.setTimeLabel("");
        }
        return r;
    }
}