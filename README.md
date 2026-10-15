# HyperFleet Scripts

CLI utilities for managing HyperFleet clusters, node pools, databases, and Kubernetes resources.

## Quick Start

```bash
hf.config.sh bootstrap my-env    # Interactive setup: context, API, port-forwards, DB
hf.config.sh doctor              # Check which scripts are ready to use
```

## Script Groups

| Prefix | What it manages |
|--------|----------------|
| `hf.cluster.*` | Cluster API objects — create, inspect, patch, watch conditions and statuses |
| `hf.nodepool.*` | NodePool API objects — create, inspect, patch, watch conditions and statuses |
| `hf.db.*` | Direct database access — queries, status records, cleanup |
| `hf.kube.*` | Kubernetes helpers — context, port-forward, in-cluster curl, debug pods |
| `hf.logs.*` | Log tailing — pods and adapter-filtered logs |
| `hf.pubsub.*` | GCP Pub/Sub — list topics/subscriptions, publish change events |
| `hf.rabbitmq.*` | RabbitMQ — publish change events via HTTP management API |
| `hf.repos.*` | GitHub repository status overview |
| `hf.config.*` | Configuration management — environments, bootstrap, doctor |

## Config System

All scripts use a **file-based configuration** system with environment variable overrides:

- **Config location**: `~/.config/hf/` (one file per setting)
- **Precedence**: Environment variables > config files > defaults
- **Shared state**: Settings persist across script invocations
- **Property registry**: All config keys are declared once in `HF_CONFIG_REGISTRY` in `hf.lib.sh`
- **Dependency tracking**: Each script declares its required config via `hf_require_config`

### Managed via `hf.config.sh`

```bash
hf.config.sh                      # Show help, environments, and active config
hf.config.sh show                 # Show current configuration
hf.config.sh show my-env          # Show config with environment overrides highlighted
hf.config.sh set api-url <url>    # Set API URL
hf.config.sh clear token          # Clear auth token
hf.config.sh clear all            # Reset everything
hf.config.sh doctor               # Check per-script readiness
hf.config.sh bootstrap [env]      # Interactive environment setup
hf.config.sh env list             # List environments
hf.config.sh env activate <name>  # Activate an environment
```

Settings are grouped into sections in the registry:

**hyperfleet**: `api-url`, `api-version`, `token`, `context`, `namespace`, `gcp-project`, `cluster-id`, `cluster-name`, `nodepool-id`

**portforward**: `pf-api-port`, `pf-pg-port`

**database**: `db-host`, `db-port`, `db-name`, `db-user`, `db-password`

### Adding a new config property

1. Add one line to `HF_CONFIG_REGISTRY` in `hf.lib.sh`
2. Add a `HF_*_FILE` variable and `_hf_load` call in the same file
3. Add a setter function if scripts need to set it programmatically
4. Scripts that need it add the key to their `hf_require_config` call

No other files need to change -- `hf.config.sh`, environments, and doctor all derive from the registry.

## Scripts Overview

### Cluster Management

| Script | Description |
|--------|-------------|
| `hf.cluster.create.sh` | Create a new cluster via API |
| `hf.cluster.delete.sh` | Delete cluster by ID |
| `hf.cluster.get.sh` | Get cluster details by ID |
| `hf.cluster.search.sh` | Search clusters by name and set as current |
| `hf.cluster.list.sh` | List all clusters |
| `hf.cluster.table.sh` | Display clusters in table format |
| `hf.cluster.id.sh` | Show current cluster ID |
| `hf.cluster.patch.sh` | Increment counter field in cluster spec or labels |
| `hf.cluster.conditions.sh` | Show cluster conditions (`-w` for watch) |
| `hf.cluster.conditions.table.sh` | Show cluster conditions in table format |
| `hf.cluster.statuses.sh` | Show cluster adapter statuses (`-w` for watch) |
| `hf.cluster.statuses.table.sh` | Display cluster adapter statuses in table format (Available and Finalized) |
| `hf.cluster.adapter.post.status.sh` | Post adapter status for current cluster |

### NodePool Management

| Script | Description |
|--------|-------------|
| `hf.nodepool.create.sh` | Create one or more node pools under the current cluster (`name [count] [instance-type]`) |
| `hf.nodepool.delete.sh` | Delete a node pool |
| `hf.nodepool.get.sh` | Get node pool details |
| `hf.nodepool.list.sh` | List node pools for the current cluster |
| `hf.nodepool.search.sh` | Search for nodepool by name and set as current |
| `hf.nodepool.table.sh` | Display node pools in table format |
| `hf.nodepool.patch.sh` | Increment counter field in nodepool spec or labels |
| `hf.nodepool.conditions.sh` | Show node pool conditions (`-w` for watch) |
| `hf.nodepool.conditions.table.sh` | Show node pool conditions in table format |
| `hf.nodepool.statuses.sh` | Show node pool adapter statuses (`-w` for watch) |
| `hf.nodepool.statuses.table.sh` | Display node pool adapter statuses in table format (Available and Finalized) |
| `hf.nodepool.adapter.post.status.sh` | Post adapter status for current node pool |

### Database Operations

| Script | Description |
|--------|-------------|
| `hf.db.config.sh` | Interactive database configuration |
| `hf.db.query.sh` | Execute SQL queries or files |
| `hf.db.delete.sh` | Delete database records |
| `hf.db.statuses.sh` | Query cluster status table |
| `hf.db.delete.all.sh` | Delete all records from adapter_statuses, node_pools, and clusters tables |
| `hf.db.statuses.delete.sh` | Delete status records |

