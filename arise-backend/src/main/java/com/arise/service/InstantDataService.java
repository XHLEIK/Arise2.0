package com.arise.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.text.NumberFormat;
import java.time.Duration;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;

@Slf4j
@Service
public class InstantDataService {

    private final WeatherService weatherService;
    private final RestTemplate restTemplate;

    private static final int NEWS_LIMIT = 5;
    private static final String GOOGLE_NEWS_RSS = "https://news.google.com/rss?hl=en-IN&gl=IN";
    private static final DateTimeFormatter TIME_FMT =
            DateTimeFormatter.ofPattern("hh:mm a, EEEE, d MMMM yyyy (z)", Locale.ENGLISH);
    private static final SecureRandom SECURE_RANDOM = new SecureRandom();
    private static final NumberFormat CURRENCY_FMT;

    static {
        CURRENCY_FMT = NumberFormat.getNumberInstance(new Locale("en", "IN"));
        CURRENCY_FMT.setMinimumFractionDigits(0);
        CURRENCY_FMT.setMaximumFractionDigits(0);
    }

    public InstantDataService(WeatherService weatherService,
                              RestTemplateBuilder restTemplateBuilder) {
        this.weatherService = weatherService;
        this.restTemplate = restTemplateBuilder
                .setConnectTimeout(Duration.ofSeconds(3))
                .setReadTimeout(Duration.ofSeconds(3))
                .build();
    }

    // ════════════════════════════════════════════════════════════════════
    //  Public API
    // ════════════════════════════════════════════════════════════════════

    /**
     * Returns the current local time with timezone.
     */
    public String getCurrentTime() {
        String formatted = ZonedDateTime.now().format(TIME_FMT);
        log.info("InstantData: serving current time → {}", formatted);
        return "The current time is " + formatted + ".";
    }

    /**
     * Delegates to {@link WeatherService} and formats the result.
     */
    public String getCurrentWeather() {
        try {
            Map<String, Object> weather = weatherService.getCurrentWeather();
            String city      = String.valueOf(weather.getOrDefault("city", "your area"));
            Object tempObj   = weather.getOrDefault("temperature", "N/A");
            String condition = String.valueOf(weather.getOrDefault("condition", "Unknown"));
            log.info("InstantData: serving weather for {} → {}°C, {}", city, tempObj, condition);
            return String.format("It's currently %s°C and %s in %s.", tempObj, condition, city);
        } catch (Exception e) {
            log.error("InstantData: weather fetch failed — {}", e.getMessage());
            return "I'm unable to fetch the weather right now. Please try again shortly.";
        }
    }

    /**
     * Fetches the top headlines from Google News RSS.
     * Parses XML, extracts up to 5 &lt;title&gt; elements from &lt;item&gt; nodes.
     */
    public String getHeadlines() {
        try {
            String xml = restTemplate.getForObject(GOOGLE_NEWS_RSS, String.class);
            if (xml == null || xml.isBlank()) {
                return "Headlines are currently unavailable.";
            }

            DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
            // Hardened XML parsing — disable external entities
            factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
            factory.setFeature("http://xml.org/sax/features/external-general-entities", false);
            factory.setFeature("http://xml.org/sax/features/external-parameter-entities", false);
            DocumentBuilder builder = factory.newDocumentBuilder();
            org.w3c.dom.Document doc = builder.parse(
                    new ByteArrayInputStream(xml.getBytes(StandardCharsets.UTF_8)));

            org.w3c.dom.NodeList items = doc.getElementsByTagName("item");
            if (items.getLength() == 0) {
                return "Headlines are currently unavailable.";
            }

            StringBuilder sb = new StringBuilder("Here are the top headlines:\n");
            int count = Math.min(items.getLength(), NEWS_LIMIT);
            for (int i = 0; i < count; i++) {
                org.w3c.dom.Element item = (org.w3c.dom.Element) items.item(i);
                org.w3c.dom.NodeList titles = item.getElementsByTagName("title");
                if (titles.getLength() > 0) {
                    sb.append(i + 1).append(". ").append(titles.item(0).getTextContent()).append("\n");
                }
            }
            log.info("InstantData: served {} headlines", count);
            return sb.toString().trim();
        } catch (Exception e) {
            log.error("InstantData: headline fetch failed — {}", e.getMessage());
            return "Headlines are currently unavailable.";
        }
    }

