package com.arise.controller;

import com.arise.model.SystemMetrics;
import com.arise.service.SystemMetricsService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import reactor.core.publisher.Mono;

@RestController
@RequestMapping("/api/system")
@RequiredArgsConstructor
public class SystemMetricsController {

    private final SystemMetricsService metricsService;

    @GetMapping("/metrics")
    public Mono<ResponseEntity<SystemMetrics>> getMetrics() {
        return metricsService.getLatestMetrics()
                .map(ResponseEntity::ok);
    }
}
