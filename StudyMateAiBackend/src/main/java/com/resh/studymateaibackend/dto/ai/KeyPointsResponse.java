package com.resh.studymateaibackend.dto.ai;

import lombok.*;

import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class KeyPointsResponse {
    private List<KeyPointItemDto> keyPoints;
    private List<FlashcardItemDto> flashcards;
}