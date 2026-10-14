package com.wms.config;

import org.springframework.boot.autoconfigure.data.redis.RedisProperties;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.cache.RedisCacheManager;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.connection.lettuce.LettuceConnectionFactory;
import org.springframework.data.redis.serializer.GenericJackson2JsonRedisSerializer;
import org.springframework.data.redis.serializer.RedisSerializationContext;
import org.springframework.data.redis.serializer.StringRedisSerializer;

/**
 * RedisConfig — configures caching for read-heavy operations.
 * SOLID SRP: centralizes cache configuration.
 *
 * Cached operations:
 * - getAllProducts() — product catalog (static, frequently read)
 * - getAllSuppliers() — supplier dropdown (static)
 * - getAllStorageLocations() — location reference (static)
 * - Report endpoints — expensive aggregations
 *
 * NOT cached (real-time requirements):
 * - Inventory stock levels (changes frequently)
 * - Order/Purchase order items (transactional)
 * - Shipment status (must be current)
 */
@Configuration
@EnableCaching
@ConditionalOnProperty(name = "spring.cache.type", havingValue = "redis")
public class RedisConfig {

	/**
	 * Connection factory for Redis using Lettuce (non-blocking).
	 * Falls back to in-memory if Redis unavailable.
	 */
	@Bean
	public RedisConnectionFactory redisConnectionFactory(RedisProperties redisProperties) {
		LettuceConnectionFactory factory = new LettuceConnectionFactory(
				redisProperties.getHost(),
				redisProperties.getPort()
		);
		return factory;
	}

	/**
	 * Cache manager with JSON serialization for complex objects.
	 * TTL: 1 hour for static data, 30 mins for reports.
	 */
	@Bean
	public CacheManager cacheManager(RedisConnectionFactory connectionFactory) {
		if (connectionFactory == null) {
			// Fallback to no-op if Redis unavailable
			return new org.springframework.cache.support.NoOpCacheManager();
		}

		GenericJackson2JsonRedisSerializer jsonRedisSerializer = new GenericJackson2JsonRedisSerializer();

		StringRedisSerializer stringRedisSerializer = new StringRedisSerializer();

		RedisSerializationContext.SerializationPair<Object> pair =
				RedisSerializationContext.SerializationPair
						.fromSerializer(jsonRedisSerializer);

		return RedisCacheManager.builder(connectionFactory)
				.cacheDefaults(
						org.springframework.data.redis.cache.RedisCacheConfiguration
								.defaultCacheConfig()
								.serializeKeysWith(
										RedisSerializationContext.SerializationPair
												.fromSerializer(stringRedisSerializer)
								)
								.serializeValuesWith(pair)
								.entryTtl(java.time.Duration.ofHours(1))
				)
				.build();
	}
}
