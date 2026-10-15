# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A suite of Bash CLI scripts (`hf.*.sh`) for managing HyperFleet clusters, node pools, databases, and Kubernetes resources. There is no build system, package manager, or test framework — these are standalone Bash scripts that users add to their PATH.

## Validation

```bash
# Syntax-check all scripts (no test suite exists)
for f in hf.*.sh; do bash -n "$f"; done

# Verify config system works end-to-end
./hf.config.sh show
./hf.config.sh doctor
```

## Architecture

### Core library: `hf.lib.sh`

Every script begins with `source "$(dirname "$(realpath "$0")")/hf.lib.sh"`. This file provides:

- **Config Property Registry** (`HF_CONFIG_REGISTRY`): Pipe-delimited array (`section|key|default|flags`) that is the single source of truth for all configuration properties. Every other script derives from this.
- **File-based config loading** (`_hf_load`): Each property maps to a file in `~/.config/hf/<key>`. Environment variables (`HF_API_URL`, `HF_TOKEN`, etc.) take precedence over files.
- **Config requirement declarations** (`hf_require_config`): Scripts declare their required config keys at the top. Used both for runtime validation and by the `doctor` command to scan readiness.
- **API helpers**: `hf_api`, `hf_get`, `hf_post`, `hf_delete` — wrappers around `curl --http1.1` targeting `${HF_API_URL}/api/hyperfleet/${HF_API_VERSION}`.
- **Kubernetes helpers**: `hf_kubectl` (context-aware), `hf_kubectl_ns` (context+namespace-aware).
- **ID management**: `hf_cluster_id`/`hf_set_cluster_id`, `hf_nodepool_id`/`hf_set_nodepool_id` — get from arg, file, or die.
- **Registry parsing**: `_hf_parse "$entry"` sets `$_HF_E_SECTION`, `$_HF_E_KEY`, `$_HF_E_DEFAULT`, `$_HF_E_FLAGS` without subshells (performance-critical — avoids fork/exec).

### Central config management: `hf.config.sh`

Subcommands: `show`, `set`, `clear`, `doctor`, `bootstrap`, `env list|show|activate`. Called with no args, it shows help + environments + active config. The `doctor` subcommand scans all scripts for `hf_require_config` lines using `sed` and cross-references with current config values.

### Script naming convention

`hf.<resource>.<action>.sh` — e.g., `hf.cluster.create.sh`, `hf.nodepool.list.sh`, `hf.db.query.sh`.

### Environment profiles

Named environments stored as `<env-name>.<property>` files in `~/.config/hf/`. Activated via `hf.config.sh env activate <name>`, which copies env-specific files over the base config files.

## Conventions for Writing New Scripts

1. First line: `source "$(dirname "$(realpath "$0")")/hf.lib.sh"`
2. Immediately declare dependencies: `hf_require_config api-url api-version cluster-id`
3. Use `hf_require_jq`, `hf_require_kubectl`, etc. for tool dependencies
4. Use `hf_cluster_id`, `hf_nodepool_id` for ID resolution (arg > file > die)
5. Pipe API JSON output through `| jq`
6. Watch mode: parse `-w` flag, use `viddy -d` for live updates
7. Help text: use `hf_usage "<args>"` then echo details
8. Colors: use `$BOLD`, `$GREEN`, `$RED`, `$YELLOW`, `$CYAN`, `$NC`
9. Logging: `hf_info`, `hf_warn`, `hf_error`, `hf_die`
10. Make scripts executable: `chmod +x`

## Adding a New Config Property

1. Add one line to `HF_CONFIG_REGISTRY` in `hf.lib.sh`
2. Add a `HF_*_FILE` variable and `_hf_load` call in the same file
3. Optionally add a setter function (`hf_set_*`)
4. Scripts that need it add the key to their `hf_require_config` call

No other files need changes — `hf.config.sh show`, `doctor`, and environments all derive from the registry.

## Performance Notes

Registry parsing uses `IFS='|' read` into shell variables (`_hf_parse`) instead of subshells/cut/awk. This matters because `hf.config.sh` iterates the full registry multiple times. Avoid `$(...)` calls inside registry loops.

## External Tool Dependencies

- `jq` — JSON processing (most scripts)
- `kubectl` — Kubernetes operations
- `viddy` — watch mode (`-w` flag on conditions/statuses scripts)
- `psql` — database scripts
- `gcloud` — GCP operations (pubsub)
- `curl` — API calls (used with `--http1.1`)
