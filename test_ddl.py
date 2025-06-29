#!/usr/bin/env python3
"""
Test DDL Schema for ClickHouse tables
"""

import asyncio
from clickhouse_driver import Client

async def test_tables():
    """Test individual table creation"""
    
    client = Client(
        host='localhost',
        port=9000,
        user='default',
        password='',
        database='default'
    )
    
    # Test workflow_executions table
    ddl1 = '''
        CREATE TABLE IF NOT EXISTS workflow_executions (
            id String,
            workflow_id String,
            workflow_name String,
            status String,
            mode String,
            started_at DateTime64(3),
            finished_at DateTime64(3),
            duration_ms UInt32,
            data_processed UInt32,
            created_at DateTime64(3) DEFAULT now(),
            INDEX idx_workflow_id workflow_id TYPE bloom_filter GRANULARITY 1,
            INDEX idx_status status TYPE set(0) GRANULARITY 1,
            INDEX idx_started_at started_at TYPE minmax GRANULARITY 1
        ) ENGINE = MergeTree()
        PARTITION BY toYYYYMM(started_at)
        ORDER BY (workflow_id, started_at)
        TTL toDateTime(started_at) + INTERVAL 1 YEAR
    '''
    
    try:
        client.execute(ddl1)
        print("✅ workflow_executions table created successfully")
    except Exception as e:
        print(f"❌ workflow_executions table creation failed: {e}")
        
    # Test workflow_metrics table
    ddl2 = '''
        CREATE TABLE IF NOT EXISTS workflow_metrics (
            workflow_id String,
            workflow_name String,
            total_executions UInt32,
            successful_executions UInt32,
            failed_executions UInt32,
            avg_duration_ms Float32,
            max_duration_ms UInt32,
            min_duration_ms UInt32,
            last_execution DateTime64(3),
            date Date,
            created_at DateTime64(3) DEFAULT now()
        ) ENGINE = ReplacingMergeTree(created_at)
        PARTITION BY toYYYYMM(date)
        ORDER BY (workflow_id, date)
        TTL date + INTERVAL 2 YEAR
    '''
    
    try:
        client.execute(ddl2)
        print("✅ workflow_metrics table created successfully")
    except Exception as e:
        print(f"❌ workflow_metrics table creation failed: {e}")
        
    # Test node_performance table  
    ddl3 = '''
        CREATE TABLE IF NOT EXISTS node_performance (
            execution_id String,
            workflow_id String,
            node_name String,
            node_type String,
            duration_ms UInt32,
            input_items UInt32,
            output_items UInt32,
            status String,
            error_message String,
            executed_at DateTime64(3),
            created_at DateTime64(3) DEFAULT now(),
            INDEX idx_workflow_id workflow_id TYPE bloom_filter GRANULARITY 1,
            INDEX idx_node_type node_type TYPE set(0) GRANULARITY 1
        ) ENGINE = MergeTree()
        PARTITION BY toYYYYMM(executed_at)
        ORDER BY (workflow_id, executed_at, node_name)
        TTL toDateTime(executed_at) + INTERVAL 6 MONTH
    '''
    
    try:
        client.execute(ddl3)
        print("✅ node_performance table created successfully")
    except Exception as e:
        print(f"❌ node_performance table creation failed: {e}")
        
    # Test error_analysis table
    ddl4 = '''
        CREATE TABLE IF NOT EXISTS error_analysis (
            id String,
            execution_id String,
            workflow_id String,
            workflow_name String,
            node_name String,
            error_type String,
            error_message String,
            error_details String,
            occurred_at DateTime64(3),
            resolved Bool DEFAULT false,
            created_at DateTime64(3) DEFAULT now(),
            INDEX idx_error_type error_type TYPE set(0) GRANULARITY 1,
            INDEX idx_workflow_id workflow_id TYPE bloom_filter GRANULARITY 1
        ) ENGINE = MergeTree()
        PARTITION BY toYYYYMM(occurred_at)
        ORDER BY (error_type, occurred_at)
        TTL toDateTime(occurred_at) + INTERVAL 1 YEAR
    '''
    
    try:
        client.execute(ddl4)
        print("✅ error_analysis table created successfully")
    except Exception as e:
        print(f"❌ error_analysis table creation failed: {e}")

if __name__ == "__main__":
    asyncio.run(test_tables())
