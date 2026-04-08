package com.resh.studymateaibackend.controller;

import com.resh.studymateaibackend.auth.CustomUserDetails;
import com.resh.studymateaibackend.dto.material.MaterialCardResponse;
import com.resh.studymateaibackend.dto.material.MaterialDetailsResponse;
import com.resh.studymateaibackend.dto.material.UploadMaterialResponse;
import com.resh.studymateaibackend.dto.study.*;
import com.resh.studymateaibackend.entity.User;
import com.resh.studymateaibackend.service.MaterialAiService;
import com.resh.studymateaibackend.service.MaterialService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.List;

@RestController
@RequestMapping("/api/materials")
@RequiredArgsConstructor
public class MaterialController {

    private final MaterialService materialService;
    private final MaterialAiService materialAiService;

    @PostMapping(value = "/upload", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<UploadMaterialResponse> uploadMaterial(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @RequestParam("file") MultipartFile file,
            @RequestParam(value = "title", required = false) String title,
            @RequestParam(value = "subjectId", required = false) Long subjectId
    ) throws IOException {
        User user = userDetails.getUser();
        return ResponseEntity.ok(materialService.uploadMaterial(user, file, title, subjectId));
    }

    @GetMapping
    public ResponseEntity<List<MaterialCardResponse>> getMaterials(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @RequestParam(defaultValue = "All") String category,
            @RequestParam(defaultValue = "") String q
    ) {
        User user = userDetails.getUser();
        return ResponseEntity.ok(materialService.getMaterials(user, category, q));
    }

    @GetMapping("/{id}")
    public ResponseEntity<MaterialDetailsResponse> getMaterialDetails(
            @PathVariable Long id,
            @AuthenticationPrincipal CustomUserDetails userDetails
    ) {
        User user = userDetails.getUser();
        return ResponseEntity.ok(materialService.getMaterialDetails(id, user));
    }
}