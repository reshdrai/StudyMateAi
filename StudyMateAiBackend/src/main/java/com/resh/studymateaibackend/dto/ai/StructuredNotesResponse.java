package com.resh.studymateaibackend.dto.ai;

import lombok.*;

import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class StructuredNotesResponse {
    private String extractedText;
    private List<ChunkItemDto> chunks;
    private List<TopicGroupDto> topics;
}