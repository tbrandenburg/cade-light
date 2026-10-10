# Repository Guide

## Purpose

CADE Light is a small Docker Compose development workbench. It brings
code-server, JupyterLab, and Node-RED together in a shared workspace, with
OpenCode and the optional SRT confinement setup available from the terminal.
The stack is managed directly with Docker Compose; it does not require a Coder
control plane or Terraform.

## Folder structure and file roles

| Path | Role |
| --- | --- |
| `compose.yaml` | User-facing default stack: selects services and configures ports, environment, profiles, and volumes. |
| `compose.srt.yaml` | Explicit opt-in overlay for host-dependent SRT confinement. |
| `components/<name>/` | Reusable service implementation and defaults; keep component-specific build/runtime files with their component. |
| `components/workbench/security/` | Workbench security profiles, host profile loader, and SRT enforcement check. |
| `config/` | User-editable application configuration and extra package lists copied or mounted into services. |
| `docs/` | Longer-form operational guidance, including SRT security implications and setup. |
| `.github/workflows/` | Repository automation and validation workflows. |
| `workspace/` | Runtime project files mounted into the workbench; do not put application source or tracked configuration here. |

Keep stack selection and host-specific configuration in the root Compose
manifests; keep reusable service implementation in `components/`; keep
user-adjustable application settings in `config/`. Add operational guidance
under `docs/` and update `README.md` when user-facing configuration or workflow
changes. Do not add a second deployment/configuration system alongside Docker
Compose or move runtime data into the source/configuration directories.

## Make targets

| Target | Purpose |
| --- | --- |
| `make help` | Print the available convenience commands. |
| `make init` | Create `.env` from `.env.example` if needed, create `workspace/`, and remind you to review placeholder secrets. |
| `make build` | Build the workbench image. |
| `make up` | Build and start the default Compose stack in the background. |
| `make down` | Stop the Compose stack without removing persistent volumes. |
| `make logs` | Follow workbench logs. |
| `make ps` | Show Compose service status. |
| `make exec` | Open a Bash shell in the workbench container. |
| `make config` | Validate the default merged Compose configuration. |
| `make config-srt` | Validate the Compose configuration with the opt-in SRT overlay. |
| `make up-srt` | Build and start the stack with the SRT overlay. |
| `make verify-srt` | Run the SRT sandbox enforcement check in the workbench. |

The SRT targets use host-dependent security profiles. Review `docs/SRT.md`
before using them.
