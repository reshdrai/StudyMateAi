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

    private static final int DEFAULT_PLAN_DAYS = 7;
    private static final int DEFAULT_MINUTES_PER_DAY = 90;

    @Transactional
    public Map<String, Object> generatePlan(Long materialId, User user) throws Exception {
        Material material = getOwnedMaterial(materialId, user);

        MaterialAnalysis analysis = materialAnalysisRepository
                .findByMaterialId(materialId).orElse(null);

        List<TopicInput> topicInputs = buildTopicInputs(analysis);
        List<String> weakTopics = readWeakTopics(analysis);
        List<TaskInput> missedTasks = collectMissedTasks(materialId);

        StudySchedulerGA scheduler = new StudySchedulerGA();
        StudySchedule schedule = scheduler.generate(
                topicInputs, weakTopics,
                DEFAULT_PLAN_DAYS, missedTasks,
                LocalDate.now(), DEFAULT_MINUTES_PER_DAY
        );

        MaterialStudyPlan savedPlan = persistPlan(material, schedule);
        return buildResponse(material.getId(), savedPlan);
    }

    @Transactional
    public void markTaskCompleted(Long taskId, boolean completed, User user) {
        MaterialStudyTask task = materialStudyTaskRepository.findById(taskId)
                .orElseThrow(() -> new RuntimeException("Task not found"));

        MaterialStudyPlan plan = task.getStudyPlan();
        if (plan == null || plan.getMaterial() == null
                || !plan.getMaterial().getUser().getId().equals(user.getId())) {
            throw new AccessDeniedException("Cannot modify this task");
        }
        task.setCompleted(completed);
        materialStudyTaskRepository.save(task);
    }

    @Transactional
    public Map<String, Object> reschedule(Long materialId, User user) throws Exception {
        return generatePlan(materialId, user);
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getExistingPlan(Long materialId, User user) {
        getOwnedMaterial(materialId, user);

        MaterialStudyPlan plan = materialStudyPlanRepository.findByMaterialId(materialId)
                .orElse(null);

        if (plan == null || plan.getTasks() == null || plan.getTasks().isEmpty()) {
            return Map.of(
                    "materialId", materialId,
                    "days", List.of(),
                    "hasPlan", false,
                    "message", "No study plan generated yet"
            );
        }
        return buildResponse(materialId, plan);
    }

    // ─── Helpers ────────────────────────────────────────────────────────────

    private List<TopicInput> buildTopicInputs(MaterialAnalysis analysis) {
        if (analysis == null || !StringUtils.hasText(analysis.getImportantTopics())) {
            return List.of(new TopicInput("General Review", "MEDIUM", List.of(), 2.0));
        }
        try {
            List<TopicPriorityDto> topics = objectMapper.readValue(
                    analysis.getImportantTopics(),
                    new TypeReference<List<TopicPriorityDto>>() {});
            return topics.stream().map(t -> new TopicInput(
                    t.getTopic() != null ? t.getTopic() : "General",
                    t.getPriority() != null ? t.getPriority() : "MEDIUM",
                    t.getSubtopics() != null ? t.getSubtopics() : List.of(),
                    t.getScore() != null ? t.getScore() : 2.0
            )).collect(Collectors.toList());
        } catch (Exception e) {
            return List.of(new TopicInput("General Review", "MEDIUM", List.of(), 2.0));
        }
    }

    private List<String> readWeakTopics(MaterialAnalysis analysis) {
        if (analysis == null || !StringUtils.hasText(analysis.getWeakTopics())) return List.of();
        try {
            return objectMapper.readValue(analysis.getWeakTopics(), new TypeReference<List<String>>() {});
        } catch (Exception e) {
            return List.of();
        }
    }

    private List<TaskInput> collectMissedTasks(Long materialId) {
        List<TaskInput> missed = new ArrayList<>();
        Optional<MaterialStudyPlan> existing = materialStudyPlanRepository.findByMaterialId(materialId);
        if (existing.isEmpty()) return missed;

        MaterialStudyPlan plan = existing.get();
        LocalDate today = LocalDate.now();

        if (plan.getTasks() == null) return missed;

        for (MaterialStudyTask task : plan.getTasks()) {
            if (task.isCompleted() || task.getDayLabel() == null) continue;
            try {
                LocalDate taskDate = LocalDate.parse(task.getDayLabel());
                if (taskDate.isBefore(today)) {
                    missed.add(new TaskInput(
                            task.getTitle() != null ? task.getTitle() : "Missed Task",
                            extractTopicFromTitle(task.getTitle()),
                            task.getDescription() != null ? task.getDescription() : "",
                            30
                    ));
                }
            } catch (Exception ignored) {}
        }
        return missed;
    }

    /**
     * Delete old plan and persist new one.
     * Uses explicit delete + flush to avoid unique constraint violation on material_id.
     */
    @Transactional
    protected MaterialStudyPlan persistPlan(Material material, StudySchedule schedule) {
        // Delete existing plan first
        materialStudyPlanRepository.findByMaterialId(material.getId()).ifPresent(existing -> {
            // Clear tasks first to avoid FK constraint issues
            existing.getTasks().clear();
            materialStudyPlanRepository.saveAndFlush(existing);
            materialStudyPlanRepository.delete(existing);
            materialStudyPlanRepository.flush();
        });

        // Serialize schedule summary for storage (avoid serializing full GA objects)
        String tasksJsonSummary = "{}";
        try {
            Map<String, Object> summary = new HashMap<>();
            summary.put("fitnessScore", schedule.fitnessScore());
            summary.put("totalDays", schedule.days() != null ? schedule.days().size() : 0);
            tasksJsonSummary = objectMapper.writeValueAsString(summary);
        } catch (Exception ignored) {}

        // Build plan entity
        MaterialStudyPlan plan = MaterialStudyPlan.builder()
                .material(material)
                .monthLabel(LocalDate.now().getMonth().name())
                .generatedAt(LocalDateTime.now())
                .tasksJson(tasksJsonSummary)
                .tasks(new ArrayList<>())
                .build();

        // Build task entities
        if (schedule.days() != null) {
            for (StudySchedule.ScheduleDay day : schedule.days()) {
                if (day == null || day.tasks() == null) continue;
                for (StudySchedule.ScheduleTask task : day.tasks()) {
                    if (task == null) continue;
                    MaterialStudyTask t = MaterialStudyTask.builder()
                            .studyPlan(plan)
                            .dayLabel(day.date() != null ? day.date() : LocalDate.now().toString())
                            .title(task.title() != null ? task.title() : "Study Task")
                            .description(task.description() != null ? task.description() : "")
                            .completed(false)
                            .taskType(task.taskType() != null ? task.taskType() : "READ")
                            .estimatedMinutes(task.estimatedMinutes() > 0 ? task.estimatedMinutes() : 25)
                            .build();
                    plan.getTasks().add(t);
                }
            }
        }

        MaterialStudyPlan saved = materialStudyPlanRepository.save(plan);

        material.setProcessingStatus("PLAN_READY");
        materialRepository.save(material);

        return saved;
    }

    private Map<String, Object> buildResponse(Long materialId, MaterialStudyPlan plan) {
        if (plan.getTasks() == null) {
            return Map.of("materialId", materialId, "days", List.of(), "hasPlan", false);
        }

        // Group tasks by dayLabel
        Map<String, List<MaterialStudyTask>> grouped = plan.getTasks().stream()
                .collect(Collectors.groupingBy(
                        t -> t.getDayLabel() != null ? t.getDayLabel() : "",
                        LinkedHashMap::new,
                        Collectors.toList()
                ));

        List<Map<String, Object>> days = new ArrayList<>();
        int dayNumber = 1;
        for (Map.Entry<String, List<MaterialStudyTask>> entry : grouped.entrySet()) {
            List<Map<String, Object>> tasks = entry.getValue().stream()
                    .map(t -> {
                        Map<String, Object> m = new LinkedHashMap<>();
                        m.put("id", t.getId());
                        m.put("title", t.getTitle() != null ? t.getTitle() : "");
                        m.put("description", t.getDescription() != null ? t.getDescription() : "");
                        m.put("completed", t.isCompleted());
                        m.put("taskType", t.getTaskType() != null ? t.getTaskType() : "READ");
                        m.put("estimatedMinutes", t.getEstimatedMinutes() > 0 ? t.getEstimatedMinutes() : 25);
                        m.put("topicLabel", extractTopicFromTitle(t.getTitle()));
                        m.put("priority", "MEDIUM");
                        return m;
                    })
                    .collect(Collectors.toList());

            int totalMins = entry.getValue().stream()
                    .mapToInt(t -> t.getEstimatedMinutes() > 0 ? t.getEstimatedMinutes() : 25)
                    .sum();

            Map<String, Object> day = new LinkedHashMap<>();
            day.put("day", "Day " + dayNumber);
            day.put("date", entry.getKey());
            day.put("tasks", tasks);
            day.put("totalMinutes", totalMins);
            days.add(day);
            dayNumber++;
        }

        // Calculate fitness score from stored JSON
        double fitnessScore = 0;
        try {
            if (plan.getTasksJson() != null) {
                Map<String, Object> stored = objectMapper.readValue(
                        plan.getTasksJson(), new TypeReference<Map<String, Object>>() {});
                Object fs = stored.get("fitnessScore");
                if (fs instanceof Number) fitnessScore = ((Number) fs).doubleValue();
            }
        } catch (Exception ignored) {}

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("materialId", materialId);
        response.put("days", days);
        response.put("hasPlan", true);
        response.put("fitnessScore", Math.round(fitnessScore * 100.0) / 100.0);
        return response;
    }

    private String extractTopicFromTitle(String title) {
        if (title == null || title.isBlank()) return "General";
        int colonIdx = title.indexOf(':');
        if (colonIdx > 0 && colonIdx < title.length() - 1) {
            return title.substring(colonIdx + 1).trim();
        }
        return title.trim();
    }

    private Material getOwnedMaterial(Long materialId, User user) {
        Material material = materialRepository.findById(materialId)
                .orElseThrow(() -> new RuntimeException("Material not found"));
        if (material.getUser() == null || user == null
                || !material.getUser().getId().equals(user.getId())) {
            throw new AccessDeniedException("User cannot access the material");
        }
        return material;
    }
}