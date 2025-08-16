FROM qdrant/qdrant:latest

# Install curl and wget (Debian based)
USER root
RUN apt-get update && apt-get install -y curl wget ca-certificates && rm -rf /var/lib/apt/lists/*

# Create expected data directories and set ownership so that when Docker
# initializes anonymous volumes from the image they inherit correct uid/gid
# (1000 used by upstream image). This avoids needing a separate 'qdrant_snapshots'
# manual creation step on the host.
RUN mkdir -p /qdrant/storage /qdrant/snapshots \
  && chown -R 1000:1000 /qdrant \
  && chmod -R 750 /qdrant

# Declare volumes so Docker will initialize them from the image content above
VOLUME ["/qdrant/storage", "/qdrant/snapshots"]

# Revert to default non-root user used by upstream image (uid 1000)
USER 1000

# No entrypoint changes; this image remains compatible with upstream qdrant
