package com.arise.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.SingleConnectionDataSource;

import javax.sql.DataSource;
import java.nio.file.Files;
import java.nio.file.Path;

@Configuration
public class DatabaseConfig {

    @Bean
    public DataSource dataSource(@Value("${arise.database.path}") String dbPath) throws Exception {
        Path path = Path.of(dbPath).toAbsolutePath().normalize();
        Files.createDirectories(path.getParent());
        String jdbcUrl = "jdbc:sqlite:" + path + "?journal_mode=WAL&busy_timeout=5000&synchronous=NORMAL";

        SingleConnectionDataSource ds = new SingleConnectionDataSource();
        ds.setDriverClassName("org.sqlite.JDBC");
        ds.setUrl(jdbcUrl);
        ds.setSuppressClose(true);
        return ds;
    }

    @Bean
    public JdbcTemplate jdbcTemplate(DataSource dataSource) {
        return new JdbcTemplate(dataSource);
    }
}
