#!/usr/bin/env bash
set -euo pipefail

# Самодостаточный установщик remnawave-node.
# Запустить на чистом сервере Debian/Ubuntu от root:
#   bash install_remnanode.sh

info() { printf "\033[1;32m[OK]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[ERR]\033[0m %s\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

[[ ${EUID:-0} -eq 0 ]] || die "Нужно запускать от root."

# Версии фиксированы под пример-ноду 152.53.105.236 (Debian 13 trixie).
DOCKER_VER="5:29.2.1-1~debian.13~trixie"
CONTAINERD_VER="2.2.1-1~debian.13~trixie"
BUILDX_VER="0.31.1-1~debian.13~trixie"
COMPOSE_VER="5.0.2-1~debian.13~trixie"

install_docker() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    info "Docker уже установлен: $(docker --version), $(docker compose version)"
    return
  fi
  info "Устанавливаю Docker (pinned)..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq ca-certificates curl gnupg
  install -m 0755 -d /etc/apt/keyrings
  . /etc/os-release
  [[ "$VERSION_CODENAME" == "trixie" ]] || warn "Дистрибутив не trixie ($VERSION_CODENAME) — версии могут не совпасть."
  if [[ ! -s /etc/apt/keyrings/docker.asc ]]; then
    curl -fsSL "https://download.docker.com/linux/${ID}/gpg" -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
  fi
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${ID} ${VERSION_CODENAME} stable" > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
  apt-get install -y -qq \
    "docker-ce=${DOCKER_VER}" \
    "docker-ce-cli=${DOCKER_VER}" \
    "containerd.io=${CONTAINERD_VER}" \
    "docker-buildx-plugin=${BUILDX_VER}" \
    "docker-compose-plugin=${COMPOSE_VER}"
  apt-mark hold docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null
  systemctl enable --now docker
  info "Docker: $(docker --version), $(docker compose version)"
}

extract_bundle() {
  info "Распаковываю конфиги в /opt..."
  mkdir -p /opt
  base64 -d <<'BUNDLE_B64' | tar xzf - -C /opt
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
BUNDLE_B64
  info "Конфиги распакованы:"
  ls -la /opt/remnawave-node
}

start_services() {
  info "Запускаю remnawave-node..."
  (cd /opt/remnawave-node && docker compose up -d)
}

main() {
  install_docker
  extract_bundle
  start_services
  sleep 3
  info "Контейнеры:"
  docker ps
  cat <<EOF

✅ Готово.
  • remnawave-node → :2222 (host network)

Если нода должна быть отдельной для панели — поправь SECRET_KEY в /opt/remnawave-node/.env
и перезапусти: cd /opt/remnawave-node && docker compose up -d
EOF
}

main "$@"
