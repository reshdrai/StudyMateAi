package com.resh.studymateaibackend.service;



import com.resh.studymateaibackend.dto.AiTipResponse;
import com.resh.studymateaibackend.dto.HomeSummaryResponse;
import com.resh.studymateaibackend.dto.NextTaskResponse;
import com.resh.studymateaibackend.entity.AiTip;
import com.resh.studymateaibackend.entity.StudyTask;
import com.resh.studymateaibackend.entity.User;
import com.resh.studymateaibackend.repository.AiTipRepository;
import com.resh.studymateaibackend.repository.StudyTaskRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.List;

@Service
@RequiredArgsConstructor
public class HomeService {

    private final StudyTaskRepository studyTaskRepository;
    private final AiTipRepository aiTipRepository;

    public HomeSummaryResponse getHomeSummary(User user) {
        LocalDate today = LocalDate.now();

        int totalTasks = studyTaskRepository.countByUserIdAndDueDate(user.getId(), today);
        int completedTasks = studyTaskRepository.countByUserIdAndDueDateAndStatus(
                user.getId(), today, "completed"
        );

        int percent = totalTasks == 0 ? 0 : (completedTasks * 100) / totalTasks;

        StudyTask nextTask = studyTaskRepository
                .findFirstByUserIdAndStatusInOrderByStartTimeAsc(
                        user.getId(),
                        List.of("pending", "in_progress")
                )
                .orElse(null);

        AiTip aiTip = aiTipRepository
                .findFirstByUserIdOrderByCreatedAtDesc(user.getId())
                .orElse(null);

        HomeSummaryResponse response = new HomeSummaryResponse();
        response.setUserName(
                user.getFullName() != null && !user.getFullName().isBlank()
                        ? user.getFullName()
                        : "Student"
        );
        response.setCompletedTasks(completedTasks);
        response.setTotalTasks(totalTasks);
        response.setProgressText(percent + "% Done");

        NextTaskResponse nextTaskResponse = new NextTaskResponse();
        if (nextTask != null) {
            nextTaskResponse.setId(nextTask.getId());
            nextTaskResponse.setTitle(nextTask.getTitle() != null ? nextTask.getTitle() : "No upcoming task");
            nextTaskResponse.setDescription(
                    nextTask.getDescription() != null ? nextTask.getDescription() : ""
            );

            if (nextTask.getSubject() != null) {
                if (nextTask.getSubject().getCode() != null && !nextTask.getSubject().getCode().isBlank()) {
                    nextTaskResponse.setSubjectTag(nextTask.getSubject().getCode().toUpperCase());
                } else {
                    nextTaskResponse.setSubjectTag(nextTask.getSubject().getName().toUpperCase());
                }
            } else {
                nextTaskResponse.setSubjectTag("GENERAL");
            }

            if (nextTask.getStartTime() != null && nextTask.getEndTime() != null) {
                String start = nextTask.getStartTime().format(DateTimeFormatter.ofPattern("HH:mm"));
                String end = nextTask.getEndTime().format(DateTimeFormatter.ofPattern("HH:mm"));
                int mins = nextTask.getEstimatedMinutes() != null ? nextTask.getEstimatedMinutes() : 0;
                nextTaskResponse.setTimeLabel(start + " - " + end + " (" + mins + " min)");
            } else {
                nextTaskResponse.setTimeLabel("");
            }
        } else {
            nextTaskResponse.setId(0L);
            nextTaskResponse.setSubjectTag("GENERAL");
            nextTaskResponse.setTitle("No upcoming task");
            nextTaskResponse.setTimeLabel("");
            nextTaskResponse.setDescription("Start by adding a goal or uploading notes.");
        }
        response.setNextTask(nextTaskResponse);

        AiTipResponse tipResponse = new AiTipResponse();
        tipResponse.setMessage(
                aiTip != null && aiTip.getMessage() != null && !aiTip.getMessage().isBlank()
                        ? aiTip.getMessage()
                        : "Upload notes or create goals to get personalized study tips."
        );
        response.setAiTip(tipResponse);

        return response;
    }

}