package com.resh.studymateaibackend.dto.ai;

import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ChunkItemDto {
    private Integer chunkIndex;
    private String chunkText;
    private String topicLabel;
    private String subtopicLabel;
    private String sectionType;
    private String topicPriority;
}