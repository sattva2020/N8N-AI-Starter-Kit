#!/usr/bin/env bash
set -euo pipefail

### scripts/check-env-placeholders.sh
# Scans staged and working env files for empty values or obvious placeholders.
# Exits with 1 if suspicious values are found.

PLACEHOLDER_REGEX='change[_-]?|your[_-]?|example(\.|com)|password|admin123|change_me|generate|placeholder|your_openai|your_n8n'

found=0
report=()

# Only inspect files that are staged in this commit
staged_files=$(git diff --cached --name-only --diff-filter=ACMRT || true)
if [ -z "$staged_files" ]; then
  # Nothing staged; nothing to validate
  exit 0
fi

for f in $staged_files; do
  case "$f" in
    .env|.env.example|template.env)
      # Read staged content
      if ! content=$(git show ":$f" 2>/dev/null); then
        # If not staged (shouldn't happen), skip
        continue
      fi
      ;;
    *)
      continue
      ;;
  esac

  while IFS= read -r line || [ -n "$line" ]; do
    # Skip comments and non key= lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    if [[ "$line" =~ ^([A-Za-z0-9_]+)=(.*)$ ]]; then
      key=${BASH_REMATCH[1]}
      val=${BASH_REMATCH[2]}
      # Trim surrounding quotes and whitespace
      # Trim surrounding quotes and whitespace (portable, avoid external sed quoting issues)
      # Trim leading/trailing whitespace
      val="${val#${val%%[![:space:]]*}}"
      val="${val%${val##*[![:space:]]}}"
      # Remove a single surrounding quote (" or ') if present
      first_char="${val:0:1}"
      last_char="${val: -1}"
      if [[ "$first_char" == '"' || "$first_char" == "'" ]]; then
        val="${val:1}"
      fi
      if [[ "$last_char" == '"' || "$last_char" == "'" ]]; then
        val="${val:0:-1}"
      fi

      if [[ -z "${val// }" ]]; then
        report+=("${f}: ${key} -> EMPTY")
        found=1
        continue
      fi

      if echo "$val" | grep -qiE "$PLACEHOLDER_REGEX"; then
        report+=("${f}: ${key} = '${val}' -> PLACEHOLDER")
        found=1
        continue
      fi
    fi
  done <<< "$content"
done

if [ $found -ne 0 ]; then
  echo "\n❌ Обнаружены пустые значения или плейсхолдеры в переменных окружения:" >&2
  for r in "${report[@]}"; do
    echo " - $r" >&2
  done
  echo "\nПожалуйста, замените их на реальные значения или удалите соответствующие строки из коммита." >&2
  exit 1
else
  echo "✅ Проверка env/placeholders: пройдена (не найдено пустых или очевидных плейсхолдеров)."
fi
