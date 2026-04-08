package com.resh.studymateaibackend.dto.study;

import lombok.*;

import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class QuizResponseDto {
    private Long materialId;
    private List<QuizQuestionDto> questions;
}