#!/usr/bin/env bash
set -euo pipefail

PUBKEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIShyODyguzrHt3VvRfXZ+lou2Vc2LON4GswVNfWqAVG'

info() { printf "\033[1;32m[OK]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[ERR]\033[0m %s\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

require_root() {
  [[ ${EUID:-0} -eq 0 ]] || die "Нужно запускать от root."
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

main() {
  require_root
  setup_ssh_key
  info "Готово."
}

main "$@"
