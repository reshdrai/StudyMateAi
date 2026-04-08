package com.resh.studymateaibackend.dto.ai;

import lombok.*;

import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AiAnalysisResponse {
    private String rawOutput;
    private List<AiKeyPointDto> keyPoints;
    private List<AiImportantTopicDto> importantTopics;
    private List<AiQuestionDto> questions;
}