package com.resh.studymateaibackend.dto.study;

import lombok.*;

import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TopicPriorityDto {
    private String topic;
    private String priority; // HIGH / MEDIUM / LOW
    private Double score;
    private List<String> subtopics;
}