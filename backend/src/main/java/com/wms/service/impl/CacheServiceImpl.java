package com.wms.service.impl;

import com.wms.service.CacheService;
import org.springframework.cache.CacheManager;
import org.springframework.stereotype.Service;

/**
 * CacheServiceImpl — implements cache management.
 * Falls back gracefully if Redis is unavailable.
 */
@Service
public class CacheServiceImpl implements CacheService {

	private final CacheManager cacheManager;

	public CacheServiceImpl(CacheManager cacheManager) {
		this.cacheManager = cacheManager;
	}

	@Override
	public void clearCache(String cacheKey) {
		if (cacheManager != null) {
			var cache = cacheManager.getCache(cacheKey);
			if (cache != null) {
				cache.clear();
			}
		}
	}

	@Override
	public void clearAllCaches() {
		if (cacheManager != null) {
			cacheManager.getCacheNames().forEach(name -> {
				var cache = cacheManager.getCache(name);
				if (cache != null) {
					cache.clear();
				}
			});
		}
	}

	@Override
	public boolean isCacheAvailable() {
		return cacheManager != null && 
		       !(cacheManager instanceof org.springframework.cache.support.NoOpCacheManager);
	}
}
