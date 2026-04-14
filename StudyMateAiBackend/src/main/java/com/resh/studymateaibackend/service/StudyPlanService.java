package com.resh.studymateaibackend.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.resh.studymateaibackend.dto.study.TopicPriorityDto;
import com.resh.studymateaibackend.entity.*;
import com.resh.studymateaibackend.repository.*;
import com.resh.studymateaibackend.service.scheduler.StudySchedulerGA;
import com.resh.studymateaibackend.service.scheduler.StudySchedulerGA.*;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class StudyPlanService {

    private final MaterialRepository materialRepository;
    private final MaterialAnalysisRepository materialAnalysisRepository;
    private final MaterialStudyPlanRepository materialStudyPlanRepository;
    private final MaterialStudyTaskRepository materialStudyTaskRepository;
    private final ObjectMapper objectMapper;

    private final StudySchedulerGA scheduler = new StudySchedulerGA();

    private static final int DEFAULT_PLAN_DAYS = 7;
    private static final int DEFAULT_MINUTES_PER_DAY = 90;

    /**
     * Generate a study plan using the genetic algorithm.
     * If a plan already exists, missed tasks are collected and rescheduled.
     */
    @Transactional
    public Map<String, Object> generatePlan(Long materialId, User user) throws Exception {
        Material material = getOwnedMaterial(materialId, user);
        MaterialAnalysis analysis = materialAnalysisRepository
                .findByMaterialId(materialId)
                .orElse(null);

        // Collect topics from analysis
        List<TopicInput> topicInputs = buildTopicInputs(analysis);
        List<String> weakTopics = readWeakTopics(analysis);

        // Check for existing plan and collect missed tasks
        List<TaskInput> missedTasks = collectMissedTasks(materialId);

        // Run genetic algorithm
        StudySchedule schedule = scheduler.generate(
                topicInputs,
                weakTopics,
                DEFAULT_PLAN_DAYS,
                missedTasks,
                LocalDate.now(),
                DEFAULT_MINUTES_PER_DAY
        );

        // Persist the plan
        persistPlan(material, schedule);

        // Build response
        return scheduleToResponse(material.getId(), schedule);
    }

    /**
     * Mark a task as completed or not completed.
     */
    @Transactional
    public void markTaskCompleted(Long taskId, boolean completed, User user) {
        MaterialStudyTask task = materialStudyTaskRepository.findById(taskId)
                .orElseThrow(() -> new RuntimeException("Task not found"));

        // Verify ownership through plan -> material -> user
        MaterialStudyPlan plan = task.getStudyPlan();
        if (plan == null || plan.getMaterial() == null ||
                !plan.getMaterial().getUser().getId().equals(user.getId())) {
            throw new AccessDeniedException("Cannot modify this task");
        }

        task.setCompleted(completed);
        materialStudyTaskRepository.save(task);
    }

    /**
     * Reschedule: collects all incomplete past-due tasks and regenerates the plan.
     */
    @Transactional
    public Map<String, Object> reschedule(Long materialId, User user) throws Exception {
        // This effectively calls generatePlan which already handles missed tasks
        return generatePlan(materialId, user);
    }

    /**
     * Get existing plan without regenerating.
     */
    public Map<String, Object> getExistingPlan(Long materialId, User user) {
        Material material = getOwnedMaterial(materialId, user);

        MaterialStudyPlan plan = materialStudyPlanRepository.findByMaterialId(materialId)
                .orElse(null);

        if (plan == null || plan.getTasks().isEmpty()) {
            return Map.of(
                    "materialId", materialId,
                    "days", List.of(),
                    "hasPlan", false,
                    "message", "No study plan generated yet"
            );
        }

        return existingPlanToResponse(material.getId(), plan);
    }

    // ─────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────

    private List<TopicInput> buildTopicInputs(MaterialAnalysis analysis) {
        if (analysis == null || !StringUtils.hasText(analysis.getImportantTopics())) {
            return List.of(new TopicInput("General Review", "MEDIUM", List.of(), 2.0));
        }

        try {
            List<TopicPriorityDto> topics = objectMapper.readValue(
                    analysis.getImportantTopics(),
                    new TypeReference<List<TopicPriorityDto>>() {}
            );

            return topics.stream().map(t -> new TopicInput(
                    t.getTopic(),
                    t.getPriority(),
                    t.getSubtopics() != null ? t.getSubtopics() : List.of(),
                    t.getScore()
            )).collect(Collectors.toList());

        } catch (Exception e) {
            return List.of(new TopicInput("General Review", "MEDIUM", List.of(), 2.0));
        }
    }

    private List<String> readWeakTopics(MaterialAnalysis analysis) {
        if (analysis == null || !StringUtils.hasText(analysis.getWeakTopics())) {
            return List.of();
        }
        try {
            return objectMapper.readValue(analysis.getWeakTopics(), new TypeReference<List<String>>() {});
        } catch (Exception e) {
            return List.of();
        }
    }

    /**
     * Find tasks from existing plan that were not completed and whose day has passed.
     */
    private List<TaskInput> collectMissedTasks(Long materialId) {
        List<TaskInput> missed = new ArrayList<>();

        Optional<MaterialStudyPlan> existingPlan = materialStudyPlanRepository.findByMaterialId(materialId);
        if (existingPlan.isEmpty()) return missed;

        MaterialStudyPlan plan = existingPlan.get();
        LocalDate today = LocalDate.now();

        for (MaterialStudyTask task : plan.getTasks()) {
            if (task.isCompleted()) continue;

            // Parse date from dayLabel if available, or use plan generation date
            LocalDate taskDate = parseDayDate(task.getDayLabel(), plan.getGeneratedAt());

            if (taskDate != null && taskDate.isBefore(today)) {
                missed.add(new TaskInput(
                        task.getTitle(),
                        extractTopicFromTitle(task.getTitle()),
                        task.getDescription(),
                        30 // default estimate
                ));
            }
        }

        return missed;
    }

    private LocalDate parseDayDate(String dayLabel, LocalDateTime planGenerated) {
        if (dayLabel == null) return null;

        // Try parsing "2025-04-09" format
        try {
            return LocalDate.parse(dayLabel);
        } catch (Exception ignored) {}

        // Try parsing "Day N" format relative to plan generation
        try {
            if (dayLabel.toLowerCase().startsWith("day ")) {
                int dayNum = Integer.parseInt(dayLabel.substring(4).trim());
                if (planGenerated != null) {
                    return planGenerated.toLocalDate().plusDays(dayNum - 1);
                }
            }
        } catch (Exception ignored) {}

        return null;
    }

    private String extractTopicFromTitle(String title) {
        if (title == null) return "General";
        // Titles like "Read: Topic Name" or "Quiz: Topic Name"
        int colonIdx = title.indexOf(':');
        if (colonIdx > 0 && colonIdx < title.length() - 1) {
            return title.substring(colonIdx + 1).trim();
        }
        return title;
    }

    /**
     * Persist the GA schedule to database.
     */
    private void persistPlan(Material material, StudySchedule schedule) {
        // Delete existing plan
        materialStudyPlanRepository.findByMaterialId(material.getId())
                .ifPresent(existing -> {
                    existing.getTasks().clear();
                    materialStudyPlanRepository.delete(existing);
                });

        // Create new plan
        MaterialStudyPlan plan = MaterialStudyPlan.builder()
                .material(material)
                .monthLabel(LocalDate.now().getMonth().name())
                .generatedAt(LocalDateTime.now())
                .build();

        try {
            plan.setTasksJson(objectMapper.writeValueAsString(schedule));
        } catch (Exception e) {
            plan.setTasksJson("{}");
        }

        List<MaterialStudyTask> tasks = new ArrayList<>();
        for (StudySchedule.ScheduleDay day : schedule.days()) {
            for (StudySchedule.ScheduleTask task : day.tasks()) {
                tasks.add(MaterialStudyTask.builder()
                        .studyPlan(plan)
                        .dayLabel(day.date())
                        .title(task.title())
                        .description(task.description())
                        .completed(false)
                        .build());
            }
        }

        plan.setTasks(tasks);
        materialStudyPlanRepository.save(plan);

        material.setProcessingStatus("PLAN_READY");
        materialRepository.save(material);
    }

    private Map<String, Object> scheduleToResponse(Long materialId, StudySchedule schedule) {
        List<Map<String, Object>> days = new ArrayList<>();

        for (StudySchedule.ScheduleDay day : schedule.days()) {
            List<Map<String, Object>> tasks = new ArrayList<>();
            for (StudySchedule.ScheduleTask task : day.tasks()) {
                tasks.add(Map.of(
                        "id", task.id(),
                        "title", task.title(),
                        "description", task.description() != null ? task.description() : "",
                        "topicLabel", task.topicLabel(),
                        "priority", task.priority(),
                        "estimatedMinutes", task.estimatedMinutes(),
                        "taskType", task.taskType(),
                        "completed", task.completed()
                ));
            }

            days.add(Map.of(
                    "day", day.label(),
                    "date", day.date(),
                    "tasks", tasks,
                    "totalMinutes", day.totalMinutes()
            ));
        }

        return Map.of(
                "materialId", materialId,
                "days", days,
                "hasPlan", true,
                "fitnessScore", Math.round(schedule.fitnessScore() * 100.0) / 100.0
        );
    }

    private Map<String, Object> existingPlanToResponse(Long materialId, MaterialStudyPlan plan) {
        // Group tasks by day
        Map<String, List<MaterialStudyTask>> grouped = plan.getTasks().stream()
                .collect(Collectors.groupingBy(
                        MaterialStudyTask::getDayLabel,
                        LinkedHashMap::new,
                        Collectors.toList()
                ));

        List<Map<String, Object>> days = new ArrayList<>();
        for (Map.Entry<String, List<MaterialStudyTask>> entry : grouped.entrySet()) {
            List<Map<String, Object>> tasks = entry.getValue().stream()
                    .map(t -> {
                        Map<String, Object> m = new HashMap<>();
                        m.put("id", t.getId());
                        m.put("title", t.getTitle());
                        m.put("description", t.getDescription() != null ? t.getDescription() : "");
                        m.put("completed", t.isCompleted());
                        m.put("topicLabel", extractTopicFromTitle(t.getTitle()));
                        m.put("priority", "MEDIUM");
                        m.put("estimatedMinutes", 25);
                        m.put("taskType", "READ");
                        return m;
                    })
                    .collect(Collectors.toList());

            int totalMins = tasks.size() * 25;

            days.add(Map.of(
                    "day", entry.getKey(),
                    "date", entry.getKey(),
                    "tasks", tasks,
                    "totalMinutes", totalMins
            ));
        }

        return Map.of(
                "materialId", materialId,
                "days", days,
                "hasPlan", true,
                "fitnessScore", 0
        );
    }

    private Material getOwnedMaterial(Long materialId, User user) {
        Material material = materialRepository.findById(materialId)
                .orElseThrow(() -> new RuntimeException("Material not found"));

        if (material.getUser() == null || user == null ||
                !material.getUser().getId().equals(user.getId())) {
            throw new AccessDeniedException("User cannot access the material");
        }
        return material;
    }
}
