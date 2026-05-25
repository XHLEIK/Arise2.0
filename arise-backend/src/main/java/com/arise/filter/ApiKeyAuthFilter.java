package com.arise.filter;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.lang.NonNull;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.preauth.PreAuthenticatedAuthenticationToken;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.security.MessageDigest;
import java.util.Collections;

@Slf4j
@Component
public class ApiKeyAuthFilter extends OncePerRequestFilter {

    @Value("${arise.security.api-key}")
    private String expectedApiKey;

    @Override
    protected void doFilterInternal(@NonNull HttpServletRequest request, @NonNull HttpServletResponse response, @NonNull FilterChain filterChain)
            throws ServletException, IOException {

        // Extract API key from header
        String providedKey = request.getHeader("X-API-KEY");

        if (providedKey != null && !providedKey.isBlank()
                && MessageDigest.isEqual(expectedApiKey.getBytes(), providedKey.getBytes())) {
            // Valid local UI request — use timing-safe comparison to prevent timing attacks
            PreAuthenticatedAuthenticationToken auth = new PreAuthenticatedAuthenticationToken("A.R.I.S.E_UI", null,
                    Collections.emptyList());
            SecurityContextHolder.getContext().setAuthentication(auth);
        }

        // Also allows JWT down the line if this fails
        filterChain.doFilter(request, response);
    }
}
