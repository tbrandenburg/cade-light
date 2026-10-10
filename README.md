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
| `config/srt-settings.json` | Example opt-in agent sandbox policy. |
| `compose.override.yaml` (optional, Git-ignored) | Host-specific Compose overrides. |

**Normally do not edit these files as a user:**

| File or directory | Purpose |
| --- | --- |
| `components/*/service.yaml` | Reusable Compose service defaults (the root manifest uses `extends`). |
| `components/workbench/Dockerfile` | OS, language runtimes, core applications and image build logic. |
| `components/workbench/start.sh` | Starts the three HTTP services and handles termination. |
| `components/workbench/node-red-settings.js` | Node-RED runtime integration and palette discovery. |
| `Makefile` | Convenience commands only; not a second configuration language. |

**Runtime data:** `workspace/` contains project files; the named `home` volume
contains application state and Node-RED flows. Both need backup independently
of the Git repository. `.env` and `workspace/` are Git-ignored. The Compose
project name remains `cade-minimal` to preserve the existing volume names.

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

SRT is installed but **not** automatically applied to OpenCode. Verify that
bubblewrap can create a sandbox under the host's Docker security policy
before relying on it:

```sh
docker compose exec workbench \
  srt --settings /etc/srt-settings.json echo sandbox-ok
```

A successful installation does not prove sandbox enforcement. Avoid
`privileged: true` or globally disabling seccomp just to make SRT start.

## Extensions

### Add a Node-RED palette node

Add the package and its version to `config/node-red/package.json`, then
`make up`. This installs packages in `/opt/node-red/node_modules` during the
image build; `components/workbench/node-red-settings.js` points Node-RED at
that directory. Existing user flows remain in the `home` volume.

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

Compose's `extends` resolves referenced service paths and build contexts from
the main Compose project directory. The workbench intentionally builds from
the repository root to read `config/` while keeping code in `components/`.
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
```

## Migration from the inline-Dockerfile layout

This is a file-layout refactor rather than a change in deployment model:
`compose.yaml` no longer holds the Dockerfile; `scripts/start.sh` and
`scripts/node-red-settings.js` moved into the workbench component, while
`scripts/srt-settings.json` moved to user-editable `config/`.
The existing `home` and `redis_data` volumes, container ports, workspace
mount, and application versions remain unchanged. To revert, check out the
previous commit and rebuild; do not use `docker compose down -v` unless you
intend to destroy saved data.