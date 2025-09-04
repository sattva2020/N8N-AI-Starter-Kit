#!/bin/bash

# N8N AI Starter Kit - Production Deployment Script (УСТАРЕЛО)
# Этот скрипт больше не используется. Для production-развертывания используйте обычный docker compose с корректной .env и настройками безопасности/SSL.

set -e

echo "\033[1;33m[WARN]\033[0m Production-профиль и отдельные production-сервисы больше не поддерживаются."
echo "\033[1;32m[INFO]\033[0m Для production используйте:"
echo "    docker compose up -d"
echo "или с нужным профилем:"
echo "    docker compose --profile cpu up -d"
echo "\033[1;32m[INFO]\033[0m Все настройки безопасности, доменов и SSL задаются через .env и конфиги Traefik."
