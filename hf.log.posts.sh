#!/bin/bash
# Extract adapter POST statuses from adapter pod logs
# Usage: hf.log.posts.sh [filter_string]
source "$(dirname "$(realpath "$0")")/hf.lib.sh"
hf_require_config context namespace cluster-id
hf_require_jq
hf_require_kubectl

FILTER="${1:-$(hf_cluster_id)}"

PODS=$(hf_kubectl_ns get pods -o name 2>/dev/null | grep adapter)
if [[ -z "$PODS" ]]; then
  hf_die "No adapter pods found in namespace $HF_KUBE_NAMESPACE"
fi

hf_info "Filtering logs for: $FILTER"

printf "${BOLD}%-14s %-20s %-3s%-4s%-4s%-4s%s${NC}\n" "TIME" "ADAPTER" "G" "AVL" "APL" "HLT" "FIN"

_dot() {
  case "$1" in
    True)    printf "${GREEN}●${NC}";;
    False)   printf "${RED}●${NC}";;
    Unknown) printf "${YELLOW}●${NC}";;
    *)       printf "-";;
  esac
}

(for pod in $PODS; do
  hf_kubectl_ns logs "$pod" --all-containers 2>/dev/null
done) | grep "$FILTER" | grep 'API call payload: POST' | sort | while IFS= read -r line; do
  # Handle both JSON logs ({"time":"..."}) and key=value logs (time=...)
  if [[ "$line" == "{"* ]]; then
    read -r time_val adapter gen available applied health finalized < <(
      echo "$line" | jq -r '
        (.time | split("T")[1] | rtrimstr("Z") | split(".") | .[0] + "." + (.[1] // "000")[0:3]) as $t |
        (.msg | capture("payload=(?<p>\\{.+\\})") | .p | fromjson) as $payload |
        [$t, $payload.adapter, ($payload.observed_generation | tostring),
         (($payload.conditions // []) | (map({(.type): .status}) | add) | .Available // "-", .Applied // "-", .Health // "-", .Finalized // "-")
        ] | @tsv' 2>/dev/null
    )
  else
    time_val=$(echo "$line" | grep -o 'time=[^ ]*' | head -1 | cut -d= -f2 | cut -dT -f2 | sed 's/Z$//')
    json=$(echo "$line" | sed 's/.*payload=\({.*}\)".*/\1/' | sed 's/\\"/"/g')
    read -r adapter gen available applied health finalized < <(
      echo "$json" | jq -r '[
        .adapter, (.observed_generation | tostring),
        ((.conditions // []) | (map({(.type): .status}) | add) | .Available // "-", .Applied // "-", .Health // "-", .Finalized // "-")
      ] | @tsv' 2>/dev/null
    )
  fi
  [[ -z "$adapter" ]] && continue

  printf "%-14s %-20s %-3s%s   %s   %s   %s\n" "$time_val" "$adapter" "$gen" "$(_dot "$available")" "$(_dot "$applied")" "$(_dot "$health")" "$(_dot "$finalized")"
done