### Kubernetes Helpers

| Script | Description |
|--------|-------------|
| `hf.kube.context.sh` | Select and save kubectl context/namespace |
| `hf.kube.curl.sh` | Run curl from inside a cluster pod (see below) |
| `hf.kube.debug.pod.sh` | Create debug pod cloned from a deployment (see below) |
| `hf.kube.port.forward.sh` | Port forward to services/pods |

#### `hf.kube.curl.sh`

Runs curl from inside a pod in the current Kubernetes cluster, useful for reaching cluster-internal services. The pod (`hf-kcurl`) is reused across invocations and auto-terminates after 5 minutes via `sleep 300`, so the first call pays the pod startup cost but subsequent calls are fast. Only curl output is written to stdout, making the script safe to use in pipelines and other scripts.

```bash
# Simple GET
hf.kube.curl.sh http://my-service.ns.svc:8080/health

# POST with inline data
hf.kube.curl.sh -X POST -H "Content-Type: application/json" -d '{"key":"val"}' http://my-service.ns.svc:8080/api

# POST with file body
hf.kube.curl.sh -X POST -H "Content-Type: application/json" -f payload.json http://my-service.ns.svc:8080/api

# Save response to file
hf.kube.curl.sh -o response.json http://my-service.ns.svc:8080/api

# Use in a pipeline
hf.kube.curl.sh http://my-service.ns.svc:8080/api | jq '.items[]'
```

#### `hf.kube.debug.pod.sh`

Creates a debug pod by cloning the pod template from an existing deployment. The debug pod runs with the same image, environment variables, volumes, and service account as the original deployment, but replaces the entrypoint with `sleep infinity` and removes all health probes. This lets you exec into a shell with the exact same runtime context as the target workload — useful for debugging configuration, network connectivity, or permissions issues.

The deployment is matched by partial name, so you don't need to type the full name.

```bash
# Clone a deployment's pod template into a debug pod and exec into it
hf.kube.debug.pod.sh my-app

# Specify a namespace
hf.kube.debug.pod.sh my-app staging

# Clean up when done
kubectl delete pod my-app-debug-<timestamp> -n default
```

### Logs

| Script | Description |
|--------|-------------|
| `hf.logs.sh` | Tail pod logs with context |
| `hf.logs.adapter.sh` | Tail adapter pod logs filtered by cluster ID |

### Pub/Sub and Messaging

| Script | Description |
|--------|-------------|
| `hf.pubsub.list.sh` | List Pub/Sub topics and subscriptions, with optional filter |
| `hf.pubsub.publish.cluster.change.sh` | Publish cluster change event to a Pub/Sub topic |
| `hf.pubsub.publish.nodepool.change.sh` | Publish nodepool change event to a Pub/Sub topic |
| `hf.rabbitmq.publish.cluster.change.sh` | Publish cluster change event to a RabbitMQ exchange via HTTP management API |

### Other Utilities

| Script | Description |
|--------|-------------|
| `hf.table.sh` | Combined table of all clusters with their nodepools, showing ready status and adapter counts |
| `hf.workflow.sh` | End-to-end test workflow: create cluster+nodepool, cycle adapter statuses and patches through multiple generations, then delete |
| `hf.workflow.api-only.sh` | API-only workflow: create cluster+nodepool, post adapter statuses, and clean up without real adapters |
| `hf.repos.sh` | Show status table for all HyperFleet GitHub repositories |
| `hf.lib.sh` | Shared library (config registry, API helpers, logging, Kubernetes wrappers) |

## Common Patterns

**Bootstrap a new environment**:
```bash
hf.config.sh bootstrap dev
```

**Check what's ready**:
```bash
hf.config.sh doctor
```

**Search and set current cluster**:
```bash
hf.cluster.search.sh my-cluster-name
```

**Query cluster details** (uses saved cluster-id):
```bash
hf.cluster.get.sh
```

**Create and manage node pools**:
```bash
hf.nodepool.create.sh my-pool 3 m5.2xlarge
hf.nodepool.list.sh
hf.nodepool.table.sh
hf.nodepool.conditions.sh -w
```

**Post adapter status manually**:
```bash
hf.cluster.adapter.post.status.sh validator True 1
hf.nodepool.adapter.post.status.sh provisioner True 1
```

**Switch environments**:
```bash
hf.config.sh env list
hf.config.sh env activate staging
```

**Configure kubectl context**:
```bash
hf.kube.context.sh select
```

**Run database query**:
```bash
hf.db.query.sh "SELECT * FROM clusters LIMIT 10"
hf.db.query.sh -f schema.sql
```

## Architecture

- **hf.lib.sh**: Core library providing config registry, config loading, API helpers, logging, and Kubernetes wrappers
- **Config registry**: `HF_CONFIG_REGISTRY` in `hf.lib.sh` is the single source of truth for all config properties (section, key, default, sensitivity)
- **Dependency declarations**: Each script declares `hf_require_config <keys>` -- used at runtime for validation and by `doctor` for readiness scanning
- **File-based state**: Each config value stored separately in `~/.config/hf/` for easy inspection and editing
- **Environment profiles**: Named environments stored as `<env>.<property>` files in the config directory
- **Environment override**: Set `HF_API_URL`, `HF_TOKEN`, etc. to override file config
- **Consistent interface**: All scripts source `hf.lib.sh` for unified behavior and error handling
