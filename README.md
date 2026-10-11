# CADE Light

A small Docker Compose development workbench: code-server, JupyterLab, and
Node-RED share one workspace; OpenCode and SRT are available in the terminal.
No Coder control plane or Terraform is required.

## Configuration contract

**Edit these files as a user:**

| File | Purpose |
| --- | --- |
| `compose.yaml` | Select and connect components; set ports, environment and volumes. This is the user-facing stack manifest. |
| `.env` (copied from `.env.example`) | Host-specific ports, passwords and tokens. Never commit secrets. |
| `config/requirements.txt` | Extra Python packages installed into the Jupyter virtual environment on rebuild. |
| `config/node-red/package.json` | Built-in and additional Node-RED palette nodes installed on rebuild. |
| `flows/flows.json` | Git-versioned Node-RED flows bundled into the image (default). |
| `compose.node-red-host-flows.yaml` | Optional read-only local workflow source overlay. |
| `config/srt-settings.json` | User-editable allowlist and secret-path restrictions for SRT. |
| `compose.override.yaml` (optional, Git-ignored) | Host-specific Compose overrides. |
| `compose.srt.yaml` (explicit opt-in) | Select the host-dependent SRT-compatible Docker confinement mode. |

**Normally do not edit these files as a user:**

| File or directory | Purpose |
| --- | --- |
| `components/*/service.yaml` | Reusable Compose service defaults (the root manifest uses `extends`). |
| `components/workbench/Dockerfile` | OS, language runtimes, core applications and image build logic. |
| `components/workbench/start.sh` | Starts the three HTTP services and handles termination. |
| `components/workbench/node-red-settings.js` | Node-RED runtime integration and palette discovery. |
| `components/workbench/security/` | Scoped seccomp/AppArmor profiles, explicit host loader, sandbox smoke test. |
| `Makefile` | Convenience commands only; not a second configuration language. |

**Runtime data:** `workspace/` holds projects; `home` holds shared workbench
state; the new `node_red_state` volume holds encrypted Node-RED credentials,
context, runtime metadata and a deployed copy of flow definitions. The source
of truth for workflows is Git (`flows/flows.json` or an external repo). `.env`,
`workspace/` and optional host `state/` are Git-ignored. **Existing Node-RED
users must migrate their previous `.node-red` data from the `home` volume.**
See [the Node-RED GitOps guide](docs/node-red-gitops.md).

## Start

Requirements: Docker Engine with the Compose v2 plugin.

```sh
make init
# Edit .env: replace ALL placeholder secrets with long, random values.
make config  # Validate the merged Compose model without starting containers.
make up      # Build and start the workbench.
```

All web interfaces bind to host loopback (not the public network):

| Application | Default URL | Authentication |
| --- | --- | --- |
| code-server | http://localhost:8080 | `PASSWORD` |
| JupyterLab | http://localhost:8888 | `JUPYTER_TOKEN` |
| Node-RED | http://localhost:1880 | **No login**; local-only by default |

The ports can be changed in `.env` with `CODE_SERVER_PORT`, `JUPYTER_PORT`, and
`NODE_RED_PORT`. For remote access, use SSH forwarding or a properly
authenticated HTTPS reverse proxy. Do not expose Node-RED directly.

Use OpenCode in the VS Code terminal or with:

```sh
docker compose exec workbench opencode
```

SRT is installed but **not** automatically applied to OpenCode or Node-RED
agents. The ordinary Docker profile may block Bubblewrap. CADE's scoped,
host-dependent seccomp/AppArmor profiles are provided as an **explicit opt-in**.
See [SRT setup, security and limitations](docs/SRT.md) first:

```sh
# Host administrator, manual action (may need repeating after reboot):
sudo components/workbench/security/load-apparmor.sh
# Enable the compatibility overlay and test actual enforcement:
make up-srt
make verify-srt
```

The overlay includes `systempaths=unconfined`, which weakens Docker's built-in
path masking. Do not use `privileged: true` as a shortcut.

## Version updates (October 10, 2026)

