#!/usr/bin/env bash
# Gera o .env a partir de um dos modelos, com segredos aleatórios.
# Uso: ./scripts/gerar-env.sh servidor|aluno|local|nativo
set -euo pipefail

perfil="${1:-servidor}"
raiz="$(cd "$(dirname "$0")/.." && pwd)"
origem="$raiz/.env.$perfil.example"
destino="$raiz/.env"

[ -f "$origem" ] || { echo "Perfil inválido: $perfil (use servidor, aluno, local ou nativo)"; exit 1; }
[ -f "$destino" ] && { echo ".env já existe. Apague-o se quiser gerar de novo."; exit 1; }

hex() { openssl rand -hex "$1"; }

while IFS= read -r linha || [ -n "$linha" ]; do
  case "$linha" in *__HEX64__*) linha="${linha//__HEX64__/$(hex 32)}" ;; esac
  case "$linha" in *__HEX32__*) linha="${linha//__HEX32__/$(hex 16)}" ;; esac
  case "$linha" in *__SENHA__*) linha="${linha//__SENHA__/$(hex 16)}" ;; esac
  printf '%s\n' "$linha"
done < "$origem" > "$destino"

chmod 600 "$destino"
echo ".env gerado a partir de .env.$perfil.example — revise os endereços antes de subir."
