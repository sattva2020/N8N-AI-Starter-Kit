from pathlib import Path
import os
import sys
import runpy


ALLOWED_ENV_KEYS = {
    'CLICKHOUSE_HOST',
    'CLICKHOUSE_PORT',
    'CLICKHOUSE_USER',
    'CLICKHOUSE_PASSWORD',
    'CLICKHOUSE_DATABASE',
    'POSTGRES_HOST',
    'POSTGRES_PORT',
    'POSTGRES_USER',
    'POSTGRES_PASSWORD',
    'POSTGRES_DATABASE',
    'N8N_API_URL',
    'N8N_API_KEY',
    'REDIS_URL',
    'ETL_BATCH_SIZE',
    'ETL_MAX_RETRIES',
    'ETL_RETRY_DELAY',
    'LOG_LEVEL',
    'LOG_FILE',
}


def load_env_file(path: Path) -> None:
    if not path.exists():
        print(f"env file not found: {path}", file=sys.stderr)
        return
    with path.open(encoding="utf-8") as f:
        for raw in f:
            line = raw.strip()
            if not line or line.startswith('#'):
                continue
            if '=' not in line:
                continue
            k, v = line.split('=', 1)
            k = k.strip()
            v = v.strip()
            # strip optional quotes
            if (v.startswith('"') and v.endswith('"')) or (v.startswith("'") and v.endswith("'")):
                v = v[1:-1]
            if k in ALLOWED_ENV_KEYS:
                os.environ[k] = v


def prune_and_prepare_env(env_path: Path) -> None:
    # Preserve a minimal set of system vars required for Python to run
    preserved = {
        k: os.environ[k] for k in ('PATH', 'SystemRoot', 'COMSPEC', 'TEMP', 'TMP', 'USERPROFILE') if k in os.environ
    }
    os.environ.clear()
    os.environ.update(preserved)

    load_env_file(env_path)

    # If services are started as containers with their names, map common container hostnames to localhost
    # so that host-run ETL can connect to ports published on the host.
    if os.environ.get('CLICKHOUSE_HOST', '').lower() in ('clickhouse', 'clickhouse-server'):
        os.environ['CLICKHOUSE_HOST'] = '127.0.0.1'
    if os.environ.get('POSTGRES_HOST', '').lower() in ('n8n-postgres', 'postgres', 'etl-postgres'):
        os.environ['POSTGRES_HOST'] = '127.0.0.1'
    # rewrite redis url if it points at container name
    red = os.environ.get('REDIS_URL')
    if red and 'redis://redis' in red:
        os.environ['REDIS_URL'] = red.replace('redis://redis', 'redis://127.0.0.1')


if __name__ == '__main__':
    repo_dir = Path(__file__).parent
    env_file = repo_dir / '.env.etl'
    print(f'Preparing environment from: {env_file}')
    prune_and_prepare_env(env_file)

    # Small debug: print a few critical vars
    for key in ['CLICKHOUSE_HOST', 'CLICKHOUSE_PORT', 'POSTGRES_HOST', 'POSTGRES_PORT', 'REDIS_URL', 'N8N_API_URL']:
        print(f'{key}={os.environ.get(key)}')

    # Temporarily move repo-level .env out of the way so pydantic BaseSettings won't load it
    repo_root = Path(__file__).resolve().parents[2]
    root_env = repo_root / '.env'
    backup_env = repo_root / '.env.run_with_env.bak'
    moved = False
    try:
        if root_env.exists():
            print(f'Temporarily moving root .env -> {backup_env}')
            root_env.replace(backup_env)
            moved = True

        main_py = repo_dir / 'main.py'
        if not main_py.exists():
            print('main.py not found at', main_py, file=sys.stderr)
            sys.exit(1)

        # Ensure getpass.getuser will use an environ fallback on Windows so it
        # won't attempt pwd.getpwuid(os.getuid()) which doesn't exist on Windows
        # when running in some environments.
        if sys.platform.startswith('win'):
            os.environ.setdefault('LOGNAME', os.environ.get('USERNAME', 'winuser'))
            os.environ.setdefault('USER', os.environ.get('USERNAME', 'winuser'))
            os.environ.setdefault('USERNAME', os.environ.get('USERNAME', 'winuser'))

        # Run main.py in __main__ context
        # On Windows, some libraries (clickhouse_driver) try to import `pwd` which
        # doesn't exist; create a minimal shim module at runtime to satisfy imports.
        if sys.platform.startswith('win'):
            shim_dir = repo_dir / '__pwd_shim__'
            shim_dir.mkdir(exist_ok=True)
            shim_file = shim_dir / 'pwd.py'
            if not shim_file.exists():
                shim_file.write_text(
                    """
def getpwuid(uid):
    # minimal shim returning a tuple-like object with pw_name at index 0
    class Pw:
        def __init__(self):
            self.pw_name = 'winuser'
    return Pw()

def getpwnam(name):
    return getpwuid(0)
""",
                    encoding='utf-8',
                )
            # Prepend shim dir to sys.path so imports find it
            sys.path.insert(0, str(shim_dir))

        runpy.run_path(str(main_py), run_name='__main__')
    finally:
        if moved:
            try:
                backup_env.replace(root_env)
                print('Restored root .env')
            except Exception as exc:
                print('Failed to restore root .env:', exc, file=sys.stderr)
