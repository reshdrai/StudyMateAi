package com.resh.studymateaibackend.dto.ai;

import lombok.*;

import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ImportanceResponse {
    private List<String> importantTopics;
    private List<String> importantSubtopics;
}