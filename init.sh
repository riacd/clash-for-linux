#!/bin/bash

# Clash shell helpers (portable version)
# Intended to be sourced from ~/.bashrc

CLASH_PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CLASH_PROJECT_DIR

_clash_is_running() {
  pgrep -f "clash-linux" > /dev/null 2>&1
}

_clash_port_listening() {
  local port="$1"
  ss -lntp 2>/dev/null | grep -q ":${port}"
}

proxy_on() {
  export http_proxy="http://127.0.0.1:7893"
  export https_proxy="http://127.0.0.1:7893"
  export no_proxy="127.0.0.1,localhost"
  export HTTP_PROXY="http://127.0.0.1:7893"
  export HTTPS_PROXY="http://127.0.0.1:7893"
  export NO_PROXY="127.0.0.1,localhost"
  echo "[OK] Proxy enabled (mixed-port 7893)"
}

proxy_off() {
  unset http_proxy
  unset https_proxy
  unset no_proxy
  unset HTTP_PROXY
  unset HTTPS_PROXY
  unset NO_PROXY
  echo "[OK] Proxy disabled"
}

clash_status() {
  if _clash_is_running; then
    echo "[OK] Clash is running"
    ss -lntp 2>/dev/null | grep -E '7893|9091' | head -4
  else
    echo "[WARN] Clash is not running"
    echo "Run: clash_start"
  fi
}

_clash_update_env_url() {
  local new_url="$1"
  local env_file="${CLASH_PROJECT_DIR}/.env"

  if [[ ! -f "${env_file}" ]]; then
    {
      echo "CLASH_URL=\"${new_url}\""
      echo "CLASH_SECRET=\"\""
    } > "${env_file}"
    return 0
  fi

  if grep -q '^CLASH_URL=' "${env_file}"; then
    sed -i "s|^CLASH_URL=.*|CLASH_URL=\"${new_url}\"|" "${env_file}"
  else
    echo "CLASH_URL=\"${new_url}\"" >> "${env_file}"
  fi

  if ! grep -q '^CLASH_SECRET=' "${env_file}"; then
    echo "CLASH_SECRET=\"\"" >> "${env_file}"
  fi
}

clash_start() {
  local new_url="${1:-}"

  if [[ -n "${new_url}" ]]; then
    _clash_update_env_url "${new_url}"
    echo "[OK] Updated CLASH_URL in ${CLASH_PROJECT_DIR}/.env"
  fi

  (cd "${CLASH_PROJECT_DIR}" && bash start.sh)
  local rc=$?

  if [[ ${rc} -eq 0 ]]; then
    sleep 1
    proxy_on
    echo "[OK] Clash started"
  else
    echo "[ERR] Failed to start Clash"
  fi

  return ${rc}
}

clash_restart() {
  (cd "${CLASH_PROJECT_DIR}" && bash restart.sh)
  local rc=$?
  if [[ ${rc} -eq 0 ]]; then
    sleep 1
    proxy_on
    echo "[OK] Clash restarted"
  else
    echo "[ERR] Failed to restart Clash"
  fi
  return ${rc}
}

clash_stop() {
  (cd "${CLASH_PROJECT_DIR}" && bash shutdown.sh)
  local rc=$?
  proxy_off > /dev/null 2>&1
  if [[ ${rc} -eq 0 ]]; then
    echo "[OK] Clash stopped"
  else
    echo "[WARN] stop script returned non-zero, please check logs"
  fi
  return ${rc}
}

clash_test() {
  echo "[INFO] Testing proxy..."
  if curl -s --connect-timeout 5 -x http://127.0.0.1:7893 http://httpbin.org/ip | grep -q "origin"; then
    echo "[OK] Proxy works"
    curl -s -x http://127.0.0.1:7893 http://httpbin.org/ip
  else
    echo "[ERR] Proxy test failed"
    return 1
  fi
}

claude_test() {
  timeout 15 curl -sS -I -x http://127.0.0.1:7893 https://claude.ai/ | head -n 5
}

clash_auto_proxy() {
  if _clash_is_running && _clash_port_listening 7893; then
    if [[ -z "${http_proxy}" ]]; then
      proxy_on > /dev/null 2>&1
      echo "[INFO] Clash detected, proxy auto-enabled"
    fi
    return 0
  fi

  if [[ "${CLASH_AUTO_START:-1}" != "1" ]]; then
    return 0
  fi

  echo "[INFO] Clash not running, auto-starting..."
  if [[ -f "${CLASH_PROJECT_DIR}/auto-start-clash.sh" ]]; then
    bash "${CLASH_PROJECT_DIR}/auto-start-clash.sh"
  else
    (cd "${CLASH_PROJECT_DIR}" && bash start.sh)
  fi

  if _clash_is_running && _clash_port_listening 7893; then
    proxy_on > /dev/null 2>&1
    echo "[OK] Clash auto-started, proxy enabled"
  else
    echo "[WARN] Auto-start failed, run: clash_start"
  fi
}

clash_help() {
  cat << 'EOF'
Available commands:
  clash_start [SUB_URL]  Start Clash, optionally update CLASH_URL
  clash_restart          Restart Clash
  clash_stop             Stop Clash
  clash_status           Show process/port status
  clash_test             Test proxy connectivity
  claude_test            Quick Claude connectivity test
  proxy_on / proxy_off   Toggle shell proxy env vars
EOF
}

# Backward-compatible aliases
check_clash() { clash_status; }
start_clash() { clash_start "$@"; }
test_proxy() { clash_test; }

alias clash-start='clash_start'
alias clash-status='clash_status'
alias clash-stop='clash_stop'
alias clash-test='clash_test'
alias claude-test='claude_test'

# Auto-run only in interactive shells (typical ~/.bashrc usage)
if [[ $- == *i* ]]; then
  clash_auto_proxy
fi
