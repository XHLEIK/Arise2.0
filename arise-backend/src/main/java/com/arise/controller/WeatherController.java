package com.arise.controller;

import com.arise.service.SystemLocationService;
import com.arise.service.WeatherService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/system")
@RequiredArgsConstructor
public class WeatherController {

    private final SystemLocationService locationService;
    private final WeatherService weatherService;

    @GetMapping("/location")
    public ResponseEntity<Map<String, Object>> getLocation() {
        return ResponseEntity.ok(locationService.getCurrentLocation());
    }

    @GetMapping("/weather")
    public ResponseEntity<Map<String, Object>> getWeather() {
        return ResponseEntity.ok(weatherService.getCurrentWeather());
    }
}
