#!/bin/bash
#
# hf.lib.sh - Shared library for HyperFleet scripts
# Source this file in your hf.* scripts:
#   source "$(dirname "$(realpath "$0")")/hf.lib.sh"
#

# ============================================================================
# Configuration
# ============================================================================

HF_CONFIG_DIR="${HF_CONFIG_DIR:-$HOME/.config/hf}"

# Ensure config directory exists
mkdir -p "$HF_CONFIG_DIR"

# Helper to load value from file if env var is not set
_hf_load() {
  local var="$1" file="$2" default="${3:-}"
  if [[ -z "${!var:-}" ]]; then
    if [[ -f "$file" ]]; then
      printf -v "$var" '%s' "$(cat "$file")"
    else
      printf -v "$var" '%s' "$default"
    fi
  fi
}

# Config file paths
HF_API_URL_FILE="$HF_CONFIG_DIR/api-url"
HF_API_VERSION_FILE="$HF_CONFIG_DIR/api-version"
HF_TOKEN_FILE="$HF_CONFIG_DIR/token"
HF_CONTEXT_FILE="$HF_CONFIG_DIR/context"
HF_NAMESPACE_FILE="$HF_CONFIG_DIR/namespace"
HF_GCP_PROJECT_FILE="$HF_CONFIG_DIR/gcp-project"
HF_CLUSTER_ID_FILE="$HF_CONFIG_DIR/cluster-id"
HF_CLUSTER_NAME_FILE="$HF_CONFIG_DIR/cluster-name"
HF_DB_HOST_FILE="$HF_CONFIG_DIR/db-host"
HF_DB_PORT_FILE="$HF_CONFIG_DIR/db-port"
HF_DB_NAME_FILE="$HF_CONFIG_DIR/db-name"
HF_DB_USER_FILE="$HF_CONFIG_DIR/db-user"
HF_DB_PASSWORD_FILE="$HF_CONFIG_DIR/db-password"
HF_PF_API_PORT_FILE="$HF_CONFIG_DIR/pf-api-port"
HF_PF_PG_PORT_FILE="$HF_CONFIG_DIR/pf-pg-port"
HF_RABBITMQ_HOST_FILE="$HF_CONFIG_DIR/rabbitmq-host"
HF_RABBITMQ_MGMT_PORT_FILE="$HF_CONFIG_DIR/rabbitmq-mgmt-port"
HF_RABBITMQ_USER_FILE="$HF_CONFIG_DIR/rabbitmq-user"
HF_RABBITMQ_PASSWORD_FILE="$HF_CONFIG_DIR/rabbitmq-password"
HF_RABBITMQ_VHOST_FILE="$HF_CONFIG_DIR/rabbitmq-vhost"
HF_REGISTRY_FILE="$HF_CONFIG_DIR/registry"

# Load config from files (env vars take precedence)
_hf_load HF_API_URL "$HF_API_URL_FILE" "http://localhost:8000"
_hf_load HF_API_VERSION "$HF_API_VERSION_FILE" "v1"
_hf_load HF_TOKEN "$HF_TOKEN_FILE" ""
_hf_load HF_KUBE_CONTEXT "$HF_CONTEXT_FILE" ""
_hf_load HF_KUBE_NAMESPACE "$HF_NAMESPACE_FILE" ""
_hf_load HF_GCP_PROJECT "$HF_GCP_PROJECT_FILE" "hcm-hyperfleet"
_hf_load HF_DB_HOST "$HF_DB_HOST_FILE" "localhost"
_hf_load HF_DB_PORT "$HF_DB_PORT_FILE" "5432"
_hf_load HF_DB_NAME "$HF_DB_NAME_FILE" ""
_hf_load HF_DB_USER "$HF_DB_USER_FILE" ""
_hf_load HF_DB_PASSWORD "$HF_DB_PASSWORD_FILE" ""
_hf_load HF_PF_API_PORT "$HF_PF_API_PORT_FILE" "8000"
_hf_load HF_PF_PG_PORT "$HF_PF_PG_PORT_FILE" "5432"
_hf_load HF_RABBITMQ_HOST "$HF_RABBITMQ_HOST_FILE" "localhost"
_hf_load HF_RABBITMQ_MGMT_PORT "$HF_RABBITMQ_MGMT_PORT_FILE" "15672"
_hf_load HF_RABBITMQ_USER "$HF_RABBITMQ_USER_FILE" "guest"
_hf_load HF_RABBITMQ_PASSWORD "$HF_RABBITMQ_PASSWORD_FILE" "guest"
_hf_load HF_RABBITMQ_VHOST "$HF_RABBITMQ_VHOST_FILE" "/"
_hf_load HF_REGISTRY "$HF_REGISTRY_FILE" "$USER"

