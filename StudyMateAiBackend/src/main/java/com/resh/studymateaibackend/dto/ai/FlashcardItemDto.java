package com.resh.studymateaibackend.dto.ai;

import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FlashcardItemDto {
    private String front;
    private String back;
}