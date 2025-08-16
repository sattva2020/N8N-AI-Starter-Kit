#!/usr/bin/env bash
set -euo pipefail

# Rotate backups under a directory by keeping the newest N entries and
# archiving older ones into backup/archive/DATE/. Intended for local
# maintenance on Windows (Git Bash / WSL) and Unix CI.
#
# Usage:
#   rotate-backups.sh [-d backup_dir] [-k keep] [--dry-run]
# Examples:
#   rotate-backups.sh -d ./backup -k 5
#   rotate-backups.sh --dry-run

DIR="./backup"
KEEP=5
DRY_RUN=0

print_usage(){
  cat <<-USAGE
Usage: $0 [-d backup_dir] [-k keep] [--dry-run]
  -d DIR     Backup directory to manage (default: ./backup)
  -k KEEP    How many newest items to keep (default: 5)
  --dry-run  Show actions without modifying files
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d) DIR="$2"; shift 2;;
    -k) KEEP="$2"; shift 2;;
    --dry-run) DRY_RUN=1; shift;;
    -h|--help) print_usage; exit 0;;
    *) echo "Unknown arg: $1"; print_usage; exit 1;;
  esac
done

if [ ! -d "$DIR" ]; then
  echo "Backup directory not found: $DIR"
  exit 0
fi

ARCHIVE_DIR="$DIR/archive_$(date +%Y%m%d_%H%M%S)"

echo "Rotate backups in: $DIR (keep newest $KEEP)"
if [ "$DRY_RUN" -eq 1 ]; then
  echo "DRY RUN: no files will be changed"
fi

# Collect top-level entries (files and directories) excluding archive_*
mapfile -t entries < <(find "$DIR" -maxdepth 1 -mindepth 1 -printf '%T@ %p\n' 2>/dev/null \
  | grep -v '/archive_' || true)

if [ ${#entries[@]} -eq 0 ]; then
  echo "No entries found in $DIR"
  exit 0
fi

# Sort by timestamp (oldest first). We already have timestamps from find.
IFS=$'\n' sorted=( $(printf '%s\n' "${entries[@]}" | sort -n) )

# Extract just the paths
paths=()
for l in "${sorted[@]}"; do
  # line format: <epoch> <path>
  p="${l#* }"
  # skip any archive directories created previously
  case "$(basename "$p")" in
    archive_* ) continue ;;
  esac
  paths+=("$p")
done

total=${#paths[@]}
if [ "$total" -le "$KEEP" ]; then
  echo "Found $total items; nothing to rotate (<= $KEEP)"
  exit 0
fi

to_archive_count=$(( total - KEEP ))
echo "Found $total items; will archive $to_archive_count oldest item(s)."

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Would create archive directory: $ARCHIVE_DIR"
  echo "Would archive items:" 
  for ((i=0;i<to_archive_count;i++)); do
    echo "  - ${paths[i]}"
  done
  exit 0
fi

mkdir -p "$ARCHIVE_DIR"

for ((i=0;i<to_archive_count;i++)); do
  src="${paths[i]}"
  name=$(basename "$src")
  if [ -d "$src" ]; then
    # compress directory into archive dir
    tarball="$ARCHIVE_DIR/${name}.tar.gz"
    echo "Archiving directory $src -> $tarball"
    tar -C "$DIR" -czf "$tarball" "${name}"
    echo "Removing original directory $src"
    rm -rf "$src"
  else
    # move file into archive dir (preserve name)
    dest="$ARCHIVE_DIR/$name"
    echo "Moving file $src -> $dest"
    mv "$src" "$dest"
  fi
done

echo "Archive complete. Old items moved to: $ARCHIVE_DIR"
exit 0
#!/usr/bin/env bash
# Rotate/move old backup files from the repository `backup/` folder into an archive folder
# Usage: rotate-backups.sh [keep_count] [backup_dir]
# Defaults: keep_count=5, backup_dir=backup

set -euo pipefail
IFS=$'\n\t'

KEEP=${1:-5}
BACKUP_DIR=${2:-backup}

if [ ! -d "$BACKUP_DIR" ]; then
  echo "Backup directory '$BACKUP_DIR' does not exist. Nothing to do." >&2
  exit 0
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ARCHIVE_DIR="$BACKUP_DIR/archive/$TIMESTAMP"
mkdir -p "$ARCHIVE_DIR"

# Collect regular files only in the top-level of BACKUP_DIR (do not recurse)
mapfile -t FILES < <(find "$BACKUP_DIR" -maxdepth 1 -type f -print0 | xargs -0 -n1 echo)

# Filter out empty result
if [ "${#FILES[@]}" -eq 0 ]; then
  echo "No backup files found in '$BACKUP_DIR'."
  exit 0
fi

# If less or equal than KEEP, nothing to do
if [ "${#FILES[@]}" -le "$KEEP" ]; then
  echo "Found ${#FILES[@]} file(s); keeping all (<= $KEEP). Nothing to rotate."
  exit 0
fi

# Sort files by mtime ascending (oldest first) and move the oldest files leaving only KEEP most recent
# Use stat -c %Y to get epoch mtime
IFS=$'\n' sorted=( $(for f in "${FILES[@]}"; do echo "$(stat -c %Y "$f") $f"; done | sort -n | awk '{sub(/^\S+ /,""); print}'))

NUM_TO_MOVE=$(( ${#sorted[@]} - KEEP ))
if [ "$NUM_TO_MOVE" -le 0 ]; then
  echo "Nothing to move."
  exit 0
fi

echo "Keeping latest $KEEP files out of ${#sorted[@]} total. Moving $NUM_TO_MOVE old file(s) to: $ARCHIVE_DIR"

for ((i=0;i<NUM_TO_MOVE;i++)); do
  src="${sorted[i]}"
  if [ -f "$src" ]; then
    mv -v -- "$src" "$ARCHIVE_DIR/" || echo "Failed to move: $src"
  fi
done

echo "Rotation complete. Archive created: $ARCHIVE_DIR"
exit 0
