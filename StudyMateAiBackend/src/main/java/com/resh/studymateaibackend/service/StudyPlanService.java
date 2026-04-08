//package com.resh.studymateaibackend.service;
//
//import com.resh.studymateaibackend.dto.material.MaterialDetailsResponse;
//import com.resh.studymateaibackend.entity.Material;
//import com.resh.studymateaibackend.entity.MaterialAnalysis;
//import com.resh.studymateaibackend.entity.MaterialStudyPlan;
//import com.resh.studymateaibackend.entity.MaterialStudyTask;
//import com.resh.studymateaibackend.entity.User;
//import com.resh.studymateaibackend.repository.MaterialAnalysisRepository;
//import com.resh.studymateaibackend.repository.MaterialStudyPlanRepository;
//import com.resh.studymateaibackend.repository.MaterialStudyTaskRepository;
//import lombok.RequiredArgsConstructor;
//import org.springframework.stereotype.Service;
//
//import java.time.LocalDateTime;
//import java.util.List;
//
//@Service
//@RequiredArgsConstructor
//public class StudyPlanService {
//
//    private final MaterialService materialService;
//    private final MaterialAnalysisRepository materialAnalysisRepository;
//    private final MaterialStudyPlanRepository materialStudyPlanRepository;
//    private final MaterialStudyTaskRepository materialStudyTaskRepository;
//    private final MaterialMapperService materialMapperService;
//
//    public MaterialDetailsResponse generateStudyPlan(Long materialId, User user) {
//        Material material = materialService.getOwnedMaterial(materialId, user);
//
//        MaterialStudyPlan plan = materialStudyPlanRepository.findByMaterialId(materialId)
//                .orElse(MaterialStudyPlan.builder()
//                        .material(material)
//                        .monthLabel("This Month")
//                        .generatedAt(LocalDateTime.now())
//                        .build());
//
//        plan.getTasks().clear();
//
//        plan.setTasks(List.of(
//                MaterialStudyTask.builder()
//                        .studyPlan(plan)
//                        .dayLabel("Day 1")
//                        .title("Review key points")
//                        .description("Read all flashcards and understand the main concepts.")
//                        .completed(false)
//                        .build(),
//                MaterialStudyTask.builder()
//                        .studyPlan(plan)
//                        .dayLabel("Day 2")
//                        .title("Revise important topics")
//                        .description("Focus on major topics and subtopics.")
//                        .completed(false)
//                        .build(),
//                MaterialStudyTask.builder()
//                        .studyPlan(plan)
//                        .dayLabel("Day 3")
//                        .title("Practice generated questions")
//                        .description("Answer the AI generated questions without looking at notes.")
//                        .completed(false)
//                        .build()
//        ));
//
//        materialStudyPlanRepository.save(plan);
//
//        MaterialAnalysis analysis = materialAnalysisRepository.findByMaterialId(materialId).orElse(null);
//
//        return materialMapperService.toDetailsResponse(material, analysis, plan);
//    }
//
//    public void markTaskComplete(Long taskId, boolean completed) {
//        MaterialStudyTask task = materialStudyTaskRepository.findById(taskId)
//                .orElseThrow(() -> new RuntimeException("Task not found"));
//
//        task.setCompleted(completed);
//        materialStudyTaskRepository.save(task);
//    }
//}