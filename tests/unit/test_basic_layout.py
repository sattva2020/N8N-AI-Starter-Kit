from pathlib import Path


def test_env_schema_exists():
    assert Path("env.schema").exists(), "env.schema must exist at repo root"


def test_compose_yamls_present_and_nonempty():
    compose_dir = Path("compose")
    assert compose_dir.exists(), "compose/ directory must exist"
    yamls = list(compose_dir.rglob("*.yml")) + list(compose_dir.rglob("*.yaml"))
    assert yamls, "compose must contain at least one yaml"
    for p in yamls:
        assert p.stat().st_size > 0, f"compose file is empty: {p}"
