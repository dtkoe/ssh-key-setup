#!/usr/bin/env bash
set -euo pipefail

PUBKEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIShyODyguzrHt3VvRfXZ+lou2Vc2LON4GswVNfWqAVG'

info() { printf "\033[1;32m[OK]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[ERR]\033[0m %s\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

require_root() {
  [[ ${EUID:-0} -eq 0 ]] || die "Нужно запускать от root."
}

pkg_install() {
  local pkg="$1"
  if command -v apt-get >/dev/null 2>&1; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" >/dev/null
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y "$pkg" >/dev/null
  elif command -v yum >/dev/null 2>&1; then
    yum install -y "$pkg" >/dev/null
  else
    die "Не удалось определить пакетный менеджер для установки ${pkg}."
  fi
}

APT_UPDATE_PID=""
start_apt_update_bg() {
  if command -v apt-get >/dev/null 2>&1; then
    info "Запускаем apt-get update в фоне..."
    DEBIAN_FRONTEND=noninteractive apt-get update -y >/tmp/apt-update.log 2>&1 &
    APT_UPDATE_PID=$!
  fi
}

wait_apt_update() {
  [[ -z "$APT_UPDATE_PID" ]] && return
  if wait "$APT_UPDATE_PID"; then
    info "apt-get update завершён."
  else
    warn "apt-get update завершился с ошибкой (см. /tmp/apt-update.log)."
  fi
}

setup_ssh_key() {
  local sshdir="/root/.ssh"
  local auth="$sshdir/authorized_keys"

  mkdir -p "$sshdir"
  chmod 700 "$sshdir"
  touch "$auth"
  chmod 600 "$auth"

  if grep -qxF "$PUBKEY" "$auth"; then
    info "Ключ уже добавлен для root."
  else
    echo "$PUBKEY" >> "$auth"
    info "SSH-ключ добавлен для root."
  fi
}

ensure_sudo() {
  if command -v sudo >/dev/null 2>&1; then
    info "sudo уже установлен."
  else
    info "sudo отсутствует — устанавливаем."
    pkg_install sudo
    info "sudo установлен."
  fi
}

main() {
  require_root
  start_apt_update_bg
  setup_ssh_key
  wait_apt_update
  ensure_sudo
  info "Готово."
}

main "$@"
