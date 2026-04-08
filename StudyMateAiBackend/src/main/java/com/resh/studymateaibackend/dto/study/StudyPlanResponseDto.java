package com.resh.studymateaibackend.dto.study;

import lombok.*;

import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class StudyPlanResponseDto {
    private Long materialId;
    private List<StudyPlanDayDto> days;
}