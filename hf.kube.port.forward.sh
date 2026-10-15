#!/bin/bash
# Port forward to hyperfleet pods
# Usage: hf.kube.port.forward.sh start|stop|status
source "$(dirname "$(realpath "$0")")/hf.lib.sh"
hf_require_config context namespace pf-api-port pf-pg-port

API_LOCAL_PORT="$HF_PF_API_PORT"
API_REMOTE_PORT="$HF_PF_API_PORT"
PG_LOCAL_PORT="$HF_PF_PG_PORT"
PG_REMOTE_PORT="$HF_PF_PG_PORT"

# Get PID of kubectl port-forward using a specific port
get_port_pid() {
  local port="$1"

  # Try lsof first (works on macOS and some Linux systems)
  if command -v lsof &>/dev/null; then
    lsof -ti ":$port" 2>/dev/null | head -1
  # Fall back to ss (available on most Linux systems)
  elif command -v ss &>/dev/null; then
    ss -tlnp 2>/dev/null | grep -E "[[:space:]]127\.0\.0\.1:${port}[[:space:]]|[[:space:]]\[::\]:${port}[[:space:]]|\[::1\]:${port}[[:space:]]" |
      sed -n 's/.*pid=\([0-9]*\).*/\1/p' | head -1
  else
    hf_die "Neither lsof nor ss command found. Please install one of them."
  fi
}

is_port_in_use() {
  [[ -n "$(get_port_pid "$1")" ]]
}

find_namespace() {
  [[ -z "$HF_KUBE_NAMESPACE" ]] && hf_die "Namespace not configured. Run: hf.config.sh set namespace <name>"
  echo "$HF_KUBE_NAMESPACE"
}

get_pod() {
  local ns="$1" label="$2"
  local pod
  pod=$(hf_kubectl get pods -n "$ns" -l "app=$label" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  [[ -z "$pod" ]] && pod=$(hf_kubectl get pods -n "$ns" --no-headers 2>/dev/null | grep "$label" | head -1 | awk '{print $1}')
  echo "$pod"
}

create_forward() {
  local ns="$1" pod="$2" local_port="$3" remote_port="$4" service="$5"

  [[ -z "$pod" ]] && {
    hf_error "No pod found for $service"
    return 1
  }

  if is_port_in_use "$local_port"; then
    hf_warn "Port $local_port already in use - skipping $service"
    return 0
  fi

  hf_info "Port forwarding $service: localhost:$local_port -> $pod:$remote_port"
  hf_kubectl port-forward -n "$ns" "$pod" "$local_port:$remote_port" &>/dev/null &
  local pid=$!

  sleep 1
  if kill -0 "$pid" 2>/dev/null; then
    hf_info "Established (PID: $pid)"
  else
    hf_error "Failed to create port forward for $service"
    return 1
  fi
}

do_start() {
  hf_require_kubectl

  # Stop any existing forwards first
  if is_port_in_use "$API_LOCAL_PORT" || is_port_in_use "$PG_LOCAL_PORT"; then
    do_stop
    echo ""
  fi

  echo -e "${BOLD}Starting HyperFleet Port Forwards${NC}\n"

  local ns
  ns=$(find_namespace) || exit 1
  hf_info "Using namespace: $ns"

  local api_pod pg_pod
  api_pod=$(get_pod "$ns" "hyperfleet-api")
  pg_pod=$(get_pod "$ns" "postgresql")
  [[ -z "$pg_pod" ]] && pg_pod=$(get_pod "$ns" "postgres")

  # Start all port forwards in parallel
  create_forward "$ns" "$api_pod" "$API_LOCAL_PORT" "$API_REMOTE_PORT" "hyperfleet-api" &
  create_forward "$ns" "$pg_pod" "$PG_LOCAL_PORT" "$PG_REMOTE_PORT" "postgresql" &

  wait

  sleep 1
  echo ""
  do_status
  echo ""
  hf_info "Use 'hf.kube.port.forward.sh stop' to stop."
}

stop_port() {
  local port="$1" service="$2"
  local pid
  pid=$(get_port_pid "$port")
  if [[ -n "$pid" ]]; then
    kill "$pid" 2>/dev/null && hf_info "Stopped $service on port $port (PID: $pid)"
  fi
}

do_stop() {
  echo -e "${BOLD}Stopping Port Forwards${NC}\n"

  local stopped=0
  if is_port_in_use "$API_LOCAL_PORT"; then
    stop_port "$API_LOCAL_PORT" "hyperfleet-api"
    ((stopped++))
  fi
  if is_port_in_use "$PG_LOCAL_PORT"; then
    stop_port "$PG_LOCAL_PORT" "postgresql"
    ((stopped++))
  fi

  [[ "$stopped" -eq 0 ]] && hf_info "No port forwards running"

  echo ""
  do_status
}

show_port_status() {
  local port="$1" service="$2"
  local pid
  pid=$(get_port_pid "$port")
  if [[ -n "$pid" ]]; then
    echo -e "  ${GREEN}●${NC} $service - localhost:$port (PID: $pid)"
    return 0
  else
    echo -e "  ${RED}●${NC} $service - localhost:$port (stopped)"
    return 1
  fi
}

do_status() {
  echo -e "${BOLD}Port Forward Status${NC}\n"

  local any_down=0
  show_port_status "$API_LOCAL_PORT" "hyperfleet-api" || any_down=1
  show_port_status "$PG_LOCAL_PORT" "postgresql" || any_down=1
  return $any_down
}

case "${1:-}" in
start) do_start ;;
stop) do_stop ;;
status)
  if ! do_status; then
    echo ""
    read -r -p "Some port forwards are down. Start all? [Y/n] " reply
    reply="${reply:-Y}"
    if [[ "$reply" =~ ^[Yy]$ ]]; then
      do_start
    fi
  fi
  ;;
"")
  hf_usage "start|stop|status"
  echo "Commands:"
  echo "  start   Start port forwards to hyperfleet pods"
  echo "  stop    Stop all running port forwards"
  echo "  status  Show status of port forwards"
  echo ""
  if ! do_status; then
    echo ""
    read -r -p "Some port forwards are down. Start all? [Y/n] " reply
    reply="${reply:-Y}"
    if [[ "$reply" =~ ^[Yy]$ ]]; then
      do_start
    fi
  fi
  ;;
*)
  hf_usage "start|stop|status"
  echo "Commands:"
  echo "  start   Start port forwards to hyperfleet pods"
  echo "  stop    Stop all running port forwards"
  echo "  status  Show status of port forwards"
  ;;
esac
