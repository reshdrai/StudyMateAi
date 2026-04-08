package com.resh.studymateaibackend.service;

import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;

@Service
public class TextExtractionService {

    public String extract(MultipartFile file) throws IOException {

        String contentType = file.getContentType();

        if (contentType != null && contentType.contains("pdf")) {
            // TEMP FIX (so AI works)
            return new String(file.getBytes());
        }

        if (contentType != null && contentType.contains("image")) {
            return "Sample extracted text from image";
        }

        // fallback
        String text = new String(file.getBytes());

        return text.isBlank() ? "Sample fallback text" : text;
    }
}