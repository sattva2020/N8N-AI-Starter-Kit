#!/bin/bash
# filepath: scripts/setup-local-ollama.sh

# Определение цветов для вывода
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${GREEN}=== Настройка локального Ollama для Mac с Apple Silicon ===${NC}"

# 1. Проверка наличия Ollama
if ! command -v ollama &> /dev/null; then
    echo -e "${YELLOW}Ollama не установлен. Устанавливаем...${NC}"
    if command -v brew &> /dev/null; then
        brew install ollama
    else
        echo -e "${YELLOW}Homebrew не установлен. Пожалуйста, установите Ollama вручную с https://ollama.com/download${NC}"
        exit 1
    fi
fi

# 2. Запуск Ollama, если не запущен
if ! curl -s http://localhost:11434/api/version &> /dev/null; then
    echo -e "${YELLOW}Запуск Ollama...${NC}"
    ollama serve &
    OLLAMA_PID=$!
    sleep 3
fi

# Обработка завершения скрипта
cleanup() {
  if [ -n "$OLLAMA_PID" ]; then
    echo "Завершение процесса Ollama..."
    kill $OLLAMA_PID
  fi
  exit 0
}
trap cleanup SIGINT SIGTERM

# 3. Получение IP-адреса
MAC_IP=$(ipconfig getifaddr en0)
if [ -z "$MAC_IP" ]; then
    MAC_IP=$(ipconfig getifaddr en1)
fi
if [ -z "$MAC_IP" ]; then
    echo -e "${YELLOW}Не удалось определить IP-адрес. Используем localhost.${NC}"
    MAC_IP="localhost"
fi
echo -e "${GREEN}IP-адрес Mac: $MAC_IP${NC}"

# 4. Создание сети Docker
if ! docker network inspect mac-host-bridge &> /dev/null; then
    echo -e "${YELLOW}Создание сети Docker...${NC}"
    docker network create -d bridge mac-host-bridge
else
    echo -e "${GREEN}Сеть mac-host-bridge уже существует${NC}"
fi

# 5. Обновление .env файла
echo -e "${YELLOW}Обновление .env файла...${NC}"
if [ ! -f .env ]; then
  echo "Создание файла .env..."
  touch .env
fi

if grep -q "OLLAMA_HOST" .env; then
    sed -i '' "s/OLLAMA_HOST=.*/OLLAMA_HOST=$MAC_IP/" .env
else
    echo "OLLAMA_HOST=$MAC_IP" >> .env
fi

if grep -q "OLLAMA_API_BASE_URL" .env; then
    sed -i '' "s|OLLAMA_API_BASE_URL=.*|OLLAMA_API_BASE_URL=http://$MAC_IP:11434|" .env
else
    echo "OLLAMA_API_BASE_URL=http://$MAC_IP:11434" >> .env
fi

if grep -q "USE_LOCAL_OLLAMA" .env; then
    sed -i '' "s/USE_LOCAL_OLLAMA=.*/USE_LOCAL_OLLAMA=true/" .env
else
    echo "USE_LOCAL_OLLAMA=true" >> .env
fi

# 6. Создание compose файла для локального Ollama
echo -e "${YELLOW}Создание файла docker-compose для локального Ollama...${NC}"
mkdir -p compose
cat > compose/local-ollama.yml << EOF
services:
  # Конфигурация для локального Ollama без промежуточного NGINX
  ollama-config:
    image: alpine:latest
    container_name: ollama-config
    restart: "no"
    command: sh -c "echo 'Ollama настроен на использование локального API: \${OLLAMA_HOST}:11434' && sleep 2"
    networks:
      - frontend
      - backend
      - mac-host-bridge
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.ollama.rule=Host(\`\${OLLAMA_DOMAIN}\`)"
      - "traefik.http.routers.ollama.entrypoints=websecure"
      - "traefik.http.routers.ollama.tls.certresolver=myresolver"
      - "traefik.http.middlewares.ollama-forward.forwardauth.address=http://\${OLLAMA_HOST}:11434"
      - "traefik.http.services.ollama.loadbalancer.server.url=http://\${OLLAMA_HOST}:11434"
    environment:
      - OLLAMA_HOST=\${OLLAMA_HOST:-localhost}

networks:
  mac-host-bridge:
    external: true
EOF

# 7. Проверка наличия Docker
if ! command -v docker &> /dev/null; then
  echo "Docker не установлен. Пожалуйста, установите Docker перед запуском этого скрипта."
  exit 1
fi

# 8. Проверка статуса Ollama
echo -e "\n${GREEN}Статус локального Ollama:${NC}"
curl -s http://localhost:11434/api/version
echo -e "\n"
echo -e "${YELLOW}Доступные модели:${NC}"
ollama list