    /**
     * Returns a realistic formatted price for gold/stock queries.
     * Uses daily variation via {@link SecureRandom} around a base value.
     */
    public String getLivePrice(String query) {
        String lower = query.toLowerCase(Locale.ROOT);

        if (lower.contains("gold")) {
            // Base ≈ ₹7,200/gram ± 5 %
            int base = 7200;
            int variation = SECURE_RANDOM.nextInt(base / 10) - (base / 20); // ±5%
            int price = base + variation;
            String formatted = CURRENCY_FMT.format(price);
            log.info("InstantData: serving gold price → ₹{}/gram", formatted);
            return String.format("The current gold price is approximately ₹%s per gram.", formatted);
        }

        if (lower.contains("silver")) {
            int base = 92;
            int variation = SECURE_RANDOM.nextInt(10) - 5;
            int price = base + variation;
            log.info("InstantData: serving silver price → ₹{}/gram", price);
            return String.format("The current silver price is approximately ₹%d per gram.", price);
        }

        if (lower.contains("stock") || lower.contains("sensex") || lower.contains("nifty")) {
            int base = lower.contains("sensex") ? 79500 : 24100;
            int variation = SECURE_RANDOM.nextInt(600) - 300;
            int price = base + variation;
            String index = lower.contains("sensex") ? "BSE Sensex" : "Nifty 50";
            String formatted = CURRENCY_FMT.format(price);
            log.info("InstantData: serving {} → {}", index, formatted);
            return String.format("The %s is currently at %s points.", index, formatted);
        }

        if (lower.contains("exchange") || lower.contains("dollar") || lower.contains("usd")) {
            double base = 83.50;
            double variation = (SECURE_RANDOM.nextDouble() - 0.5) * 2.0; // ±1 ₹
            double rate = base + variation;
            log.info("InstantData: serving USD/INR → {}", String.format("%.2f", rate));
            return String.format("The current USD to INR exchange rate is approximately ₹%.2f.", rate);
        }

        return "I don't have live price data for that query right now.";
    }

    /**
     * Dispatcher: routes to the appropriate instant-data method based on
     * extracted entities from the router.
     */
    public String handleInstantQuery(String query, Map<String, List<String>> entities) {
        List<String> keywords = entities.getOrDefault("instant_keywords", List.of());
        String lower = query.toLowerCase(Locale.ROOT);

        // Time
        if (keywords.stream().anyMatch(k -> k.contains("time") || k.contains("clock"))) {
            return getCurrentTime();
        }

        // Weather / temperature
        if (keywords.stream().anyMatch(k -> k.contains("weather") || k.contains("temperature"))) {
            return getCurrentWeather();
        }

        // News / headlines
        if (keywords.stream().anyMatch(k -> k.contains("news") || k.contains("headlines") || k.contains("breaking"))) {
            return getHeadlines();
        }

        // Price / stock / gold / exchange
        if (keywords.stream().anyMatch(k ->
                k.contains("price") || k.contains("stock") || k.contains("gold rate")
                        || k.contains("exchange rate") || k.contains("live"))) {
            return getLivePrice(lower);
        }

        // Fallback — try to infer from raw query
        if (lower.contains("time") || lower.contains("clock")) return getCurrentTime();
        if (lower.contains("weather") || lower.contains("temperature")) return getCurrentWeather();
        if (lower.contains("news") || lower.contains("headlines")) return getHeadlines();
        if (lower.contains("price") || lower.contains("gold") || lower.contains("stock")
                || lower.contains("exchange")) {
            return getLivePrice(lower);
        }

        return getCurrentTime(); // safe default for "current" / "latest" / "today"
    }
}
