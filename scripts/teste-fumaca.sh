#!/usr/bin/env bash
# Teste rápido depois de subir a stack. Uso: ./scripts/teste-fumaca.sh
set -euo pipefail
raiz="$(cd "$(dirname "$0")/.." && pwd)"
CHAVE="$(grep -E '^AGENTES_API_KEY=' "$raiz/.env" | cut -d= -f2-)"
BASE="http://localhost:8000"

echo "1) Saúde";          curl -s "$BASE/saude"; echo
echo "2) Modelos";        curl -s -H "Authorization: Bearer $CHAVE" "$BASE/v1/models"; echo
echo "3) Pedido real (pode levar alguns minutos)"
curl -s --max-time 900 -H "Authorization: Bearer $CHAVE" -H "Content-Type: application/json" \
  "$BASE/v1/chat/completions" -d '{
    "model": "stevelab-agentes", "stream": false,
    "messages": [{"role": "user", "content": "Descreva a planilha exemplo_chamados.csv e diga qual setor tem o maior tempo médio de resolução. Cite a fonte."}]
  }' | python3 -c 'import json,sys; print(json.load(sys.stdin)["choices"][0]["message"]["content"])'
