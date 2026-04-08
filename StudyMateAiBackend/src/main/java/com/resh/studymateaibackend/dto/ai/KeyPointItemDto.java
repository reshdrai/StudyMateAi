package com.resh.studymateaibackend.dto.ai;

import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class KeyPointItemDto {
    private String text;
    private String importance;
    private Double score;
    private String topicLabel;
    private String subtopicLabel;
}