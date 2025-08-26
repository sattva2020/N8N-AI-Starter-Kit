"""Helpers for credential creation: CSV->JSON parsing and payload generation.

This file is used by unit tests to validate parsing and payload logic.
"""
import csv
import ast
import json
from typing import List, Dict, Any


def parse_csv_to_entries(path: str) -> List[Dict[str, Any]]:
    rows = []
    with open(path, newline='', encoding='utf-8') as fh:
        reader = csv.DictReader(fh)
        for r in reader:
            entry = {k: v for k, v in r.items()}
            if 'data' in entry and entry['data']:
                raw0 = entry['data']
                # fast path: if the CSV reader already returned a valid JSON string
                try:
                    entry['data'] = json.loads(raw0)
                    rows.append(entry)
                    continue
                except Exception:
                    pass

                raw = raw0
                # normalize newlines (CRLF -> LF)
                raw = raw.replace('\r\n', '\n').replace('\r', '\n')
                # strip surrounding quotes if present
                if len(raw) >= 2 and ((raw.startswith('"') and raw.endswith('"')) or (raw.startswith("'") and raw.endswith("'"))):
                    raw = raw[1:-1]
                # unescape doubled quotes often produced in CSV exports
                raw = raw.replace('""', '"')
                # if opening quote after { is missing (e.g. {url":...), insert it
                if raw.startswith('{') and not raw.startswith('{"') and '":' in raw:
                    raw = '{"' + raw[1:]
                try:
                    entry['data'] = json.loads(raw)
                except Exception:
                        # try extracting a {...} substring and parse that
                        try:
                            start = raw.index('{')
                            end = raw.rindex('}')
                            sub = raw[start:end+1]
                            try:
                                entry['data'] = json.loads(sub)
                            except Exception:
                                try:
                                    entry['data'] = ast.literal_eval(sub)
                                except Exception:
                                    entry['data'] = raw
                        except Exception:
                            entry['data'] = raw
            rows.append(entry)
    return rows


def build_payload(name: str, type_: str, data: Any) -> Dict[str, Any]:
    # ensure data is a dict
    if isinstance(data, str):
        try:
            data = json.loads(data)
        except Exception:
            data = {'value': data}

    payload = {
        'name': name,
        'type': type_,
        'nodesAccess': [],
        'data': data or {}
    }
    return payload


def detect_type_from_env(env: Dict[str, str], prefer: str = None) -> Dict[str, Any]:
    """Return a guessed payload for known env vars. Used for integration parity with bash script."""
    if prefer and prefer.lower() in ('qdrant', 'qdrantapi', 'qdrantApi'):
        return build_payload('qdrant', 'qdrantApi', {'url': env.get('QDRANT_URL', 'http://qdrant:6333'), 'apiKey': env.get('QDRANT_API_KEY', '')})
    if prefer and prefer.lower() in ('s3', 'aws', 'awsS3', 'minio'):
        return build_payload('s3', 'awsS3', {
            'accessKeyId': env.get('MINIO_ROOT_USER', env.get('AWS_ACCESS_KEY_ID', '')),
            'secretAccessKey': env.get('MINIO_ROOT_PASSWORD', env.get('AWS_SECRET_ACCESS_KEY', '')),
            'endpoint': env.get('MINIO_ENDPOINT', env.get('MINIO_URL', 'http://minio:9000')),
            'region': env.get('AWS_DEFAULT_REGION', 'us-east-1')
        })
    if prefer and prefer.lower() in ('redis',):
        return build_payload('redis', 'redis', {'url': env.get('REDIS_URL', 'redis://redis:6379'), 'password': env.get('REDIS_PASSWORD', '')})
    if prefer and prefer.lower() in ('graphiti', 'graphitiapi'):
        return build_payload('graphiti', 'graphitiApi', {'apiKey': env.get('GRAPHITI_API_KEY', ''), 'url': env.get('GRAPHITI_URL', 'http://graphiti:8000')})

    # fallback empty
    return build_payload('unknown', prefer or 'generic', {})
