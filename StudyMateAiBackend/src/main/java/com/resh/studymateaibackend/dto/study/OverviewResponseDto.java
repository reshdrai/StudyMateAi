package com.resh.studymateaibackend.dto.study;

import com.resh.studymateaibackend.dto.study.FlashcardDto;
import lombok.*;

import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class OverviewResponseDto {
    private Long materialId;
    private List<FlashcardDto> flashcards;
    private List<TopicPriorityDto> importantTopics;
}