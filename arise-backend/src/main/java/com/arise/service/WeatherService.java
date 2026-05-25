package com.arise.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.Map;

@Slf4j
@Service
public class WeatherService {

    private final SystemLocationService locationService;
    private final RestTemplate restTemplate = new RestTemplate();

    @Value("${arise.weather-api-key:}")
    private String weatherApiKey;

    public WeatherService(SystemLocationService locationService) {
        this.locationService = locationService;
    }

    public Map<String, Object> getCurrentWeather() {
        if (weatherApiKey == null || weatherApiKey.isBlank()) {
            log.warn("Weather API key not configured. Returning fallback data.");
            return getFallbackWeather("Local");
        }

        Map<String, Object> location = locationService.getCurrentLocation();
        double lat = (double) location.get("latitude");
        double lon = (double) location.get("longitude");

        try {
            String url = String.format(
                    "http://api.weatherapi.com/v1/current.json?key=%s&q=%s,%s&aqi=no",
                    weatherApiKey, lat, lon);
            @SuppressWarnings("unchecked")
            Map<String, Object> response = restTemplate.getForObject(java.util.Objects.requireNonNull(url), Map.class);
            if (response != null && response.containsKey("current")) {
                @SuppressWarnings("unchecked")
                Map<String, Object> current = (Map<String, Object>) response.get("current");
                @SuppressWarnings("unchecked")
                Map<String, Object> loc = (Map<String, Object>) response.get("location");
                @SuppressWarnings("unchecked")
                Map<String, Object> cond = (Map<String, Object>) current.get("condition");

                String fetchedCity = loc.containsKey("name") ? (String) loc.get("name") : "Unknown";

                return Map.of(
                        "temperature", current.get("temp_c"),
                        "condition", cond.get("text"),
                        "city", fetchedCity);
            }
        } catch (Exception e) {
            log.error("Failed to fetch weather from WeatherAPI: {}", e.getMessage());
        }

        // Fallback placeholder
        String city = location.containsKey("city") ? (String) location.get("city") : "Local";
        return getFallbackWeather(city);
    }

    private Map<String, Object> getFallbackWeather(String city) {
        return Map.of(
                "temperature", 25.0,
                "condition", "Unknown",
                "city", city);
    }
}
