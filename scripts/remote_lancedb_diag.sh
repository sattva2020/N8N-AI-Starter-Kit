#!/usr/bin/env bash
set -euo pipefail
REMOTE_DIR="/opt/graphrag"
CONDA_PREFIX="/root/miniconda"
export PATH="${CONDA_PREFIX}/bin:$PATH"
cd "${REMOTE_DIR}"

echo "=== conda python ==="
conda run -n graphrag --no-capture-output python -c 'import sys; print(sys.version)'

echo "=== pyarrow location ==="
conda run -n graphrag --no-capture-output python - <<'PY'
import pyarrow as pa, sys
print('pyarrow', getattr(pa, '__file__', None))
PY

echo "=== lancedb import ==="
conda run -n graphrag --no-capture-output python - <<'PY'
import sys, traceback
try:
    import lancedb
    print('lancedb', getattr(lancedb, '__file__', None))
except Exception as e:
    print('lancedb import error', type(e).__name__, e)
    traceback.print_exc()
    sys.exit(2)
PY

# find shared objects
echo "=== locating lancedb/arrow .so files ==="
find "${CONDA_PREFIX}/envs/graphrag" -type f \( -iname '*lancedb*.so*' -o -iname '*pyarrow*.so*' -o -iname '*arrow*.so*' -o -iname '*libarrow*.so*' \) -print || true

for f in $(find "${CONDA_PREFIX}/envs/graphrag" -type f \( -iname '*lancedb*.so*' -o -iname '*pyarrow*.so*' -o -iname '*arrow*.so*' -o -iname '*libarrow*.so*' \) -print); do
  echo "--- ldd for $f ---"
  ldd "$f" || true
done

echo "=== dmesg tail ==="
dmesg | tail -n 50 || true

echo "=== END lancedb diagnostics ==="
