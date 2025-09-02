#!/bin/bash
# =============================================================================
# INSTALL PRE-COMMIT CLEANUP HOOK
# =============================================================================
# Установка автоматической проверки перед коммитом

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }

echo "🛠️ Установка pre-commit cleanup hook..."

# Создаем резервную копию существующего hook
if [[ -f "$PROJECT_ROOT/.git/hooks/pre-commit" ]]; then
    cp "$PROJECT_ROOT/.git/hooks/pre-commit" "$PROJECT_ROOT/.git/hooks/pre-commit.backup"
    print_info "Создана резервная копия: .git/hooks/pre-commit.backup"
fi

# Создаем новый pre-commit hook
cat > "$PROJECT_ROOT/.git/hooks/pre-commit" << 'EOF'
#!/bin/bash
# =============================================================================
# COMBINED PRE-COMMIT HOOK
# =============================================================================
# Сначала запускаем проверку на мусорные файлы
# Затем запускаем стандартные pre-commit проверки

echo "🔍 Запуск pre-commit cleanup проверки..."

# Проверка на файлы только для разработки
if [[ -f "./scripts/pre-commit-check.sh" ]]; then
    ./scripts/pre-commit-check.sh --auto
    cleanup_exit_code=$?

    if [[ $cleanup_exit_code -ne 0 ]]; then
        echo ""
        echo "❌ Cleanup проверка не пройдена!"
        echo "   Запустите: ./scripts/pre-commit-check.sh для исправления"
        echo "   Или используйте: git commit --no-verify для принудительного коммита"
        exit 1
    fi

    echo "✅ Cleanup проверка пройдена!"
else
    echo "⚠️ Скрипт cleanup не найден, пропускаем проверку"
fi

# Запуск стандартного pre-commit (если есть)
if [[ -f ".git/hooks/pre-commit.backup" ]]; then
    echo "🔧 Запуск стандартных pre-commit проверок..."
    .git/hooks/pre-commit.backup "$@"
    standard_exit_code=$?

    if [[ $standard_exit_code -ne 0 ]]; then
        echo "❌ Стандартные pre-commit проверки не пройдены!"
        exit $standard_exit_code
    fi

    echo "✅ Стандартные проверки пройдены!"
fi

echo "🎉 Все pre-commit проверки успешно завершены!"
exit 0
EOF

# Делаем hook исполняемым
chmod +x "$PROJECT_ROOT/.git/hooks/pre-commit"

print_success "Pre-commit hook установлен!"
print_info "Теперь при каждом коммите будет автоматически проверяться:"
echo "  • Файлы только для разработки"
echo "  • Чувствительные данные"
echo "  • Содержимое файлов"
echo "  • Обновление .gitignore"

echo ""
print_info "Для тестирования запустите:"
echo "  ./scripts/pre-commit-check.sh"

echo ""
print_info "Для отключения hook временно используйте:"
echo "  git commit --no-verify"
