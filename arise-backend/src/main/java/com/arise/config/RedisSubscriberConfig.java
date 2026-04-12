package com.arise.config;

import com.arise.service.EventService;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.listener.ChannelTopic;
import org.springframework.data.redis.listener.RedisMessageListenerContainer;
import org.springframework.data.redis.listener.adapter.MessageListenerAdapter;
import org.springframework.lang.NonNull;

@Configuration
public class RedisSubscriberConfig {

    @Bean
    public RedisMessageListenerContainer redisContainer(@NonNull RedisConnectionFactory connectionFactory,
                                                        @NonNull MessageListenerAdapter voiceEventsListenerAdapter,
                                                        @NonNull MessageListenerAdapter systemEventsListenerAdapter) {
        RedisMessageListenerContainer container = new RedisMessageListenerContainer();
        container.setConnectionFactory(connectionFactory);
        container.addMessageListener(voiceEventsListenerAdapter, new ChannelTopic("voice_events"));
        container.addMessageListener(systemEventsListenerAdapter, new ChannelTopic("system_events"));
        return container;
    }

    @Bean
    public MessageListenerAdapter voiceEventsListenerAdapter(EventService eventService) {
        return new MessageListenerAdapter(new VoiceMessageDelegate(eventService), "handleMessage");
    }

    @Bean
    public MessageListenerAdapter systemEventsListenerAdapter(EventService eventService) {
        return new MessageListenerAdapter(new SystemMessageDelegate(eventService), "handleMessage");
    }

    public static class VoiceMessageDelegate {
        private final EventService eventService;
        public VoiceMessageDelegate(EventService eventService) {
            this.eventService = eventService;
        }
        public void handleMessage(String message) {
            eventService.publishEvent("voice_events", message);
        }
    }

    public static class SystemMessageDelegate {
        private final EventService eventService;
        public SystemMessageDelegate(EventService eventService) {
            this.eventService = eventService;
        }
        public void handleMessage(String message) {
            eventService.publishEvent("system_events", message);
        }
    }
}
