package com.arise.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Slf4j
@Service
public class AiRouterService {

    // ── Intent taxonomy ─────────────────────────────────────────────────
    public enum Intent {
        GENERAL,
        INFORMATIVE,
        PERFORMATIVE,
        INSTANT
    }

    // ── Routing decision record ─────────────────────────────────────────
    public record RoutingDecision(
            Intent primaryIntent,
            Intent secondaryIntent,
            double confidence,
            Map<String, List<String>> extractedEntities,
            List<String> actionTargets,
            boolean clarificationNeeded,
            String clarificationQuestion
    ) {}

    // ── Pre-compiled patterns (class-init time, thread-safe) ───────────

    private static final List<String> PERFORMATIVE_KEYWORDS = List.of(
            "open", "launch", "close", "run", "start", "stop",
            "go to", "navigate", "switch to", "turn on", "turn off",
            "play", "find", "search", "execute", "shut down",
            "scan", "rescan", "refresh"
    );
    private static final Pattern PERFORMATIVE_PATTERN;

    static {
        StringJoiner joiner = new StringJoiner("|");
        for (String kw : PERFORMATIVE_KEYWORDS) {
            joiner.add(Pattern.quote(kw));
        }
        PERFORMATIVE_PATTERN = Pattern.compile("\\b(" + joiner + ")\\b", Pattern.CASE_INSENSITIVE);
    }

    /** Keywords that signal an INSTANT data query. */
    private static final List<String> INSTANT_KEYWORDS = List.of(
            "weather", "temperature", "news", "headlines",
            "time", "clock", "stock", "price", "gold rate",
            "exchange rate", "live", "current", "latest",
            "today", "right now", "breaking"
    );
    private static final Pattern INSTANT_PATTERN;

    static {
        StringJoiner joiner = new StringJoiner("|");
        for (String kw : INSTANT_KEYWORDS) {
            joiner.add(Pattern.quote(kw));
        }
        INSTANT_PATTERN = Pattern.compile("\\b(" + joiner + ")\\b", Pattern.CASE_INSENSITIVE);
    }

    /** Phrase-prefixes that signal an INFORMATIVE intent. */
    private static final List<String> INFORMATIVE_PHRASES = List.of(
            "who is", "what is", "why do", "how does",
            "explain", "summarize", "describe", "tell me about",
            "give me details", "compare", "define", "history of"
    );
    private static final Pattern INFORMATIVE_PATTERN;

    static {
        StringJoiner joiner = new StringJoiner("|");
        for (String phrase : INFORMATIVE_PHRASES) {
            joiner.add(Pattern.quote(phrase));
        }
        INFORMATIVE_PATTERN = Pattern.compile("\\b(" + joiner + ")\\b", Pattern.CASE_INSENSITIVE);
    }

    /** URL pattern — matches common domain forms like youtube.com, www.google.com, etc. */
    private static final Pattern URL_PATTERN = Pattern.compile(
            "(https?://[^\\s]+|(?:www\\.)?[a-zA-Z0-9-]+\\.[a-zA-Z]{2,}(?:/[^\\s]*)?)",
            Pattern.CASE_INSENSITIVE
    );

    /**
     * After an action verb, capture the next 1-3 words as a potential app-name / target.
     * Group 1 = verb, Group 2 = 1-3 trailing words.
     */
    private static final Pattern APP_NAME_PATTERN;

    static {
        StringJoiner joiner = new StringJoiner("|");
        for (String kw : PERFORMATIVE_KEYWORDS) {
            joiner.add(Pattern.quote(kw));
        }
        APP_NAME_PATTERN = Pattern.compile(
                "\\b(" + joiner + ")\\s+([a-zA-Z0-9._-]+(?:\\s+[a-zA-Z0-9._-]+){0,2})",
                Pattern.CASE_INSENSITIVE
        );
    }

    private static final Pattern BROWSER_INDICATOR_PATTERN = Pattern.compile(
            "\\b(?:on|in|using|with|via)\\s+(?:the\\s+)?(brave|chrome|firefox|edge|safari|opera|browser)(?:\\s+browser)?\\b",
            Pattern.CASE_INSENSITIVE
    );

