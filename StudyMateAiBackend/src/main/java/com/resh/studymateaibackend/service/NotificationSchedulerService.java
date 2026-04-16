package com.resh.studymateaibackend.service;

import com.resh.studymateaibackend.entity.Material;
import com.resh.studymateaibackend.entity.MaterialStudyPlan;
import com.resh.studymateaibackend.entity.MaterialStudyTask;
import com.resh.studymateaibackend.entity.NotificationLog;
import com.resh.studymateaibackend.repository.MaterialRepository;
import com.resh.studymateaibackend.repository.MaterialStudyPlanRepository;
import com.resh.studymateaibackend.repository.NotificationLogRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.*;

@Service
@RequiredArgsConstructor
@Slf4j
public class NotificationSchedulerService {

    private final MaterialRepository materialRepository;
    private final MaterialStudyPlanRepository materialStudyPlanRepository;
    private final NotificationLogRepository notificationLogRepository;
    private final FcmService fcmService;

    private static final LocalTime WINDOW_START = LocalTime.of(8, 0);
    private static final LocalTime WINDOW_END = LocalTime.of(21, 0);

    @Scheduled(fixedDelay = 300_000, initialDelay = 60_000)
    @Transactional
    public void checkAndNotify() {
        if (!fcmService.isEnabled()) {
            log.debug("[NotificationScheduler] FCM not initialized, skipping check");
            return;
        }

        LocalTime now = LocalTime.now();
        if (now.isBefore(WINDOW_START) || now.isAfter(WINDOW_END)) {
            log.debug("[NotificationScheduler] Outside notification window ({} - {})",
                    WINDOW_START, WINDOW_END);
            return;
        }

        LocalDate today = LocalDate.now();
        int notificationsSent = 0;

        List<Material> allMaterials = materialRepository.findAll();

        Map<Long, List<Material>> materialsByUser = new HashMap<>();
        for (Material m : allMaterials) {
            if (m.getUser() == null) continue;
            materialsByUser
                    .computeIfAbsent(m.getUser().getId(), k -> new ArrayList<>())
                    .add(m);
        }

        for (Map.Entry<Long, List<Material>> entry : materialsByUser.entrySet()) {
            Long userId = entry.getKey();
            List<Material> userMaterials = entry.getValue();

            try {
                notificationsSent += processUser(userId, userMaterials, today);
            } catch (Exception e) {
                log.error("[NotificationScheduler] Error processing user {}: {}", userId, e.getMessage(), e);
            }
        }

        if (notificationsSent > 0) {
            log.info("[NotificationScheduler] Sent {} notifications in this run", notificationsSent);
        }
    }

    private int processUser(Long userId, List<Material> userMaterials, LocalDate today) {
        int sent = 0;

        List<MaterialStudyTask> todayIncomplete = new ArrayList<>();
        List<MaterialStudyTask> overdueTasks = new ArrayList<>();

        for (Material material : userMaterials) {
            Optional<MaterialStudyPlan> planOpt =
                    materialStudyPlanRepository.findByMaterialId(material.getId());
            if (planOpt.isEmpty()) continue;

            MaterialStudyPlan plan = planOpt.get();
            if (plan.getTasks() == null) continue;

            for (MaterialStudyTask task : plan.getTasks()) {
                if (task.isCompleted()) continue;
                if (task.getDayLabel() == null) continue;

                LocalDate taskDate;
                try {
                    taskDate = LocalDate.parse(task.getDayLabel());
                } catch (Exception e) {
                    continue;
                }

                if (taskDate.equals(today)) {
                    todayIncomplete.add(task);
                } else if (taskDate.isBefore(today)) {
                    overdueTasks.add(task);
                }
            }
        }

        if (!todayIncomplete.isEmpty()) {
            String key = "DAILY_" + today;
            if (!alreadyNotified(todayIncomplete.get(0).getId(), key)) {
                String title = todayIncomplete.size() == 1
                        ? "You have a study task today"
                        : String.format("You have %d study tasks today", todayIncomplete.size());

                String body = todayIncomplete.size() == 1
                        ? todayIncomplete.get(0).getTitle()
                        : "Open StudyMate to see your schedule and get started.";

                Map<String, String> data = new HashMap<>();
                data.put("type", "DAILY_REMINDER");
                data.put("taskId", String.valueOf(todayIncomplete.get(0).getId()));

                if (todayIncomplete.get(0).getStudyPlan() != null
                        && todayIncomplete.get(0).getStudyPlan().getMaterial() != null) {
                    data.put("materialId", String.valueOf(
                            todayIncomplete.get(0).getStudyPlan().getMaterial().getId()));
                } else {
                    data.put("materialId", "0");
                }

                fcmService.sendToUser(userId, title, body, data);
                logNotification(todayIncomplete.get(0).getId(), userId, key);
                sent++;
            }
        }

        for (MaterialStudyTask task : overdueTasks) {
            String key = "OVERDUE";
            if (!alreadyNotified(task.getId(), key)) {
                String title = "Overdue study task";
                String body = String.format("'%s' was scheduled for %s. Reschedule or complete it now.",
                        task.getTitle(),
                        task.getDayLabel());

                Map<String, String> data = new HashMap<>();
                data.put("type", "OVERDUE");
                data.put("taskId", String.valueOf(task.getId()));

                if (task.getStudyPlan() != null && task.getStudyPlan().getMaterial() != null) {
                    data.put("materialId", String.valueOf(task.getStudyPlan().getMaterial().getId()));
                }

                fcmService.sendToUser(userId, title, body, data);
                logNotification(task.getId(), userId, key);
                sent++;

                if (sent >= 3) break;
            }
        }

        return sent;
    }

    private boolean alreadyNotified(Long taskId, String type) {
        return notificationLogRepository.existsByTaskIdAndNotificationType(taskId, type);
    }

    private void logNotification(Long taskId, Long userId, String type) {
        try {
            NotificationLog logEntry = new NotificationLog();
            logEntry.setTaskId(taskId);
            logEntry.setUserId(userId);
            logEntry.setNotificationType(type);
            logEntry.setSentAt(LocalDateTime.now());
            notificationLogRepository.save(logEntry);
        } catch (Exception e) {
            log.debug("[NotificationScheduler] logNotification failed: {}", e.getMessage());
        }
    }
}