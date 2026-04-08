package com.resh.studymateaibackend.service;

import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.json.gson.GsonFactory;
import com.resh.studymateaibackend.dto.AuthResponse;
import com.resh.studymateaibackend.entity.User;
import com.resh.studymateaibackend.repository.UserRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.security.GeneralSecurityException;
import java.util.Collections;

@Service
public class GoogleAuthService {

    @Value("${app.google.web-client-id}")
    private String googleWebClientId;

    private final JwtService jwtService;
    private final UserRepository userRepository;

    public GoogleAuthService(JwtService jwtService, UserRepository userRepository) {
        this.jwtService = jwtService;
        this.userRepository = userRepository;
    }

    public AuthResponse loginWithGoogle(String idTokenString) throws GeneralSecurityException, IOException {
        GoogleIdTokenVerifier verifier = new GoogleIdTokenVerifier.Builder(
                new NetHttpTransport(),
                GsonFactory.getDefaultInstance()
        )
                .setAudience(Collections.singletonList(googleWebClientId))
                .build();

        GoogleIdToken idToken = verifier.verify(idTokenString);

        if (idToken == null) {
            throw new RuntimeException("Invalid Google ID token");
        }

        GoogleIdToken.Payload payload = idToken.getPayload();

        String email = payload.getEmail();
        Boolean emailVerified = payload.getEmailVerified();
        String name = (String) payload.get("name");
        String picture = (String) payload.get("picture");
        String providerUserId = payload.getSubject();

        if (email == null || Boolean.FALSE.equals(emailVerified)) {
            throw new RuntimeException("Google email is not verified");
        }

        if (name == null || name.isBlank()) {
            name = email;
        }

        final String finalName = name;

        User user = userRepository.findByEmail(email).orElseGet(() -> {
            User newUser = new User();
            newUser.setEmail(email);
            newUser.setFullName(finalName);
            newUser.setProfileImageUrl(picture);
            newUser.setAuthProvider("google");
            newUser.setProviderUserId(providerUserId);
            newUser.setRole("STUDENT");
            newUser.setIsActive(true);
            return userRepository.save(newUser);
        });

        user.setFullName(name);
        user.setProfileImageUrl(picture);
        user.setAuthProvider("google");
        user.setProviderUserId(providerUserId);
        userRepository.save(user);

        String appJwt = jwtService.generateToken(
                user.getEmail(),
                user.getFullName(),
                user.getRole()
        );

        return new AuthResponse(
                appJwt,
                user.getEmail(),
                user.getFullName(),
                user.getRole()
        );
    }
}