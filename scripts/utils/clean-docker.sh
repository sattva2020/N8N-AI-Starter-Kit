#!/bin/bash

set -u

FORCE_NETWORKS=false
DRY_RUN=false

while [ "$#" -gt 0 ]; do
	case "$1" in
		--force-networks)
			FORCE_NETWORKS=true
			shift
			;;
		--dry-run)
			DRY_RUN=true
			shift
			;;
		-h|--help)
			echo "Usage: $0 [--force-networks] [--dry-run]"
			echo "  --force-networks   Disconnect containers and remove user networks even if in use"
			echo "  --dry-run          Print actions without executing them"
			exit 0
			;;
		*)
			echo "Unknown option: $1" >&2
			shift
			;;
	esac
done

echo "=============================="
echo "🧹 Начинаем полную очистку Docker..."
echo "Options: FORCE_NETWORKS=${FORCE_NETWORKS}, DRY_RUN=${DRY_RUN}"
echo "=============================="

# helper to run safely
safe_run() {
	if [ "$#" -eq 0 ]; then
		return 0
	fi
	if [ "${DRY_RUN}" = true ]; then
		echo "[dry-run] $*"
		return 0
	fi
	echo "-> $*"
	"$@" || true
}

echo "📋 Состояние перед очисткой:"
echo "- Контейнеры:"
docker ps -a --format "{{.Names}}\t{{.Status}}" || true
echo "- Образы:"
docker images --format "{{.Repository}}:{{.Tag}}\t{{.ID}}" || true
echo "- Тома:"
docker volume ls || true
echo "- Сети:"
docker network ls || true

# Остановить все запущенные контейнеры
echo "\n🛑 Останавливаем все запущенные контейнеры..."
CONTAINERS=$(docker ps -aq)
if [ -n "${CONTAINERS}" ]; then
	safe_run docker stop ${CONTAINERS}
else
	echo "(нет контейнеров для остановки)"
fi

# Удалить все контейнеры
echo "\n🗑️ Удаляем все контейнеры..."
ALL_CONTAINERS=$(docker ps -aq)
if [ -n "${ALL_CONTAINERS}" ]; then
	safe_run docker rm -f ${ALL_CONTAINERS}
else
	echo "(нет контейнеров для удаления)"
fi

# Удалить все сети (кроме системных) — сначала пробуем prune для неиспользуемых
echo "\n🌐 Удаляем все неиспользуемые сети (prune)..."
safe_run docker network prune -f

# Удалить все неизвестные сети (осторожно) — покажем список и удалим по одному
echo "\n🌐 Список пользовательских сетей (будут удалены, если есть):"
USER_NETWORKS=$(docker network ls --format "{{.Name}}" | grep -vE "^(bridge|host|none)" || true)
if [ -n "${USER_NETWORKS}" ]; then
	echo "${USER_NETWORKS}"
	for net in ${USER_NETWORKS}; do
		echo "Обработка сети: ${net}"
		if [ "${FORCE_NETWORKS}" = true ]; then
			echo "Отключаем контейнеры от сети ${net} (force)..."
			# Получить все контейнеры, подключённые к сети
			CNT_LIST=$(docker network inspect -f '{{range $k,$v := .Containers}}{{$k}} {{end}}' "${net}" 2>/dev/null || true)
			if [ -n "${CNT_LIST}" ]; then
				for cid in ${CNT_LIST}; do
					echo "Отключаем контейнер ${cid} от сети ${net}"
					safe_run docker network disconnect -f "${net}" "${cid}"
				done
			else
				echo "(контейнеры не найдены)"
			fi
		fi
		echo "Удаляем сеть: ${net}"
		safe_run docker network rm "${net}"
	done
else
	echo "(нет пользовательских сетей для удаления)"
fi

# Удалить все образы
echo "\n🖼️ Удаляем все образы..."
IMAGES=$(docker images -aq)
if [ -n "${IMAGES}" ]; then
	safe_run docker rmi -f ${IMAGES}
else
	echo "(нет образов для удаления)"
fi

# Удалить все тома (включая занятые) — покажем список и удалим
echo "\n💾 Удаляем все тома..."
VOLUMES=$(docker volume ls -q)
if [ -n "${VOLUMES}" ]; then
	echo "Найденные тома:"
	docker volume ls
	for vol in ${VOLUMES}; do
		echo "Удаляем том: ${vol}"
		safe_run docker volume rm -f "${vol}"
	done
else
	echo "(нет томов для удаления)"
fi

# Очистка неиспользуемых build-кэшей
echo "\n🧽 Очищаем неиспользуемый кэш сборок..."
safe_run docker builder prune -af

echo "\n=============================="
echo "📊 Результат очистки — текущее состояние Docker:"
echo "- Контейнеры (после):"
docker ps -a --format "{{.Names}}\t{{.Status}}" || true
echo "- Образы (после):"
docker images --format "{{.Repository}}:{{.Tag}}\t{{.ID}}" || true
echo "- Тома (после):"
docker volume ls || true
echo "- Сети (после):"
docker network ls || true
echo "=============================="
echo "✅ Очистка Docker завершена!"
echo "=============================="
