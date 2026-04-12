package com.arise.controller;

import lombok.extern.slf4j.Slf4j;
import org.apache.catalina.connector.ClientAbortException;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;
import java.io.IOException;

@Slf4j
@ControllerAdvice
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {

    @ExceptionHandler({ClientAbortException.class, IOException.class})
    public void handleClientAbortException(Exception ex) {
        if (ex.getMessage() != null && (ex.getMessage().contains("Broken pipe") || ex.getMessage().contains("Connection reset by peer"))) {
            log.debug("Client disconnected during SSE stream: {}", ex.getMessage());
        } else {
            log.error("IO Exception during stream", ex);
        }
    }
}
