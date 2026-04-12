package com.arise.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.Map;

@Slf4j
@Service
public class WeatherService {

    private final SystemLocationService locationService;
    private final RestTemplate restTemplate = new RestTemplate();

    public WeatherService(SystemLocationService locationService) {
        this.locationService = locationService;
    }

    public Map<String, Object> getCurrentWeather() {
        Map<String, Object> location = locationService.getCurrentLocation();
        double lat = (double) location.get("latitude");
        double lon = (double) location.get("longitude");
        String city = location.containsKey("city") ? (String) location.get("city") : "Local";

        try {
            String url = String.format(
                    "https://api.open-meteo.com/v1/forecast?latitude=%s&longitude=%s&current=temperature_2m,weather_code",
                    lat, lon);
            @SuppressWarnings("unchecked")
            Map<String, Object> response = restTemplate.getForObject(java.util.Objects.requireNonNull(url), Map.class);
            if (response != null && response.containsKey("current")) {
                @SuppressWarnings("unchecked")
                Map<String, Object> current = (Map<String, Object>) response.get("current");
                return Map.of(
                        "temperature", current.get("temperature_2m"),
                        "condition", getWeatherCondition((Integer) current.get("weather_code")),
                        "city", city);
            }
        } catch (Exception e) {
            log.error("Failed to fetch weather from Open-Meteo: {}", e.getMessage());
        }

        // Fallback placeholder
        return Map.of(
                "temperature", 25.0,
                "condition", "Unknown",
                "city", city);
    }

    private String getWeatherCondition(Integer code) {
        if (code == null)
            return "Unknown";
        if (code == 0)
            return "Clear";
        if (code <= 3)
            return "Cloudy";
        if (code <= 49)
            return "Foggy";
        if (code <= 59)
            return "Drizzle";
        if (code <= 69)
            return "Rain";
        if (code <= 79)
            return "Snow";
        if (code <= 84)
            return "Showers";
        if (code <= 94)
            return "Snow";
        return "Storm";
    }
}
