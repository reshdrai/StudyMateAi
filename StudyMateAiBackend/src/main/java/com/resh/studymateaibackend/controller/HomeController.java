package com.resh.studymateaibackend.controller;

import com.resh.studymateaibackend.dto.HomeSummaryResponse;
import com.resh.studymateaibackend.entity.User;
import com.resh.studymateaibackend.auth.CustomUserDetails;
import com.resh.studymateaibackend.service.HomeService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/home")
@RequiredArgsConstructor
public class HomeController {

    private final HomeService homeService;

    @GetMapping("/summary")
    public ResponseEntity<HomeSummaryResponse> getHomeSummary(
            @AuthenticationPrincipal CustomUserDetails userDetails
    ) {
        User currentUser = userDetails.getUser();
        HomeSummaryResponse response = homeService.getHomeSummary(currentUser);
        return ResponseEntity.ok(response);
    }
}