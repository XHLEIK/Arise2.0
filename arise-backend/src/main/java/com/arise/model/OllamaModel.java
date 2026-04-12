package com.arise.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OllamaModel {
    private String name;
    private String size;
    private String details;
    private String modifiedAt;
}
