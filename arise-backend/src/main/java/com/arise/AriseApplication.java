package com.arise;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class AriseApplication {
    public static void main(String[] args) {
        SpringApplication.run(AriseApplication.class, args);
    }
}
