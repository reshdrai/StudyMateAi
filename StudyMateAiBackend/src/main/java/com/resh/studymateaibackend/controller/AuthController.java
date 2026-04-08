package com.resh.studymateaibackend.controller;

import com.resh.studymateaibackend.dto.AuthResponse;
import com.resh.studymateaibackend.dto.GoogleAuthRequest;
import com.resh.studymateaibackend.dto.auth.LoginRequest;
import com.resh.studymateaibackend.dto.auth.RegisterRequest;
import com.resh.studymateaibackend.service.AuthService;
import com.resh.studymateaibackend.service.GoogleAuthService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.io.IOException;
import java.security.GeneralSecurityException;

@RestController
@RequestMapping("/auth")
@CrossOrigin(origins = "*")
public class AuthController {

    private final GoogleAuthService googleAuthService;
    private final AuthService authService;

    public AuthController(GoogleAuthService googleAuthService, AuthService authService) {
        this.googleAuthService = googleAuthService;
        this.authService = authService;
    }

    @PostMapping("/google")
    public ResponseEntity<AuthResponse> googleLogin(@Valid @RequestBody GoogleAuthRequest request)
            throws GeneralSecurityException, IOException {

        AuthResponse response = googleAuthService.loginWithGoogle(request.getIdToken());
        return ResponseEntity.ok(response);
    }

    @PostMapping("/register")
    public ResponseEntity<AuthResponse> register(@Valid @RequestBody RegisterRequest request) {
        AuthResponse response = authService.register(request);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/login")
    public ResponseEntity<AuthResponse> login(@Valid @RequestBody LoginRequest request) {
        AuthResponse response = authService.login(request);
        return ResponseEntity.ok(response);
    }
}