package com.resh.studymateaibackend.dto;





import lombok.Data;

@Data
public class HomeSummaryResponse {
    private String userName;
    private int completedTasks;
    private int totalTasks;
    private String progressText;
    private NextTaskResponse nextTask;
    private AiTipResponse aiTip;
}
