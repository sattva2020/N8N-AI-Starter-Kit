#!/usr/bin/env bash
set -euo pipefail
REMOTE_DIR="/opt/graphrag"
CONDA_PREFIX="/root/miniconda"
export PATH="${CONDA_PREFIX}/bin:$PATH"
cd "${REMOTE_DIR}"

echo "=== CPU info ==="
lscpu || true
echo
cat /proc/cpuinfo | sed -n '1,60p' || true

echo "\n=== Searching for candidate .so files (pyarrow, arrow, lancedb, lz4, zstd) ==="
find "${CONDA_PREFIX}/envs/graphrag" -type f \( -iname '*lancedb*.so*' -o -iname '*pyarrow*.so*' -o -iname '*arrow*.so*' -o -iname '*libarrow*.so*' -o -iname '*lz4*.so*' -o -iname '*zstd*.so*' -o -iname '*parquet*.so*' \) -print || true

# run file/readelf/ldd on each found .so
for f in $(find "${CONDA_PREFIX}/envs/graphrag" -type f \( -iname '*lancedb*.so*' -o -iname '*pyarrow*.so*' -o -iname '*arrow*.so*' -o -iname '*libarrow*.so*' -o -iname '*lz4*.so*' -o -iname '*zstd*.so*' -o -iname '*parquet*.so*' \) -print); do
  echo "--- FILE: $f ---"
  file "$f" || true
  echo "--- readelf -A ---"
  readelf -A "$f" 2>/dev/null || true
  echo "--- ldd ---"
  ldd "$f" || true
  echo
done

echo "=== dmesg tail ==="
dmesg | tail -n 80 || true

echo "=== END .so inspection ==="
