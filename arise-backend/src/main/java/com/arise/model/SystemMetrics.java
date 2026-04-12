package com.arise.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SystemMetrics {
    private double cpuUsage;
    private double cpuTemp;
    private double gpuUsage;
    private double gpuTemp;
    private double ramUsage;
    private double storageUsage;
    private String timestamp;
}
