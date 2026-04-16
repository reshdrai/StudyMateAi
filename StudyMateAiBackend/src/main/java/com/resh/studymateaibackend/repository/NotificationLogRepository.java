package com.resh.studymateaibackend.repository;

import com.resh.studymateaibackend.entity.NotificationLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface NotificationLogRepository extends JpaRepository<NotificationLog, Long> {

    Optional<NotificationLog> findByTaskIdAndNotificationType(Long taskId, String notificationType);

    boolean existsByTaskIdAndNotificationType(Long taskId, String notificationType);
}