package com.arise.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Slf4j
@Service
public class AiRouterService {

    public enum Intent {
        CONVERSATION,
        CODING,
        AUTOMATION,
        FILE_PROCESSING,
        WEB_SEARCH
    }

    /**
     * Inspects the prompt and classifies it into an Intent category.
     * Currently a structural routing layer to be expanded with LLM zero-shot
     * routing later.
     */
    public Intent routePrompt(String prompt) {
        if (prompt == null || prompt.isBlank()) {
            return Intent.CONVERSATION;
        }

        String lower = prompt.toLowerCase();

        if (lower.contains("code") || lower.contains("function") || lower.contains("debug") || lower.contains("python")
                || lower.contains("java") || lower.contains("flutter")) {
            log.info("Router classified prompt as CODING intent.");
            return Intent.CODING;
        } else if (lower.contains("search") || lower.contains("google") || lower.contains("look up")) {
            log.info("Router classified prompt as WEB_SEARCH intent.");
            return Intent.WEB_SEARCH;
        } else if (lower.contains("file") || lower.contains("document") || lower.contains("pdf")) {
            log.info("Router classified prompt as FILE_PROCESSING intent.");
            return Intent.FILE_PROCESSING;
        } else if (lower.contains("automate") || lower.contains("task") || lower.contains("script")) {
            log.info("Router classified prompt as AUTOMATION intent.");
            return Intent.AUTOMATION;
        }

        log.info("Router classified prompt as CONVERSATION intent.");
        return Intent.CONVERSATION;
    }
}
