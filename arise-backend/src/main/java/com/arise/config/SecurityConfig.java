package com.arise.config;

import com.arise.filter.ApiKeyAuthFilter;
import jakarta.servlet.DispatcherType;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;

import java.util.List;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    private final ApiKeyAuthFilter apiKeyAuthFilter;

    public SecurityConfig(ApiKeyAuthFilter apiKeyAuthFilter) {
        this.apiKeyAuthFilter = apiKeyAuthFilter;
    }

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
                .cors(cors -> cors.configurationSource(request -> {
                    var config = new CorsConfiguration();
                    // Restrict CORS to localhost origins only (Flutter desktop + dev servers)
                    config.setAllowedOriginPatterns(List.of("http://localhost:*", "http://127.0.0.1:*"));
                    config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS"));
                    config.setAllowedHeaders(List.of("X-API-KEY", "Authorization", "Content-Type", "Accept"));
                    config.setAllowCredentials(true);
                    return config;
                }))
                // CSRF disabled: stateless API-key auth over localhost only. Safe because CORS is restricted.
                .csrf(AbstractHttpConfigurer::disable)
                .headers(headers -> headers
                        .contentTypeOptions(contentTypeOptions -> {})
                        .frameOptions(frameOptions -> frameOptions.deny())
                )
                .authorizeHttpRequests(auth -> auth
                        // CRITICAL: Permit async dispatches — SSE streaming does async dispatch
                        // after the initial request is already authenticated. Without this,
                        // the security filter re-runs on the async thread where SecurityContext
                        // is lost, causing AccessDeniedException mid-stream.
                        .dispatcherTypeMatchers(DispatcherType.ASYNC).permitAll()
                        // Public endpoints - no auth required
                        .requestMatchers("/actuator/health").permitAll()
                        .requestMatchers("/api/health").permitAll()
                        .requestMatchers("/api/events/stream").permitAll()
                        .requestMatchers("/api/models/list").permitAll()
                        .requestMatchers("/api/models/ollama/status").permitAll()
                        .requestMatchers("/api/models/installing").permitAll()
                        .requestMatchers("/api/system/**").permitAll()
                        // AI endpoints - require API key auth (includes SSE streaming chat)
                        .requestMatchers("/api/ai/**").authenticated()
                        // Destructive/sensitive operations - require authentication
                        .requestMatchers("/api/models/pull").authenticated()
                        .requestMatchers(HttpMethod.DELETE, "/api/models/**").authenticated()
                        .requestMatchers("/api/models/cloud/**").authenticated()
                        .requestMatchers("/api/models/config").authenticated()
                        .requestMatchers("/api/models/select").authenticated()
                        // Default: require authentication for everything else
                        .anyRequest().authenticated()
                )
                .addFilterBefore(apiKeyAuthFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }
}
