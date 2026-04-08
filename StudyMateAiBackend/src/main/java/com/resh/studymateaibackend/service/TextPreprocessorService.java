package com.resh.studymateaibackend.service;

import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;

@Service
public class TextPreprocessorService {

    public String normalizeForModel(String rawText) {
        if (rawText == null) return "";

        String text = rawText;

        // normalize line endings
        text = text.replace("\r\n", "\n").replace("\r", "\n");

        // remove page numbers standing alone
        text = text.replaceAll("(?m)^\\s*\\d+\\s*$", "");

        // remove repeated spaces/tabs
        text = text.replaceAll("[ \\t]+", " ");

        // remove lines that are too short and noisy
        text = text.replaceAll("(?m)^\\s*[-–_=]{2,}\\s*$", "");

        // merge broken lines inside paragraphs
        text = text.replaceAll("(?<![.!?:])\\n(?!\\n)", " ");

        // keep paragraph breaks
        text = text.replaceAll("\\n{2,}", "\n\n");

        // remove weird symbols except basic punctuation
        text = text.replaceAll("[^\\p{L}\\p{N}\\p{P}\\p{Z}]", " ");

        // clean repeated spaces again
        text = text.replaceAll(" +", " ");

        return text.trim();
    }

    public String trimForInference(String text, int maxChars) {
        if (text == null) return "";
        if (text.length() <= maxChars) return text;
        return text.substring(0, maxChars);
    }


    public List<String> splitIntoChunks(String text, int maxCharsPerChunk) {
        List<String> chunks = new ArrayList<>();

        if (text == null || text.isBlank()) {
            return chunks;
        }

        String[] paragraphs = text.split("\\n\\n+");
        StringBuilder current = new StringBuilder();

        for (String paragraph : paragraphs) {
            String cleaned = paragraph.trim();
            if (cleaned.isEmpty()) continue;

            if (current.length() + cleaned.length() + 2 <= maxCharsPerChunk) {
                if (current.length() > 0) current.append("\n\n");
                current.append(cleaned);
            } else {
                if (current.length() > 0) {
                    chunks.add(current.toString());
                }
                current = new StringBuilder(cleaned);
            }
        }

        if (current.length() > 0) {
            chunks.add(current.toString());
        }

        return chunks;
    }
}