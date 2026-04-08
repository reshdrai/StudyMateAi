package com.resh.studymateaibackend.service;

import com.resh.studymateaibackend.dto.AuthResponse;
import com.resh.studymateaibackend.dto.auth.LoginRequest;
import com.resh.studymateaibackend.dto.auth.RegisterRequest;
import com.resh.studymateaibackend.entity.User;
import com.resh.studymateaibackend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;

    public AuthResponse register(RegisterRequest request) {
        if (userRepository.existsByEmail(request.getEmail())) {
            throw new RuntimeException("Email already registered");
        }

        User user = User.builder()
                .fullName(request.getFullName())
                .email(request.getEmail())
                .passwordHash(passwordEncoder.encode(request.getPassword()))
                .authProvider("local")
                .role("STUDENT")
                .isActive(true)
                .build();

        userRepository.save(user);

        String token = jwtService.generateToken(
                user.getEmail(),
                user.getFullName(),
                user.getRole()
        );

        return new AuthResponse(
                token,
                user.getEmail(),
                user.getFullName(),
                user.getRole()
        );
    }

    public AuthResponse login(LoginRequest request) {
        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new BadCredentialsException("Invalid email or password"));

        if (user.getPasswordHash() == null || user.getPasswordHash().isBlank()) {
            throw new BadCredentialsException("This account does not use password login");
        }

        if (!passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
            throw new BadCredentialsException("Invalid email or password");
        }

        String token = jwtService.generateToken(
                user.getEmail(),
                user.getFullName(),
                user.getRole()
        );

        return new AuthResponse(
                token,
                user.getEmail(),
                user.getFullName(),
                user.getRole()
        );
    }
}