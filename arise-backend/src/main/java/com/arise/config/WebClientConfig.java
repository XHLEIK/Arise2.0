package com.arise.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.reactive.ReactorClientHttpConnector;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.netty.http.client.HttpClient;

import java.time.Duration;

@Configuration
public class WebClientConfig {

    @Bean
    public WebClient ollamaWebClient(@Value("${arise.ollama.base-url:http://localhost:11434/api}") String ollamaBaseUrl) {
        HttpClient httpClient = HttpClient.create()
                .responseTimeout(Duration.ofSeconds(120));
        return WebClient.builder()
                .baseUrl(ollamaBaseUrl)
                .clientConnector(new ReactorClientHttpConnector(httpClient))
                .codecs(configurer -> configurer.defaultCodecs().maxInMemorySize(16 * 1024 * 1024))
                .build();
    }
}