# ============================================================================
# Colors
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ============================================================================
# Logging
# ============================================================================

hf_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
hf_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
hf_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
hf_debug() { [[ -n "${HF_DEBUG:-}" ]] && echo -e "${CYAN}[DEBUG]${NC} $1"; }

hf_die() {
  hf_error "$1"
  exit 1
}

# ============================================================================
# Cluster ID Management
# ============================================================================

# Get cluster ID from argument, file, or fail
hf_cluster_id() {
  local id="${1:-}"
  if [[ -n "$id" ]]; then
    echo "$id"
  elif [[ -f "$HF_CLUSTER_ID_FILE" ]]; then
    cat "$HF_CLUSTER_ID_FILE"
  else
    hf_die "No cluster ID specified and none saved. Use hf.cluster.search.sh to set one."
  fi
}

# Save cluster ID to file
hf_set_cluster_id() {
  echo "$1" >"$HF_CLUSTER_ID_FILE"
  hf_info "Current cluster set to: $1"
}

# Get cluster name from argument or file
hf_cluster_name() {
  local name="${1:-}"
  if [[ -n "$name" ]]; then
    echo "$name"
  elif [[ -f "$HF_CLUSTER_NAME_FILE" ]]; then
    cat "$HF_CLUSTER_NAME_FILE"
  else
    hf_die "No cluster name specified and none saved."
  fi
}

# Save cluster name to file
hf_set_cluster_name() {
  echo "$1" >"$HF_CLUSTER_NAME_FILE"
  hf_debug "Cluster name saved: $1"
}

# ============================================================================
# NodePool ID & Name Management
# ============================================================================

HF_NODEPOOL_ID_FILE="$HF_CONFIG_DIR/nodepool-id"
HF_NODEPOOL_NAME_FILE="$HF_CONFIG_DIR/nodepool-name"

# Get nodepool ID from argument, file, or fail
hf_nodepool_id() {
  local id="${1:-}"
  if [[ -n "$id" ]]; then
    echo "$id"
  elif [[ -f "$HF_NODEPOOL_ID_FILE" ]]; then
    cat "$HF_NODEPOOL_ID_FILE"
  else
    hf_die "No nodepool ID specified and none saved. Use hf.nodepool.list.sh to find one."
  fi
}

# Save nodepool ID to file
hf_set_nodepool_id() {
  echo "$1" >"$HF_NODEPOOL_ID_FILE"
  hf_info "Current nodepool set to: $1"
}

# Get nodepool name from argument or file
hf_nodepool_name() {
  local name="${1:-}"
  if [[ -n "$name" ]]; then
    echo "$name"
  elif [[ -f "$HF_NODEPOOL_NAME_FILE" ]]; then
    cat "$HF_NODEPOOL_NAME_FILE"
  else
    hf_die "No nodepool name specified and none saved."
  fi
}

# Save nodepool name to file
hf_set_nodepool_name() {
  echo "$1" >"$HF_NODEPOOL_NAME_FILE"
  hf_debug "Nodepool name saved: $1"
}

# ============================================================================
# Config Setters
# ============================================================================

# Generic setter: saves value to file and updates variable
_hf_set() {
  local var="$1" file="$2" value="$3" label="$4"
  echo "$value" >"$file"
  printf -v "$var" '%s' "$value"
  hf_info "$label set to: $value"
}

# Generic clear: removes file and clears variable
_hf_clear() {
  local var="$1" file="$2" label="$3"
  rm -f "$file"
  printf -v "$var" '%s' ""
  hf_info "$label cleared"
}

hf_set_context() { _hf_set HF_KUBE_CONTEXT "$HF_CONTEXT_FILE" "$1" "Context"; }
hf_set_namespace() { _hf_set HF_KUBE_NAMESPACE "$HF_NAMESPACE_FILE" "$1" "Namespace"; }
hf_set_api_url() { _hf_set HF_API_URL "$HF_API_URL_FILE" "$1" "API URL"; }
hf_set_api_version() { _hf_set HF_API_VERSION "$HF_API_VERSION_FILE" "$1" "API version"; }
hf_set_token() { _hf_set HF_TOKEN "$HF_TOKEN_FILE" "$1" "Token"; }
hf_set_gcp_project() { _hf_set HF_GCP_PROJECT "$HF_GCP_PROJECT_FILE" "$1" "GCP project"; }
hf_set_db_host() { _hf_set HF_DB_HOST "$HF_DB_HOST_FILE" "$1" "DB host"; }
hf_set_db_port() { _hf_set HF_DB_PORT "$HF_DB_PORT_FILE" "$1" "DB port"; }
hf_set_db_name() { _hf_set HF_DB_NAME "$HF_DB_NAME_FILE" "$1" "DB name"; }
hf_set_db_user() { _hf_set HF_DB_USER "$HF_DB_USER_FILE" "$1" "DB user"; }
hf_set_db_password() { _hf_set HF_DB_PASSWORD "$HF_DB_PASSWORD_FILE" "$1" "DB password"; }
hf_set_pf_api_port() { _hf_set HF_PF_API_PORT "$HF_PF_API_PORT_FILE" "$1" "Port-forward API port"; }
hf_set_pf_pg_port() { _hf_set HF_PF_PG_PORT "$HF_PF_PG_PORT_FILE" "$1" "Port-forward PG port"; }
hf_set_registry() { _hf_set HF_REGISTRY "$HF_REGISTRY_FILE" "$1" "Registry"; }

