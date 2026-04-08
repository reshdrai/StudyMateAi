package com.resh.studymateaibackend.dto.study;

import lombok.*;

import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class StudyPlanDayDto {
    private String day;
    private List<String> tasks;
}