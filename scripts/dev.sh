#!/usr/bin/env bash
# Runner de desenvolvimento do projeto Relatorio JRC Brasil.
#
# Sobe o stack completo via Docker Compose (db PostgreSQL + backend Django + frontend React/Vite)
# com um unico comando, espera cada servico ficar pronto e mostra as URLs de acesso.
#
# Uso:
#   scripts/dev.sh            # build + sobe o stack (detached) e segue os logs
#   scripts/dev.sh --no-build # sobe sem reconstruir as imagens (mais rapido)
#   scripts/dev.sh --logs     # apenas segue os logs do stack ja em execucao
#   scripts/dev.sh --down     # para o stack (mantem os dados do banco)
#   scripts/dev.sh --reset    # para o stack e APAGA o volume do banco (down -v)
#   scripts/dev.sh -h         # ajuda
set -euo pipefail

# Raiz do repositorio (este script vive em scripts/).
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT_DIR"

# --- Log colorido (apenas em TTY e sem NO_COLOR) ----------------------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  c_reset='\033[0m'; c_blue='\033[34m'; c_green='\033[32m'; c_yellow='\033[33m'; c_red='\033[31m'
else
  c_reset=''; c_blue=''; c_green=''; c_yellow=''; c_red=''
fi
log()  { printf '%b==>%b %s\n' "$c_blue" "$c_reset" "$*"; }
ok()   { printf '%bOK %b %s\n' "$c_green" "$c_reset" "$*"; }
warn() { printf '%b!! %b %s\n' "$c_yellow" "$c_reset" "$*"; }
die()  { printf '%bERRO%b %s\n' "$c_red" "$c_reset" "$*" >&2; exit 1; }

# --- Pre-requisitos ---------------------------------------------------------
command -v docker >/dev/null 2>&1 || die "Docker nao encontrado no PATH."
docker info >/dev/null 2>&1 || die "Daemon do Docker indisponivel. Inicie o Docker e tente novamente."

# Comando do Compose (plugin v2/v5 'docker compose').
compose() { docker compose "$@"; }

# --- Pre-flight de portas ---------------------------------------------------
# Ha um listener na porta? (cadeia de fallback ss -> lsof -> fuser). 0 = em uso.
port_in_use() {
  local p="$1"
  if command -v ss >/dev/null 2>&1; then ss -ltn 2>/dev/null | grep -q ":$p "
  elif command -v lsof >/dev/null 2>&1; then lsof -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1
  else fuser "$p"/tcp >/dev/null 2>&1
  fi
}

# Avisa se 5432/8000/8080 ja estao tomadas por algo que nao e o nosso stack.
check_ports() {
  # Se o nosso stack ja esta de pe, as portas ocupadas sao nossas — ok.
  # 'compose ps -q' retorna IDs dos containers em execucao (vazio se nenhum).
  local mine; mine="$(compose ps -q 2>/dev/null || true)"
  [ -n "$mine" ] && return 0
  local p
  for p in 5432 8000 8080; do
    port_in_use "$p" && warn "Porta $p ja esta em uso. Se for um stack antigo deste projeto, rode 'scripts/dev.sh --down'; senao libere a porta."
  done
  return 0  # garante saida 0 (senao 'set -e' aborta quando a ultima porta verificada esta livre)
}

# --- .env (com protecao contra CRLF do WSL/Windows, ver pitfall P18) --------
ensure_env() {
  if [ ! -f .env ]; then
    [ -f .env.example ] || die ".env e .env.example ausentes — nao ha como configurar o banco."
    cp .env.example .env
    ok "Criado .env a partir de .env.example."
  fi
  # Remove CR (\r) que o Windows/WSL costuma deixar e que quebra o parsing do Compose.
  if grep -q $'\r' .env 2>/dev/null; then
    sed -i 's/\r$//' .env
    warn "Removido CRLF do .env (normalizado para LF)."
  fi
}

# Le um valor do .env (sem CR) — usado em healthchecks que precisam do usuario do banco.
env_val() { grep -E "^$1=" .env 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\r'; }

# --- Espera ativa por prontidao (sem sleeps cegos) --------------------------
wait_for_db() {
  local user; user="$(env_val POSTGRES_USER)"; local db; db="$(env_val POSTGRES_DB)"
  log "Aguardando PostgreSQL..."
  for _ in $(seq 1 60); do
    if compose exec -T db pg_isready -U "$user" -d "$db" >/dev/null 2>&1; then ok "PostgreSQL pronto."; return 0; fi
    sleep 1
  done
  die "PostgreSQL nao ficou pronto em 60s. Veja: scripts/dev.sh --logs"
}

wait_for_http() {
  local url="$1" name="$2"
  log "Aguardando $name ($url)..."
  for _ in $(seq 1 60); do
    # Sem conexao o curl ja imprime "000" e sai != 0; o '|| true' evita abortar sob set -e.
    local code; code="$(curl -s -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || true)"
    # Qualquer resposta HTTP (inclusive 401/404) significa que o servico esta de pe.
    if [ -n "$code" ] && [ "$code" != "000" ]; then ok "$name respondendo (HTTP $code)."; return 0; fi
    sleep 1
  done
  die "$name nao respondeu em 60s. Veja: scripts/dev.sh --logs"
}

# --- Acoes ------------------------------------------------------------------
usage() {
  cat <<'EOF'
Runner de desenvolvimento do projeto Relatorio JRC Brasil.

Sobe o stack completo via Docker Compose (db PostgreSQL + backend Django + frontend React/Vite)
com um unico comando, espera cada servico ficar pronto e mostra as URLs de acesso.

Uso:
  scripts/dev.sh            # build + sobe o stack (detached) e segue os logs
  scripts/dev.sh --no-build # sobe sem reconstruir as imagens (mais rapido)
  scripts/dev.sh --logs     # apenas segue os logs do stack ja em execucao
  scripts/dev.sh --down     # para o stack (mantem os dados do banco)
  scripts/dev.sh --reset    # para o stack e APAGA o volume do banco (down -v)
  scripts/dev.sh -h         # ajuda
EOF
}

do_down()  { log "Parando o stack..."; compose down; ok "Stack parado (dados do banco preservados)."; }
do_reset() { warn "Apagando containers E o volume do banco..."; compose down -v; ok "Stack e volume removidos."; }
do_logs()  { exec compose logs -f --tail=50; }

do_up() {
  local build="--build"; [ "${NO_BUILD:-0}" = "1" ] && build=""
  ensure_env
  check_ports
  log "Subindo o stack (db + backend + frontend)${build:+ com build}..."
  # shellcheck disable=SC2086
  compose up $build -d
  wait_for_db
  wait_for_http "http://localhost:8000/api/" "Backend Django"
  wait_for_http "http://localhost:8080/"     "Frontend React"
  echo
  ok "Stack no ar:"
  printf "    Frontend : %s\n" "http://localhost:8080"
  printf "    Backend  : %s\n" "http://localhost:8000/api/"
  printf "    Admin    : %s\n" "http://localhost:8000/admin/"
  echo
  log "Seguindo os logs (Ctrl+C apenas desanexa; o stack continua rodando). Para parar: scripts/dev.sh --down"
  exec compose logs -f --tail=20
}

# --- Parsing de argumentos --------------------------------------------------
NO_BUILD=0
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  --down)    do_down; exit 0 ;;
  --reset)   do_reset; exit 0 ;;
  --logs)    do_logs ;;
  --no-build) NO_BUILD=1; do_up ;;
  "")        do_up ;;
  *)         die "Argumento desconhecido: $1 (use -h para ajuda)" ;;
esac