    // ── Confidence constants ────────────────────────────────────────────
    private static final double CONF_EXACT_KEYWORD = 0.95;
    private static final double CONF_PATTERN_MATCH = 0.85;
    private static final double CONF_FUZZY         = 0.60;
    private static final double CONF_DEFAULT       = 0.50;

    // ════════════════════════════════════════════════════════════════════
    //  PUBLIC API
    // ════════════════════════════════════════════════════════════════════

    /**
     * Classify the user prompt into an {@link Intent}, extract entities,
     * and produce a fully-formed {@link RoutingDecision}.
     */
    public RoutingDecision routePrompt(String prompt) {
        if (prompt == null || prompt.isBlank()) {
            log.info("Router: empty prompt → GENERAL (default)");
            return defaultDecision();
        }

        // Step 1 — normalise
        String normalised = prompt.trim().toLowerCase(Locale.ROOT);

        Map<String, List<String>> entities = new LinkedHashMap<>();
        List<String> actionTargets = new ArrayList<>();

        // Preprocess to find browser indicators and strip them from the match target
        String browserOverride = null;
        Matcher browserMatcher = BROWSER_INDICATOR_PATTERN.matcher(normalised);
        if (browserMatcher.find()) {
            browserOverride = browserMatcher.group(1);
            normalised = browserMatcher.replaceAll("").replaceAll("\\s+", " ").trim();
        }

        if (browserOverride != null) {
            entities.computeIfAbsent("browser_override", k -> new ArrayList<>()).add(browserOverride);
        }

        boolean performativeFound = false;
        boolean instantFound      = false;
        boolean informativeFound  = false;

        double performativeConf = 0.0;
        double instantConf      = 0.0;
        double informativeConf  = 0.0;

        // ── Step 2 — PERFORMATIVE (highest priority for actions) ────────
        Matcher perfMatcher = PERFORMATIVE_PATTERN.matcher(normalised);
        if (perfMatcher.find()) {
            performativeFound = true;
            performativeConf  = CONF_EXACT_KEYWORD;
            entities.computeIfAbsent("action_verbs", k -> new ArrayList<>())
                    .add(perfMatcher.group(1));

            // Extract URLs
            Matcher urlMatcher = URL_PATTERN.matcher(normalised);
            while (urlMatcher.find()) {
                actionTargets.add(urlMatcher.group());
                entities.computeIfAbsent("urls", k -> new ArrayList<>())
                        .add(urlMatcher.group());
            }

            // Extract app names (1-3 words after the verb)
            Matcher appMatcher = APP_NAME_PATTERN.matcher(normalised);
            while (appMatcher.find()) {
                String candidate = appMatcher.group(2).trim();
                // Avoid duplicating URLs already captured
                if (!actionTargets.contains(candidate)) {
                    actionTargets.add(candidate);
                    entities.computeIfAbsent("app_names", k -> new ArrayList<>())
                            .add(candidate);
                }
            }
        }

        // ── Step 3 — INSTANT keywords ──────────────────────────────────
        Matcher instMatcher = INSTANT_PATTERN.matcher(normalised);
        while (instMatcher.find()) {
            instantFound = true;
            instantConf  = CONF_EXACT_KEYWORD;
            entities.computeIfAbsent("instant_keywords", k -> new ArrayList<>())
                    .add(instMatcher.group(1));
        }

        // Extract simple location / ticker hints (words after "in" / "for")
        extractContextualEntities(normalised, entities);

        // ── Step 4 — INFORMATIVE patterns ──────────────────────────────
        Matcher infoMatcher = INFORMATIVE_PATTERN.matcher(normalised);
        if (infoMatcher.find()) {
            informativeFound = true;
            informativeConf  = CONF_PATTERN_MATCH;
            entities.computeIfAbsent("informative_phrases", k -> new ArrayList<>())
                    .add(infoMatcher.group(1));
        }

        // ── Step 5 — Build RoutingDecision ─────────────────────────────

        // 5a: PERFORMATIVE verb found but no target extracted → clarify
        if (performativeFound && actionTargets.isEmpty()) {
            List<String> verbs = entities.getOrDefault("action_verbs", List.of());
            String verb = verbs.isEmpty() ? "" : verbs.get(0);
            if ("scan".equalsIgnoreCase(verb) || "rescan".equalsIgnoreCase(verb) || "refresh".equalsIgnoreCase(verb) || "update".equalsIgnoreCase(verb)) {
                actionTargets.add("system");
                entities.computeIfAbsent("app_names", k -> new ArrayList<>()).add("system");
            } else {
                log.info("Router: PERFORMATIVE verb detected but no target → clarification needed");
                return new RoutingDecision(
                        Intent.PERFORMATIVE,
                        instantFound ? Intent.INSTANT : null,
                        CONF_FUZZY,
                        Collections.unmodifiableMap(entities),
                        List.of(),
                        true,
                        "Which application would you like me to open?"
                );
            }
        }

        // 5b: Mixed PERFORMATIVE + INSTANT
        if (performativeFound && instantFound) {
            log.info("Router decision: intent=PERFORMATIVE (secondary=INSTANT), confidence={}, entities={}",
                    performativeConf, entities);
            return new RoutingDecision(
                    Intent.PERFORMATIVE,
                    Intent.INSTANT,
                    performativeConf,
                    Collections.unmodifiableMap(entities),
                    List.copyOf(actionTargets),
                    false,
                    null
            );
        }

        // 5c: Pure PERFORMATIVE
        if (performativeFound) {
            log.info("Router decision: intent=PERFORMATIVE, confidence={}, entities={}",
                    performativeConf, entities);
            return new RoutingDecision(
                    Intent.PERFORMATIVE,
                    null,
                    performativeConf,
                    Collections.unmodifiableMap(entities),
                    List.copyOf(actionTargets),
                    false,
                    null
            );
        }

        // 5d: Pure INSTANT
        if (instantFound) {
            log.info("Router decision: intent=INSTANT, confidence={}, entities={}",
                    instantConf, entities);
            return new RoutingDecision(
                    Intent.INSTANT,
                    null,
                    instantConf,
                    Collections.unmodifiableMap(entities),
                    List.of(),
                    false,
                    null
            );
        }

        // 5e: INFORMATIVE
        if (informativeFound) {
            log.info("Router decision: intent=INFORMATIVE, confidence={}, entities={}",
                    informativeConf, entities);
            return new RoutingDecision(
                    Intent.INFORMATIVE,
                    null,
                    informativeConf,
                    Collections.unmodifiableMap(entities),
                    List.of(),
                    false,
                    null
            );
        }

        // 5f: Default → GENERAL
        log.info("Router decision: intent=GENERAL, confidence={}", CONF_DEFAULT);
        return defaultDecision();
    }

    // ── Private helpers ─────────────────────────────────────────────────

    private static final Pattern CONTEXT_AFTER_IN = Pattern.compile(
            "\\b(?:in|for|of|at)\\s+([a-zA-Z][a-zA-Z\\s]{1,30}?)(?:\\.|,|\\?|!|$)",
            Pattern.CASE_INSENSITIVE
    );

    /**
     * Extracts contextual entities (locations, tickers, topics) that follow
     * prepositions like "in", "for", "of", "at".
     */
    private void extractContextualEntities(String normalised, Map<String, List<String>> entities) {
        Matcher ctxMatcher = CONTEXT_AFTER_IN.matcher(normalised);
        while (ctxMatcher.find()) {
            String value = ctxMatcher.group(1).trim();
            if (!value.isEmpty() && value.length() > 1) {
                entities.computeIfAbsent("context_hints", k -> new ArrayList<>())
                        .add(value);
            }
        }
    }

    private RoutingDecision defaultDecision() {
        return new RoutingDecision(
                Intent.GENERAL,
                null,
                CONF_DEFAULT,
                Map.of(),
                List.of(),
                false,
                null
        );
    }
}
