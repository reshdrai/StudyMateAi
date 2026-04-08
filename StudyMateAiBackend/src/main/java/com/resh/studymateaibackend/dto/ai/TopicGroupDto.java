package com.resh.studymateaibackend.dto.ai;

import lombok.*;

import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TopicGroupDto {
    private String topicLabel;
    private List<String> subtopics;
    private List<Integer> chunkIndexes;
}