package com.resh.studymateaibackend.service;

import org.apache.pdfbox.Loader;
import org.apache.pdfbox.io.RandomAccessReadBuffer;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.text.PDFTextStripper;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;

@Service
public class TextExtractionService {

    public String extract(MultipartFile file) throws IOException {
        String contentType = (file.getContentType() != null) ? file.getContentType().toLowerCase() : "";
        String originalName = (file.getOriginalFilename() != null) ? file.getOriginalFilename().toLowerCase() : "";

        System.out.println("=== TEXT EXTRACTION ===");
        System.out.println("Content-Type: " + contentType);
        System.out.println("Filename: " + originalName);
        System.out.println("Size: " + file.getSize() + " bytes");

        // Detect PDF by content type OR file extension
        boolean isPdf = contentType.contains("pdf")
                || contentType.equals("application/octet-stream") && originalName.endsWith(".pdf")
                || originalName.endsWith(".pdf");

        if (isPdf) {
            System.out.println("Detected as PDF, extracting text...");
            byte[] bytes = file.getBytes();

            // Extra safety: check if bytes actually start with PDF magic number
            if (bytes.length >= 4
                    && bytes[0] == '%'
                    && bytes[1] == 'P'
                    && bytes[2] == 'D'
                    && bytes[3] == 'F') {
                System.out.println("Confirmed PDF magic bytes: %PDF");
            }

            String text = extractFromPdf(bytes);

            if (text != null && text.startsWith("%PDF")) {
                throw new RuntimeException(
                        "PDF text extraction failed - got raw binary. File: " + originalName
                );
            }

            System.out.println("Extracted text length: " + (text != null ? text.length() : 0));
            return text;
        }

        // Detect images
        boolean isImage = contentType.contains("image")
                || originalName.endsWith(".jpg")
                || originalName.endsWith(".jpeg")
                || originalName.endsWith(".png");

        if (isImage) {
            System.out.println("Detected as image");
            return "[Image file - OCR needed]";
        }

        // Plain text fallback
        System.out.println("Treating as plain text");
        String text = new String(file.getBytes());
        return text.isBlank() ? "[Empty file]" : text;
    }

    private String extractFromPdf(byte[] pdfBytes) throws IOException {

        // PDFBox 3.0.5: use RandomAccessReadBuffer to wrap byte[]
        try {
            System.out.println("Trying RandomAccessReadBuffer approach...");
            RandomAccessReadBuffer readBuffer = new RandomAccessReadBuffer(pdfBytes);
            try (PDDocument document = Loader.loadPDF(readBuffer)) {
                String text = stripText(document);
                if (text != null && !text.isBlank()) {
                    System.out.println("SUCCESS: Extracted " + text.length() + " chars via RandomAccessReadBuffer");
                    return text;
                }
                System.out.println("RandomAccessReadBuffer: document loaded but no text extracted");
            }
        } catch (Exception e) {
            System.out.println("RandomAccessReadBuffer failed: " + e.getClass().getSimpleName() + ": " + e.getMessage());
        }

        // Fallback: write to temp file
        File tempFile = null;
        try {
            System.out.println("Trying temp file approach...");
            tempFile = File.createTempFile("studymate_pdf_", ".pdf");
            try (FileOutputStream fos = new FileOutputStream(tempFile)) {
                fos.write(pdfBytes);
                fos.flush();
            }

            try (PDDocument document = Loader.loadPDF(tempFile)) {
                String text = stripText(document);
                if (text != null && !text.isBlank()) {
                    System.out.println("SUCCESS: Extracted " + text.length() + " chars via temp file");
                    return text;
                }
                System.out.println("Temp file: document loaded but no text extracted");
            }
        } catch (Exception e) {
            System.out.println("Temp file approach failed: " + e.getClass().getSimpleName() + ": " + e.getMessage());
            e.printStackTrace();
        } finally {
            if (tempFile != null && tempFile.exists()) {
                tempFile.delete();
            }
        }

        System.out.println("WARNING: No text could be extracted from PDF");
        return "[PDF contained no extractable text - may be scanned/image-based]";
    }

    private String stripText(PDDocument document) throws IOException {
        PDFTextStripper stripper = new PDFTextStripper();
        String text = stripper.getText(document);

        if (text == null || text.isBlank()) {
            return null;
        }

        // Clean control characters
        text = text
                .replace("\u0000", "")
                .replaceAll("[\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F\\x7F]", "")
                .trim();

        // If still looks like binary
        if (text.startsWith("%PDF") || text.length() < 10) {
            return null;
        }

        return text;
    }
}