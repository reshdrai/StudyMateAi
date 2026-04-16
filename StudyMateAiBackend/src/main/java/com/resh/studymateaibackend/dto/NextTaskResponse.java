package com.resh.studymateaibackend.dto;

import lombok.Data;

@Data
public class NextTaskResponse {
    private Long id;
    private String subjectTag;
    private String title;
    private String timeLabel;
    private String description;

    // Added for study-plan task navigation from home page
    private Long materialId;   // so frontend can open the right study plan / flashcard page
    private String taskType;   // "READ", "QUIZ", "REVIEW", "DEEP_REVIEW"
}