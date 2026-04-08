package com.resh.studymateaibackend.dto.material;

import com.resh.studymateaibackend.dto.study.FlashcardDto;
import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;

@Data
@Builder



public class MaterialDetailsResponse {

    private Long id;
    private String title;
    private String fileType;
    private String fileUrl;
    private String extractedText;
    private String processingStatus;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    private String keyPoints;
    private String importantTopics;
    private String questions;
    private String studyPlan;
}