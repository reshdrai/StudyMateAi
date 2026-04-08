package com.resh.studymateaibackend.dto.material;

import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class StudyPlanTaskDto {
    private Long id;
    private String title;
    private String description;
    private boolean completed;
}