This PR moves to Node.js 24, Node-RED 5.0.8, JupyterLab 4.6.4,
OpenCode 1.18.35, SRT 0.0.79, code-server 4.141.0, FlowFuse Dashboard
1.33.0 and node-red-agents 0.4.4. Redis remains on major 7 (7.4.11-alpine).
These upgrades **require live build/flow compatibility testing**. Back up the
named home volume before starting upgraded Node-RED with existing flows.

## GitOps Node-RED workflows

By default, this Git repository's `flows/flows.json` is bundled into the
image. Alternatively configure **an external Git repository** in `.env`:

```dotenv
NODE_RED_FLOWS_SOURCE=git
NODE_RED_GIT_URL=https://github.com/example/automations.git
NODE_RED_GIT_REF=main
NODE_RED_FLOW_PATH=flows.json
```

The container fetches the repository itself at startup, resolves the selected
ref, verifies JSON and stages the file into persistent Node-RED runtime state.
No host checkout or polling sidecar is required. Pin an exact commit SHA for
production. Editor changes do **not** push to Git; deploys back up the replaced
working copy. For a local directory instead, set `NODE_RED_HOST_FLOWS_PATH`
and use `make up-host-flows` (read-only source mount). Runtime credentials and
context remain in `node_red_state` by default; optionally set
`NODE_RED_STATE_STORAGE=./state/node-red` for host-backed state.

**Upgrading an existing workbench requires manual Node-RED data migration.**
Read [GitOps setup, persistence, security and migration](docs/node-red-gitops.md)
before switching.

## Extensions

### Add a Node-RED palette node

Add the package and its version to `config/node-red/package.json`, then
`make up`. This installs packages in `/opt/node-red/node_modules` during the
image build; `components/workbench/node-red-settings.js` points Node-RED at
that directory. Existing user flows and credentials must be migrated from `home` into `node_red_state` (or configured host state directory); see the GitOps guide.

### Add Python packages

Add pinned dependencies to `config/requirements.txt`, then `make up`.
They are installed into `/opt/jupyter`, which is also put on the container's
`PATH` (including VS Code terminals). This is not the Debian system Python.

### Add a service

Create `components/<name>/service.yaml` defining its reusable implementation.
Reference it from root `compose.yaml` using `extends`, and put optional
`profiles`, host ports, persistent volumes, and user-specific environment in
the root manifest. For example, Redis is already implemented this way:

```sh
docker compose --profile redis up -d
# or set COMPOSE_PROFILES=redis in .env
```

The workbench can connect to Redis at `redis:6379` over the Compose network.
For larger multi-service capabilities, Compose `include` may be a better fit;
there is no need to introduce a proprietary plugin manifest or generator.

Compose `extends` resolves the reusable build context relative to the component
file (`../..` is the repository root). The Dockerfile path is relative to this
build context, allowing `config/` access without mixing build details into
the user manifest.
`.dockerignore` excludes `.env` and workspace data from the build context.

## Commands

```sh
make config  # Validate Compose interpolation/merges
make build   # Build workbench image
make up      # Start or rebuild workbench
make ps      # List running containers
make logs    # Follow workbench logs
make exec    # Shell inside workbench
make down    # Stop without deleting persistent volumes
make config-srt # Validate SRT opt-in Compose overlay
make up-srt     # Start with host-loaded security profile
make verify-srt # Check sandbox startup and deny enforcement
make up-host-flows # Optional host-backed workflow source
```

## Migration from the inline-Dockerfile layout

This is a file-layout refactor rather than a change in deployment model:
`compose.yaml` no longer holds the Dockerfile; `scripts/start.sh` and
`scripts/node-red-settings.js` moved into the workbench component, while
`scripts/srt-settings.json` moved to user-editable `config/`.
The existing `home` and `redis_data` volumes and application ports are retained, but a new `node_red_state` volume is introduced for Node-RED; migrate existing data before first startup. To revert, check out the
previous commit and rebuild; do not use `docker compose down -v` unless you
intend to destroy saved data.