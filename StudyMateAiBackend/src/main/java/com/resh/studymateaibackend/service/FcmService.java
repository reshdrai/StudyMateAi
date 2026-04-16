package com.resh.studymateaibackend.service;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.*;
import com.resh.studymateaibackend.entity.FcmToken;
import com.resh.studymateaibackend.repository.FcmTokenRepository;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.io.FileInputStream;
import java.io.InputStream;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Sends push notifications via Firebase Cloud Messaging.
 *
 * Configuration in application.properties:
 *   firebase.enabled=true
 *   firebase.service-account-path=/path/to/service-account.json
 *
 * If firebase.enabled is false or credentials are missing,
 * the service silently logs and does not attempt to send.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class FcmService {

    private final FcmTokenRepository fcmTokenRepository;

    @Value("${firebase.enabled:false}")
    private boolean firebaseEnabled;

    @Value("${firebase.service-account-path:}")
    private String serviceAccountPath;

    private boolean initialized = false;

    @PostConstruct
    public void init() {
        if (!firebaseEnabled) {
            log.info("[FCM] Firebase disabled. Push notifications will not be sent.");
            return;
        }

        if (serviceAccountPath == null || serviceAccountPath.isBlank()) {
            log.warn("[FCM] firebase.service-account-path not set. Skipping initialization.");
            return;
        }

        try {
            InputStream serviceAccount = new FileInputStream(serviceAccountPath);
            FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                    .build();

            if (FirebaseApp.getApps().isEmpty()) {
                FirebaseApp.initializeApp(options);
            }
            initialized = true;
            log.info("[FCM] Firebase initialized successfully");
        } catch (Exception e) {
            log.error("[FCM] Failed to initialize Firebase: {}", e.getMessage());
        }
    }

    /**
     * Register or update a device token for a user.
     * Call this from /api/fcm/register endpoint when the Flutter app gets an FCM token.
     */
    public void registerToken(Long userId, String token, String platform,
                              com.resh.studymateaibackend.entity.User user) {
        if (token == null || token.isBlank()) return;

        fcmTokenRepository.findByToken(token).ifPresentOrElse(
                existing -> {
                    // Token exists - update user in case it changed device
                    existing.setUser(user);
                    existing.setPlatform(platform);
                    fcmTokenRepository.save(existing);
                },
                () -> {
                    FcmToken newToken = FcmToken.builder()
                            .user(user)
                            .token(token)
                            .platform(platform != null ? platform : "android")
                            .build();
                    fcmTokenRepository.save(newToken);
                }
        );
    }

    /**
     * Send a notification to all of a user's registered devices.
     */
    public void sendToUser(Long userId, String title, String body, Map<String, String> data) {
        if (!initialized) {
            log.debug("[FCM] Not initialized, skipping send to user {}", userId);
            return;
        }

        List<FcmToken> tokens = fcmTokenRepository.findByUserId(userId);
        if (tokens.isEmpty()) {
            log.debug("[FCM] No registered tokens for user {}", userId);
            return;
        }

        for (FcmToken tokenEntity : tokens) {
            try {
                sendToToken(tokenEntity.getToken(), title, body, data);
            } catch (FirebaseMessagingException e) {
                log.warn("[FCM] Failed to send to token {}: {}", tokenEntity.getId(), e.getMessage());

                // Clean up invalid tokens
                if (e.getMessagingErrorCode() == MessagingErrorCode.UNREGISTERED ||
                        e.getMessagingErrorCode() == MessagingErrorCode.INVALID_ARGUMENT) {
                    fcmTokenRepository.delete(tokenEntity);
                }
            }
        }
    }

    /**
     * Send to a specific FCM token.
     */
    public String sendToToken(String token, String title, String body, Map<String, String> data)
            throws FirebaseMessagingException {

        Notification notification = Notification.builder()
                .setTitle(title)
                .setBody(body)
                .build();

        Message.Builder messageBuilder = Message.builder()
                .setToken(token)
                .setNotification(notification)
                // Android-specific config (high priority for wake-up)
                .setAndroidConfig(AndroidConfig.builder()
                        .setPriority(AndroidConfig.Priority.HIGH)
                        .setNotification(AndroidNotification.builder()
                                .setChannelId("studymate_reminders")
                                .setSound("default")
                                .build())
                        .build())
                // iOS-specific config
                .setApnsConfig(ApnsConfig.builder()
                        .setAps(Aps.builder()
                                .setSound("default")
                                .setBadge(1)
                                .build())
                        .build());

        if (data != null) {
            Map<String, String> dataCopy = new HashMap<>(data);
            messageBuilder.putAllData(dataCopy);
        }

        return FirebaseMessaging.getInstance().send(messageBuilder.build());
    }

    public boolean isEnabled() {
        return initialized;
    }
}