# filepath: scripts/diagnose.sh
#!/bin/bash
echo "====== Диагностика системы ======"
echo "Docker версия:"
docker --version

echo -e "\nDocker Compose версия:"
docker compose version

echo -e "\nСписок контейнеров:"
docker ps -a

echo -e "\nСписок сетей Docker:"
docker network ls

echo -e "\nПроверка конфигураций:"
if [ -f "config/vector/vector.yml" ]; then
  echo "✅ Vector config существует"
else
  echo "❌ Vector config отсутствует"
fi

echo -e "\nПроверка сертификата для домена:"
curl -s -I https://n8n.${DOMAIN_NAME} | head -1 || echo "❌ Сертификат не доступен"