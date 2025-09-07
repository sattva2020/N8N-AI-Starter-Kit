#!/usr/bin/env python3
import asyncio
import faulthandler
import os
import sys

faulthandler.enable()
print('DEBUG: starting', sys.version.splitlines()[0])

print('STEP 1: importing modules')
try:
    import faiss
    import numpy as np
    from graphrag.api.index import GraphRAG
    from ollama import OllamaClient

    print('STEP 1 OK: numpy', np.__version__, 'faiss', getattr(faiss, '__file__', None))
except Exception as e:
    print('STEP 1 ERROR', type(e).__name__, e)
    raise

print('STEP 2: instantiating OllamaClient')
try:
    ollama_url = os.environ.get('OLLAMA_URL', 'http://localhost:11434')
    client = OllamaClient(ollama_url)
    print('STEP 2 OK: OllamaClient created')
except Exception as e:
    print('STEP 2 ERROR', type(e).__name__, e)
    raise

print('STEP 3: creating GraphRAG (no indexing yet)')
try:
    rag = GraphRAG(
        llm_func=lambda prompt: client.chat(
            model="llama3.2:latest:q4_k_m", messages=[{"role": "user", "content": prompt}]
        ).content,
        retriever_config={"vector_dim": 1024, "index_path": "./test_graphrag/index.faiss"},
    )
    print('STEP 3 OK: GraphRAG instanced')
except Exception as e:
    print('STEP 3 ERROR', type(e).__name__, e)
    raise

print('STEP 4: running index_texts (await)')


async def run_index():
    try:
        await rag.index_texts(["Small test document about GraphRAG."])
        print('STEP 4 OK: index_texts finished')
    except Exception as e:
        print('STEP 4 ERROR', type(e).__name__, e)
        raise


try:
    asyncio.run(run_index())
except Exception as e:
    print('ASYNC ERROR', type(e).__name__, e)
    raise

print('STEP 5: running query')


async def run_query():
    try:
        res = await rag.query('What is GraphRAG?')
        print('STEP 5 OK: query result', res)
    except Exception as e:
        print('STEP 5 ERROR', type(e).__name__, e)
        raise


try:
    asyncio.run(run_query())
except Exception as e:
    print('ASYNC QUERY ERROR', type(e).__name__, e)
    raise

print('DEBUG: finished')
