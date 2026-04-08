package com.resh.studymateaibackend.dto.material;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UploadMaterialResponse {

    private Long id;
    private String title;
    private String processingStatus;
}