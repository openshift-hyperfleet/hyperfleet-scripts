#!/bin/bash
# List all clusters with their nodepools in a combined table
source "$(dirname "$(realpath "$0")")/hf.lib.sh"
hf_require_config api-url api-version

hf_require_jq

GREEN=$(printf '\033[32m')
RED=$(printf '\033[31m')
YELLOW=$(printf '\033[33m')
RESET=$(printf '\033[0m')

CLUSTERS_JSON=$(hf_get "/clusters")

CLUSTER_STATUSES_MAP='{}'
NP_MAP='{}'
NP_STATUSES_MAP='{}'

while IFS= read -r CID; do
  NP_JSON=$(hf_get "/clusters/${CID}/nodepools" 2>/dev/null || echo '{"items":[]}')
  C_STATUSES=$(hf_get "/clusters/${CID}/statuses" 2>/dev/null || echo '{"items":[]}')

  CLUSTER_STATUSES_MAP=$(jq -n \
    --argjson m "$CLUSTER_STATUSES_MAP" --arg id "$CID" --argjson s "$C_STATUSES" \
    '$m + {($id): ($s.items // [])}')

  NP_MAP=$(jq -n \
    --argjson m "$NP_MAP" --arg id "$CID" --argjson np "$NP_JSON" \
    '$m + {($id): ($np.items // [])}')

  while IFS= read -r NPID; do
    NP_STAT=$(hf_get "/clusters/${CID}/nodepools/${NPID}/statuses" 2>/dev/null || echo '{"items":[]}')
    NP_STATUSES_MAP=$(jq -n \
      --argjson m "$NP_STATUSES_MAP" --arg id "$NPID" --argjson s "$NP_STAT" \
      '$m + {($id): ($s.items // [])}')
  done < <(echo "$NP_JSON" | jq -r '(.items // [])[].id')
done < <(echo "$CLUSTERS_JSON" | jq -r '.items[].id')

jq -n -r \
  --argjson clusters "$CLUSTERS_JSON" \
  --argjson cluster_statuses "$CLUSTER_STATUSES_MAP" \
  --argjson np_map "$NP_MAP" \
  --argjson np_statuses "$NP_STATUSES_MAP" \
  --arg green "$GREEN" --arg red "$RED" --arg yellow "$YELLOW" --arg reset "$RESET" '

  def fmt_cond:
    if . == null then "-"
    else
      (.observed_generation | if . != null then tostring else "" end) as $gen |
      if   .status == "True"    then "" + $gen
      elif .status == "False"   then "" + $gen
      elif .status == "Unknown" then "" + $gen
      elif .status == "" or .status == null then "-"
      else .status end
    end;

  def fmt_adapter(ctype):
    if . == null then "-"
    else
      (.observed_generation | if . != null then tostring else "" end) as $gen |
      (.conditions | map(select(.type == ctype)) | .[0].status) as $s |
      if   $s == "True"    then "" + $gen
      elif $s == "False"   then "" + $gen
      elif $s == "Unknown" then "" + $gen
      elif $s == null      then "-"
      else $s end
    end;

  $clusters.items as $citems |

  # Condition types from clusters and nodepools (excluding *Successful)
  ([ $citems[].status.conditions[]?.type,
     ($np_map | to_entries[].value[].status.conditions[]?.type) ]
   | unique | map(select(endswith("Successful") | not))) as $ctypes |

  # Adapter names from all statuses
  ([ ($cluster_statuses | to_entries[].value[].adapter),
     ($np_statuses | to_entries[].value[].adapter) ]
   | map(select(. != null)) | unique) as $adapters |

  # Header
  (["ID", "NAME", "GEN"] + $ctypes + $adapters | @tsv),
  (["---", "---", "---"] + ($ctypes | map("---")) + ($adapters | map("---")) | @tsv),

  # Rows: cluster row followed by its nodepool rows
  ($citems[] |
    . as $cluster |
    ($cluster_statuses[$cluster.id] // []) as $cstatus |
    (if $cluster.deleted_time != null then "Finalized" else "Available" end) as $ctype |

    ([ .id, .name,
       ((.generation // 0 | tostring) + (if .deleted_time != null then "" else "" end)) ] +
     [ $ctypes[] as $t | $cluster.status.conditions // [] | map(select(.type == $t)) | .[0] | fmt_cond ] +
     [ $adapters[] as $a | $cstatus | map(select(.adapter == $a)) | .[0] | fmt_adapter($ctype) ]
     | @tsv),

    ($np_map[$cluster.id] // [] | .[] |
      . as $np |
      ($np_statuses[$np.id] // []) as $npstatus |
      (if $np.deleted_time != null then "Finalized" else "Available" end) as $nptype |

      ([ ("  " + .id), ("  " + .name),
         ((.generation // 0 | tostring) + (if .deleted_time != null then "" else "" end)) ] +
       [ $ctypes[] as $t | $np.status.conditions // [] | map(select(.type == $t)) | .[0] | fmt_cond ] +
       [ $adapters[] as $a | $npstatus | map(select(.adapter == $a)) | .[0] | fmt_adapter($nptype) ]
       | @tsv)
    )
  )
' | awk -v green="$GREEN" -v red="$RED" -v yellow="$YELLOW" -v reset="$RESET" '
BEGIN { FS = "\t" }
function dw(cell,    c, gen, pos) {
  c = substr(cell, 1, 1)
  if (c == "\001" || c == "\002" || c == "\003") {
    gen = substr(cell, 2)
    return 1 + (gen != "" ? 1 + length(gen) : 0)
  }
  pos = index(cell, "\004")
  if (pos > 0) return (pos - 1) + 3
  return length(cell)
}
function render(cell,    c, gen, pos) {
  c = substr(cell, 1, 1)
  if (c == "\001") { gen = substr(cell, 2); return green "●" reset (gen != "" ? " " gen : "") }
  if (c == "\002") { gen = substr(cell, 2); return red   "●" reset (gen != "" ? " " gen : "") }
  if (c == "\003") { gen = substr(cell, 2); return yellow "●" reset (gen != "" ? " " gen : "") }
  pos = index(cell, "\004")
  if (pos > 0) return substr(cell, 1, pos - 1) " " red "❌" reset
  return cell
}
{
  row[NR] = $0
  n = split($0, f, "\t")
  if (n > ncols) ncols = n
  for (i = 1; i <= n; i++) {
    w = dw(f[i])
    if (w > cw[i]) cw[i] = w
  }
}
END {
  for (r = 1; r <= NR; r++) {
    n = split(row[r], f, "\t")
    for (i = 1; i <= ncols; i++) {
      cell = (i <= n) ? f[i] : ""
      pad = cw[i] - dw(cell)
      if (i < ncols) printf "%s%*s  ", render(cell), pad, ""
      else           printf "%s", render(cell)
    }
    printf "\n"
  }
}'
