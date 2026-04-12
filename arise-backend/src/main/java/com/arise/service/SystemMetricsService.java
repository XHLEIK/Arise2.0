package com.arise.service;

import com.arise.model.SystemMetrics;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

@Slf4j
@Service
public class SystemMetricsService {

    private final WebClient webClient = WebClient.builder().baseUrl("http://localhost:8002").build();

    /**
     * Polls the live hardware metrics from the Python worker HTTP proxy endpoint.
     */
    public Mono<SystemMetrics> getLatestMetrics() {
        return webClient.get()
                .uri("/metrics")
                .retrieve()
                .bodyToMono(SystemMetrics.class)
                .onErrorResume(e -> {
                    log.warn("System metrics proxy failed (Python service restarting/offline): {}", e.getMessage());
                    SystemMetrics fallback = new SystemMetrics();
                    fallback.setCpuUsage(0.0);
                    fallback.setGpuUsage(0.0);
                    fallback.setRamUsage(0.0);
                    return Mono.just(fallback);
                });
    }
}