hf_clear_context() { _hf_clear HF_KUBE_CONTEXT "$HF_CONTEXT_FILE" "Context"; }
hf_clear_namespace() { _hf_clear HF_KUBE_NAMESPACE "$HF_NAMESPACE_FILE" "Namespace"; }

# ============================================================================
# API Helpers
# ============================================================================

# Get API base URL
hf_api_base() {
  echo "${HF_API_URL}/api/hyperfleet/${HF_API_VERSION}"
}

# Make an API request
# Usage: hf_api GET /clusters
#        hf_api POST /clusters "$json_payload"
hf_api() {
  local method="$1"
  local endpoint="$2"
  local data="${3:-}"

  local url="$(hf_api_base)${endpoint}"
  local curl_args=(
    -X "$method"
    --http1.1
    -s
    -H 'Accept: application/json'
  )

  if [[ -n "$HF_TOKEN" ]]; then
    curl_args+=(-H "Authorization: Bearer $HF_TOKEN")
  fi

  if [[ -n "$data" ]]; then
    curl_args+=(-H 'Content-Type: application/json')
    curl_args+=(-d "$data")
  fi

  hf_debug "API: $method $url"
  curl "${curl_args[@]}" "$url"
}

# Shorthand for common API methods
hf_get() { hf_api GET "$1"; }
hf_post() { hf_api POST "$1" "$2"; }
hf_patch() { hf_api PATCH "$1" "$2"; }
hf_delete() { hf_api DELETE "$1"; }

# ============================================================================
# Requirement Checks
# ============================================================================

hf_require_jq() {
  command -v jq &>/dev/null || hf_die "jq is required but not installed"
}

hf_require_kubectl() {
  command -v kubectl &>/dev/null || hf_die "kubectl is required but not installed"
}

hf_require_gcloud() {
  command -v gcloud &>/dev/null || hf_die "gcloud is required but not installed"
}

hf_require_viddy() {
  command -v viddy &>/dev/null || hf_die "viddy is required for watch mode but not installed"
}

hf_require_psql() {
  command -v psql &>/dev/null || hf_die "psql (PostgreSQL client) is required but not installed"
}


# ============================================================================
# Kubernetes Helpers
# ============================================================================

# Get kubectl with context if set
hf_kubectl() {
  if [[ -n "$HF_KUBE_CONTEXT" ]]; then
    kubectl --context="$HF_KUBE_CONTEXT" "$@"
  else
    kubectl "$@"
  fi
}

# Get kubectl with context and namespace if set
hf_kubectl_ns() {
  if [[ -n "$HF_KUBE_CONTEXT" ]] && [[ -n "$HF_KUBE_NAMESPACE" ]]; then
    kubectl --context="$HF_KUBE_CONTEXT" -n "$HF_KUBE_NAMESPACE" "$@"
  elif [[ -n "$HF_KUBE_NAMESPACE" ]]; then
    kubectl -n "$HF_KUBE_NAMESPACE" "$@"
  else
    kubectl "$@"
  fi
}

# Find postgres pod
hf_find_postgres_pod() {
  hf_require_kubectl
  [[ -z "$HF_KUBE_CONTEXT" ]] && hf_die "HF_KUBE_CONTEXT not set"
  [[ -z "$HF_KUBE_NAMESPACE" ]] && hf_die "HF_KUBE_NAMESPACE not set"

  local pod
  pod=$(hf_kubectl_ns get pods -o name 2>/dev/null | grep -i postgres | head -1 | sed 's|pod/||')
  [[ -z "$pod" ]] && hf_die "Could not find postgres pod in namespace $HF_KUBE_NAMESPACE"
  echo "$pod"
}

# ============================================================================
# Config Property Registry
# ============================================================================
#
# Single source of truth for all config properties.
# Format: "section|key|default|flags"
#   section  — grouping for display
#   key      — config key (maps to file $HF_CONFIG_DIR/<key>)
#   default  — default value (empty if none)
#   flags    — "s" = sensitive (masked in output)
#
# To add a property: add one line here + a HF_*_FILE + _hf_load above.

