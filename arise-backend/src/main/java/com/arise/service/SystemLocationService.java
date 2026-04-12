package com.arise.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.util.Map;

@Slf4j
@Service
public class SystemLocationService {

    private final RestTemplate restTemplate = new RestTemplate();

    public Map<String, Object> getCurrentLocation() {
        // Priority 1: Try Windows API internally using embedded PowerShell
        Map<String, Object> winLocation = attemptWindowsLocation();
        if (winLocation != null) {
            return winLocation;
        }

        // Priority 2: Fallback to IP Geolocation via ipapi
        return attemptIpFallbackLocation();
    }

    private Map<String, Object> attemptWindowsLocation() {
        try {
            // This relies on Windows 10/11 Location privacy settings being enabled.
            // Executing a small inline script; timeout heavily to prevent stalling.
            String script = "$watcher = New-Object System.Device.Location.GeoCoordinateWatcher; " +
                    "$watcher.Start(); " +
                    "Start-Sleep -Milliseconds 1500; " +
                    "if ($watcher.Status -eq 'Ready') { " +
                    "  Write-Output ($watcher.Position.Location.Latitude.ToString() + ',' + $watcher.Position.Location.Longitude.ToString()); "
                    +
                    "} " +
                    "$watcher.Stop();";

            ProcessBuilder pb = new ProcessBuilder("powershell.exe", "-NoProfile", "-Command", script);
            Process p = pb.start();
            p.waitFor(3, java.util.concurrent.TimeUnit.SECONDS);

            BufferedReader reader = new BufferedReader(new InputStreamReader(p.getInputStream()));
            String line = reader.readLine();

            if (line != null && line.contains(",")) {
                String[] parts = line.split(",");
                log.info("Successfully fetched physical Windows Location API data.");
                return Map.of(
                        "latitude", Double.parseDouble(parts[0]),
                        "longitude", Double.parseDouble(parts[1]));
            }
        } catch (Exception e) {
            log.warn("Windows Location API unreadable (check privacy settings). Proceeding to IP Fallback.");
        }
        return null;
    }

    private Map<String, Object> attemptIpFallbackLocation() {
        try {
            @SuppressWarnings("unchecked")
            Map<String, Object> response = restTemplate.getForObject("https://ipapi.co/json/", Map.class);
            if (response != null && response.containsKey("latitude")) {
                log.info("Successfully fetched location via IP Geolocation: {}", response.get("city"));
                return Map.of(
                        "latitude", response.get("latitude"),
                        "longitude", response.get("longitude"),
                        "city", response.get("city"));
            }
        } catch (Exception e) {
            log.error("Failed IP Location fallback: {}", e.getMessage());
        }

        // Hard fallback to New Delhi if offline/failed
        return Map.of(
                "latitude", 28.6139,
                "longitude", 77.2090,
                "city", "New Delhi");
    }
}
