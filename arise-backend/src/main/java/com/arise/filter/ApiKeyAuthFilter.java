package com.arise.filter;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.lang.NonNull;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.preauth.PreAuthenticatedAuthenticationToken;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Collections;

@Component
public class ApiKeyAuthFilter extends OncePerRequestFilter {

    @Value("${arise.security.api-key}")
    private String expectedApiKey;

    @Override
    protected void doFilterInternal(@NonNull HttpServletRequest request, @NonNull HttpServletResponse response, @NonNull FilterChain filterChain)
            throws ServletException, IOException {

        // Extract API key from header
        String providedKey = request.getHeader("X-API-KEY");

        if (expectedApiKey.equals(providedKey)) {
            // Valid local UI request
            PreAuthenticatedAuthenticationToken auth = new PreAuthenticatedAuthenticationToken("A.R.I.S.E_UI", null,
                    Collections.emptyList());
            SecurityContextHolder.getContext().setAuthentication(auth);
        }

        // Also allows JWT down the line if this fails
        filterChain.doFilter(request, response);
    }
}