HF_CONFIG_REGISTRY=(
  "hyperfleet|api-url|http://localhost:8000"
  "hyperfleet|api-version|v1"
  "hyperfleet|token||s"
  "hyperfleet|context"
  "hyperfleet|namespace"
  "hyperfleet|gcp-project|hcm-hyperfleet"
  "hyperfleet|cluster-id"
  "hyperfleet|cluster-name"
  "hyperfleet|nodepool-id"
  "portforward|pf-api-port|8000"
  "portforward|pf-pg-port|5432"
  "database|db-host|localhost"
  "database|db-port|5432"
  "database|db-name|hyperfleet"
  "database|db-user|hyperfleet"
  "database|db-password|foobar-bizz-buzz|s"
  "rabbitmq|rabbitmq-host|localhost"
  "rabbitmq|rabbitmq-mgmt-port|15672"
  "rabbitmq|rabbitmq-user|guest"
  "rabbitmq|rabbitmq-password|guest|s"
  "rabbitmq|rabbitmq-vhost|/"
  "registry|registry|$USER"
)

# Parse a registry entry into _HF_E_* variables (no subshells)
_hf_parse() {
  local IFS='|'
  # shellcheck disable=SC2034
  read -r _HF_E_SECTION _HF_E_KEY _HF_E_DEFAULT _HF_E_FLAGS <<<"$1"
}

# Convenience accessors (use after _hf_parse, or accept entry as arg)
hf_prop_section() {
  _hf_parse "$1"
  echo "$_HF_E_SECTION"
}
hf_prop_key() {
  _hf_parse "$1"
  echo "$_HF_E_KEY"
}
hf_prop_default() {
  _hf_parse "$1"
  echo "$_HF_E_DEFAULT"
}
hf_prop_flags() {
  _hf_parse "$1"
  echo "$_HF_E_FLAGS"
}
hf_prop_is_sensitive() {
  _hf_parse "$1"
  [[ "$_HF_E_FLAGS" == *s* ]]
}

# Get all registered keys as a flat list
hf_config_keys() {
  for entry in "${HF_CONFIG_REGISTRY[@]}"; do
    _hf_parse "$entry"
    echo "$_HF_E_KEY"
  done
}

# Check if a key exists in the registry
hf_config_has_key() {
  local key="$1"
  for entry in "${HF_CONFIG_REGISTRY[@]}"; do
    _hf_parse "$entry"
    [[ "$_HF_E_KEY" == "$key" ]] && return 0
  done
  return 1
}

# Get registry entry by key
hf_config_entry() {
  local key="$1"
  for entry in "${HF_CONFIG_REGISTRY[@]}"; do
    _hf_parse "$entry"
    [[ "$_HF_E_KEY" == "$key" ]] && echo "$entry" && return 0
  done
  return 1
}

# Get the current value of a config key from its file, falling back to default
hf_config_value() {
  local file="$HF_CONFIG_DIR/$1"
  if [[ -f "$file" ]]; then
    cat "$file"
  else
    for entry in "${HF_CONFIG_REGISTRY[@]}"; do
      _hf_parse "$entry"
      if [[ "$_HF_E_KEY" == "$1" ]]; then
        echo "$_HF_E_DEFAULT"
        return 0
      fi
    done
  fi
}

# Generic set by key name
hf_config_set() {
  local key="$1" value="$2"
  hf_config_has_key "$key" || hf_die "Unknown config key: $key"
  echo "$value" >"$HF_CONFIG_DIR/$key"
  hf_info "$key set to: $value"
}

# Generic clear by key name
hf_config_clear() {
  local key="$1"
  hf_config_has_key "$key" || hf_die "Unknown config key: $key"
  rm -f "$HF_CONFIG_DIR/$key"
  hf_info "$key cleared"
}

# ============================================================================
# Config Requirement Declarations
# ============================================================================

# Declare and validate that a script requires specific config properties.
# Usage: hf_require_config api-url cluster-id
# Dies with a clear message if any required property has no value.
hf_require_config() {
  local missing=()
  for key in "$@"; do
    local value
    value=$(hf_config_value "$key")
    if [[ -z "$value" ]]; then
      missing+=("$key")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    hf_die "Missing required config: ${missing[*]}. Run: hf.config.sh set <key> <value>"
  fi
}

# ============================================================================
# Script Info
# ============================================================================

# Print script usage header
hf_usage() {
  local script_name
  script_name=$(basename "$0")
  echo -e "${BOLD}Usage:${NC} $script_name $1"
  echo ""
}
