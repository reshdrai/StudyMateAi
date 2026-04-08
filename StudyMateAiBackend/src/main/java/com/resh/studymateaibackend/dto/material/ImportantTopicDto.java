package com.resh.studymateaibackend.dto.material;

import lombok.*;

import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ImportantTopicDto {
    private String title;
    private List<String> subtopics;
}