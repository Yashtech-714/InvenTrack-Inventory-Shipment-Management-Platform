package com.wms.service;

/**
 * CacheService — provides cache management operations.
 * SOLID SRP: handles all cache-related operations.
 */
public interface CacheService {

	/**
	 * Clear cache by key pattern (used after updates).
	 * Example: "products", "suppliers", "reports::*"
	 */
	void clearCache(String cacheKey);

	/**
	 * Clear all caches (useful on full data refresh).
	 */
	void clearAllCaches();

	/**
	 * Check if cache is available/connected.
	 */
	boolean isCacheAvailable();
}
