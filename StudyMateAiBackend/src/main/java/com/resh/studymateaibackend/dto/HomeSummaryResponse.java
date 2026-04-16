package com.resh.studymateaibackend.dto;

import lombok.Data;

import java.util.ArrayList;
import java.util.List;

@Data
public class HomeSummaryResponse {
    private String userName;
    private int completedTasks;
    private int totalTasks;
    private String progressText;
    private NextTaskResponse nextTask;

    // New: list of upcoming study-plan tasks (today + next 2 days)
    private List<NextTaskResponse> upcomingTasks = new ArrayList<>();

    private AiTipResponse aiTip;
}