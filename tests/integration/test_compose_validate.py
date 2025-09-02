import os
import shutil
import subprocess
from pathlib import Path

import pytest


def has_docker_compose() -> bool:
    return shutil.which("docker-compose") is not None or shutil.which("docker") is not None


@pytest.mark.integration
def test_docker_compose_config_can_render():
    if not has_docker_compose():
        pytest.skip("docker/docker-compose not available in test environment")

    root = Path(__file__).resolve().parents[2]
    files = ["docker-compose.yml"]
    # include the optional files if present, but don't fail if missing
    compose_optional = [
        "compose/networks.yml",
        "compose/optional-services.yml",
    ]
    for f in compose_optional:
        if (root / f).exists():
            files.append(f)

    cmd = None
    if shutil.which("docker-compose"):
        cmd = ["docker-compose", *sum([["-f", f] for f in files], []), "config"]
    else:
        cmd = ["docker", "compose", *sum([["-f", f] for f in files], []), "config"]

    env = os.environ.copy()
    env.setdefault("DOMAIN_NAME", "example.com")
    # set required LightRAG env to render labels; use safe placeholders
    env.setdefault("LIGHRAG_DOMAIN", "lightrag.example.com")
    env.setdefault("LIGHTRAG_API_KEY", "test-key")
    env.setdefault("TOKEN_SECRET", "test-secret")

    res = subprocess.run(cmd, cwd=root, env=env, capture_output=True, text=True)
    assert res.returncode == 0, f"compose config failed: {res.stderr[:500]}"
    assert "services:" in res.stdout
