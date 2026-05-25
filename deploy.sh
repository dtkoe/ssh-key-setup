#!/usr/bin/env bash
set -euo pipefail

SERVERS_FILE="${SERVERS_FILE:-servers.txt}"
PARALLEL="${PARALLEL:-4}"
SCRIPT_URL="${SCRIPT_URL:-https://raw.githubusercontent.com/dtkoe/ssh-key-setup/main/add_ssh_key.sh}"
LOG_DIR="${LOG_DIR:-./deploy_logs}"

info() { printf "\033[1;32m[OK]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[ERR]\033[0m %s\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

usage() {
  cat <<EOF
Массовый bootstrap серверов: заливает SSH-ключ и базовые пакеты.

Использование:
  $0 [servers.txt]

Переменные окружения:
  SERVERS_FILE  файл со списком серверов (по умолчанию: servers.txt)
  PARALLEL      число параллельных подключений (по умолчанию: 4)
  SCRIPT_URL    URL bootstrap-скрипта (по умолчанию: GitHub raw)
  LOG_DIR       каталог логов (по умолчанию: ./deploy_logs)

Формат servers.txt (разделители — пробелы, # — комментарий):
  host user password [port]
EOF
  exit 0
}

[[ "${1:-}" =~ ^(-h|--help)$ ]] && usage
[[ -n "${1:-}" ]] && SERVERS_FILE="$1"

command -v sshpass >/dev/null 2>&1 || die "sshpass не установлен. apt install sshpass / brew install hudochenkov/sshpass/sshpass"
command -v ssh >/dev/null 2>&1 || die "ssh не установлен."
[[ -f "$SERVERS_FILE" ]] || die "Файл $SERVERS_FILE не найден."

mkdir -p "$LOG_DIR"

OK_FILE="$(mktemp)"
FAIL_FILE="$(mktemp)"
trap 'rm -f "$OK_FILE" "$FAIL_FILE"' EXIT

deploy_one() {
  local host="$1" user="$2" password="$3" port="${4:-22}"
  local log="$LOG_DIR/${host}.log"

  if SSHPASS="$password" sshpass -e ssh \
       -o StrictHostKeyChecking=no \
       -o UserKnownHostsFile=/dev/null \
       -o ConnectTimeout=15 \
       -o PreferredAuthentications=password \
       -o PubkeyAuthentication=no \
       -p "$port" \
       "$user@$host" \
       "bash -c \"\$(curl -fsSL $SCRIPT_URL)\"" \
       >"$log" 2>&1; then
    info "$host — успешно"
    echo "$host" >> "$OK_FILE"
  else
    err "$host — ошибка (см. $log)"
    echo "$host" >> "$FAIL_FILE"
  fi
}

JOBS=0
TOTAL=0
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%%#*}"
  line="${line#"${line%%[![:space:]]*}"}"
  [[ -z "$line" ]] && continue

  read -r host user password port _ <<< "$line"
  [[ -z "${host:-}" || -z "${user:-}" || -z "${password:-}" ]] && { warn "Пропущена некорректная строка: $line"; continue; }

  TOTAL=$((TOTAL+1))
  deploy_one "$host" "$user" "$password" "${port:-22}" &
  JOBS=$((JOBS+1))

  if (( JOBS >= PARALLEL )); then
    wait -n
    JOBS=$((JOBS-1))
  fi
done < "$SERVERS_FILE"

wait

OK_COUNT=$(wc -l < "$OK_FILE" 2>/dev/null | tr -d ' ' || echo 0)
FAIL_COUNT=$(wc -l < "$FAIL_FILE" 2>/dev/null | tr -d ' ' || echo 0)

echo
echo "===== Сводка ====="
echo "Всего:    $TOTAL"
echo "Успешно:  $OK_COUNT"
echo "Ошибок:   $FAIL_COUNT"
if (( FAIL_COUNT > 0 )); then
  echo
  echo "Серверы с ошибками:"
  sed 's/^/  - /' "$FAIL_FILE"
  exit 1
fi
