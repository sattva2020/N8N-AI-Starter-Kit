#!/usr/bin/env bash
set -euo pipefail

# Toggle the `web-interface` service in docker-compose.yml
# Usage: ./scripts/toggle-web-interface.sh enable|disable

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/docker-compose.yml"

if [ ! -f "$COMPOSE_FILE" ]; then
  echo "docker-compose.yml not found at $COMPOSE_FILE"
  exit 1
fi

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 enable|disable"
  exit 2
fi

ACTION="$1"
BACKUP="$COMPOSE_FILE.bak.$(date +%s)"
cp "$COMPOSE_FILE" "$BACKUP"

case "$ACTION" in
  enable)
    # Uncomment lines that start the commented web-interface block
    awk 'BEGIN{state=0}
    {
      if(state==0 && $0 ~ /^  # web-interface:/) { sub(/^  # /,"  "); print; state=1; next }
      if(state==1) {
        if($0 ~ /^  [^#].+:/) { state=0; print; next }
        sub(/^  # /,"  "); print; next
      }
      print
    }' "$BACKUP" > "$COMPOSE_FILE"
    echo "web-interface enabled (backup saved to $BACKUP)"
    ;;
  disable)
    # Comment out the web-interface block by prefixing lines with '  # '
    awk 'BEGIN{state=0}
    {
      if(state==0 && $0 ~ /^  web-interface:/) { sub(/^  /,"  # "); print; state=1; next }
      if(state==1) {
        if($0 ~ /^  [^#].+:/) { state=0; print; next }
        sub(/^  /,"  # "); print; next
      }
      print
    }' "$BACKUP" > "$COMPOSE_FILE"
    echo "web-interface disabled (backup saved to $BACKUP)"
    ;;
  *)
    echo "Unknown action: $ACTION"
    echo "Usage: $0 enable|disable"
    exit 2
    ;;
esac

exit 0
