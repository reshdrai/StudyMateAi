package com.resh.studymateaibackend.dto.ai;

import lombok.*;

import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class QuizRequest {
    private String extractedText;
    private List<ChunkItemDto> chunks;
    private String topicLabel;
    private String subtopicLabel;
    private Integer maxQuestions;
}