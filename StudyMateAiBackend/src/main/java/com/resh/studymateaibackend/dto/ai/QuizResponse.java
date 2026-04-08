package com.resh.studymateaibackend.dto.ai;

import lombok.*;

import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class QuizResponse {
    private String topicLabel;
    private String subtopicLabel;
    private List<QuizItemDto> questions;
}