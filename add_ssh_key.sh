#!/usr/bin/env bash
set -euo pipefail

PUBKEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIShyODyguzrHt3VvRfXZ+lou2Vc2LON4GswVNfWqAVG'

info() { printf "\033[1;32m[OK]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[ERR]\033[0m %s\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

HOME_DIR="${HOME:-$(getent passwd "$(id -un)" | cut -d: -f6)}"
[[ -n "$HOME_DIR" && -d "$HOME_DIR" ]] || die "Не удалось определить домашний каталог."

SSH_DIR="$HOME_DIR/.ssh"
AUTH="$SSH_DIR/authorized_keys"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
touch "$AUTH"
chmod 600 "$AUTH"

if grep -qxF "$PUBKEY" "$AUTH"; then
  info "Ключ уже добавлен для пользователя $(id -un)."
else
  echo "$PUBKEY" >> "$AUTH"
  info "SSH-ключ добавлен для пользователя $(id -un)."
fi
