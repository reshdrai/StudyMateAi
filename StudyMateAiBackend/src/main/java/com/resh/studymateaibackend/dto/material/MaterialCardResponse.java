package com.resh.studymateaibackend.dto.material;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MaterialCardResponse {

    private Long id;
    private String title;
    private String subjectName;
    private String fileType;
    private String fileUrl;
    private LocalDateTime createdAt;
    private String processingStatus;
}