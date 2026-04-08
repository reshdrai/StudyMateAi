package com.resh.studymateaibackend.dto;


import lombok.Data;

@Data
public class NextTaskResponse {
    private Long id;
    private String subjectTag;
    private String title;
    private String timeLabel;
    private String description;
}
