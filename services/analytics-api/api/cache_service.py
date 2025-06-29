"""
Redis Cache Service
"""

import json
import asyncio
from typing import Any, Optional
import structlog
import redis.asyncio as redis

logger = structlog.get_logger(__name__)

class CacheService:
    """Redis cache service"""
    
    def __init__(self, config):
        self.config = config
        self.redis_client: Optional[redis.Redis] = None
        self._initialized = False

    async def initialize(self):
        """Initialize Redis connection"""
        try:
            self.redis_client = redis.from_url(
                self.config.redis_url,
                encoding="utf-8",
                decode_responses=True,
                socket_connect_timeout=5,
                socket_timeout=5,
                retry_on_timeout=True,
                health_check_interval=30
            )
            
            # Test connection
            await self.redis_client.ping()
            
            self._initialized = True
            logger.info("Redis cache service initialized", url=self.config.redis_url)
            
        except Exception as e:
            logger.error("Failed to initialize Redis cache service", error=str(e))
            # Don't raise - cache is optional
            self._initialized = False

    async def get(self, key: str) -> Optional[Any]:
        """Get value from cache"""
        if not self._initialized or not self.redis_client:
            return None
        
        try:
            value = await self.redis_client.get(key)
            if value:
                return json.loads(value)
            return None
            
        except Exception as e:
            logger.warning("Failed to get from cache", key=key, error=str(e))
            return None

    async def set(self, key: str, value: Any, ttl: int = None) -> bool:
        """Set value in cache"""
        if not self._initialized or not self.redis_client:
            return False
        
        try:
            serialized_value = json.dumps(value, default=str)
            ttl = ttl or self.config.cache_ttl_default
            
            await self.redis_client.setex(key, ttl, serialized_value)
            return True
            
        except Exception as e:
            logger.warning("Failed to set cache", key=key, error=str(e))
            return False

    async def delete(self, key: str) -> bool:
        """Delete key from cache"""
        if not self._initialized or not self.redis_client:
            return False
        
        try:
            result = await self.redis_client.delete(key)
            return result > 0
            
        except Exception as e:
            logger.warning("Failed to delete from cache", key=key, error=str(e))
            return False

    async def delete_pattern(self, pattern: str) -> int:
        """Delete keys matching pattern"""
        if not self._initialized or not self.redis_client:
            return 0
        
        try:
            keys = await self.redis_client.keys(pattern)
            if keys:
                result = await self.redis_client.delete(*keys)
                return result
            return 0
            
        except Exception as e:
            logger.warning("Failed to delete pattern from cache", pattern=pattern, error=str(e))
            return 0

    async def clear_all(self) -> bool:
        """Clear all cache"""
        if not self._initialized or not self.redis_client:
            return False
        
        try:
            await self.redis_client.flushdb()
            return True
            
        except Exception as e:
            logger.warning("Failed to clear cache", error=str(e))
            return False

    def is_connected(self) -> bool:
        """Check if Redis is connected"""
        return self._initialized and self.redis_client is not None

    async def get_stats(self) -> dict:
        """Get cache statistics"""
        if not self._initialized or not self.redis_client:
            return {}
        
        try:
            info = await self.redis_client.info()
            return {
                "connected": True,
                "used_memory": info.get("used_memory_human", "N/A"),
                "connected_clients": info.get("connected_clients", 0),
                "total_commands_processed": info.get("total_commands_processed", 0),
                "keyspace_hits": info.get("keyspace_hits", 0),
                "keyspace_misses": info.get("keyspace_misses", 0),
            }
        except Exception as e:
            logger.warning("Failed to get cache stats", error=str(e))
            return {"connected": False, "error": str(e)}

    async def close(self):
        """Close Redis connection"""
        if self.redis_client:
            try:
                await self.redis_client.aclose()
                self.redis_client = None
                self._initialized = False
                logger.info("Redis cache service closed")
            except Exception as e:
                logger.error("Error closing Redis cache service", error=str(e))
