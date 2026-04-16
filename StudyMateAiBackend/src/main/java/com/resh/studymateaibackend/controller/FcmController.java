package com.resh.studymateaibackend.controller;

import com.resh.studymateaibackend.auth.CustomUserDetails;
import com.resh.studymateaibackend.service.FcmService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/fcm")
@RequiredArgsConstructor
public class FcmController {

    private final FcmService fcmService;

    /**
     * Called by the Flutter app whenever it obtains or refreshes its FCM token.
     * Body: { "token": "<fcm_token>", "platform": "android"|"ios"|"web" }
     */
    @PostMapping("/register")
    public ResponseEntity<Map<String, Object>> register(
            @RequestBody Map<String, String> body,
            @AuthenticationPrincipal CustomUserDetails userDetails
    ) {
        String token = body.get("token");
        String platform = body.getOrDefault("platform", "android");

        if (token == null || token.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false,
                    "error", "token is required"
            ));
        }

        fcmService.registerToken(
                userDetails.getUser().getId(),
                token,
                platform,
                userDetails.getUser()
        );

        return ResponseEntity.ok(Map.of(
                "success", true,
                "enabled", fcmService.isEnabled()
        ));
    }

    /**
     * Send a test notification to the current user's devices.
     * Useful for verifying the integration end-to-end.
     */
    @PostMapping("/test")
    public ResponseEntity<Map<String, Object>> test(
            @AuthenticationPrincipal CustomUserDetails userDetails
    ) {
        fcmService.sendToUser(
                userDetails.getUser().getId(),
                "StudyMate AI",
                "Test notification - your FCM setup is working!",
                Map.of("type", "TEST")
        );

        return ResponseEntity.ok(Map.of(
                "success", true,
                "enabled", fcmService.isEnabled()
        ));
    }
}