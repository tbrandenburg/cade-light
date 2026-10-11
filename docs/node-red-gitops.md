# Node-RED GitOps flows and persistent runtime state

CADE Light separates **Git-versioned workflow definitions** from **runtime
credentials and context**. The root Compose manifest remains the user-facing
control: it selects flow source, remote revision and runtime storage.

## Flow sources

1. **Bundled (default):** version `flows/flows.json` in the CADE Light Git
   repository. The image includes this file. Fresh installations start with
   `[]` and do not require Git network access.
2. **Remote Git:** set `NODE_RED_FLOWS_SOURCE=git`, `NODE_RED_GIT_URL`,
   `NODE_RED_GIT_REF` (branch, tag or exact commit) and
   `NODE_RED_FLOW_PATH` (relative to repository root). Startup clones the
   repository **inside the container**, without any new host checkout mount.
3. **Host development:** use `make up-host-flows` with
   `NODE_RED_HOST_FLOWS_PATH=./flows` or another local path.
   `compose.node-red-host-flows.yaml` binds it **read-only** as a source.
   This overlay is optional; it is never required for Git deployment.

Examples in `.env`:

```dotenv
# Default: code ships from the platform's own version-controlled source.
NODE_RED_FLOWS_SOURCE=bundled
NODE_RED_FLOW_PATH=flows.json

# OR independent workflow repository:
NODE_RED_FLOWS_SOURCE=git
NODE_RED_GIT_URL=https://github.com/example/workflows.git
NODE_RED_GIT_REF=main
NODE_RED_FLOW_PATH=node-red/flows.json
```

Use an exact commit SHA as `NODE_RED_GIT_REF` in production for deterministic
deployments. `make up` builds/starts; `docker compose restart workbench`
re-fetches remote Git. There is no polling, live hot-reload or automatic
git commit/push. A flow edited in Node-RED's browser is a change to the
persistent **deployed copy**, not Git; commit reviewed changes to the source
repository explicitly. At next deployment, the previous working copy is
backed up under `.cade-flow-backups/` if it differs.

If Git or JSON validation fails, startup exits before launching applications,
without replacing the previous deployed flows. A successful fetch validates
that the JSON is a list of objects; it **does not** prove every node type
exists or every flow will start. Git repos are cloned with `--no-checkout`
and switched to the resolved commit; no repository scripts are executed
during fetch. Flow nodes may themselves execute code after Node-RED starts.

## State persistence and security

Runtime Node-RED userDir remains `/home/node/.node-red`, but is now a
dedicated mounted volume. It contains the deployed `flows.json`,
`flows_cred.json` (encrypted using the existing stable
`NODE_RED_CREDENTIAL_SECRET`), persistent filesystem context,
`package.json`, library state, backups and a
`.cade-flow-revision` marker. Runtime data is not Git-controlled.
The palette packages still come from the maintainer-built image and
`config/node-red/package.json`, not arbitrary repository build scripts.

Default persistent state uses a Docker named volume:

```dotenv
NODE_RED_STATE_STORAGE=node_red_state
```

Optional host-backed state works with *any* flow source:

```dotenv
NODE_RED_STATE_STORAGE=./state/node-red
```

Create the directory first and make it writable by the container's `node`
user (normally UID 1000), while preventing other local users from reading
it. The `state/` directory is Git-ignored; back it up securely. This is
**different** from the optional host *flow source* overlay.

Avoid tokens embedded in Git URLs and never commit credentials files.
Public HTTPS works without additional setup. For private Git, you must
provide appropriately scoped read-only credentials to the container's
Git process, preferably via a deployment-time credential helper. Since
this workbench also runs user code and agent tools, secrets visible to Git
in the same container may be visible to those processes: prefer a
separate fetch service or CI for untrusted workflows.

## Existing deployments: mandatory migration

The old Node-RED user directory is inside the shared `home` volume.
The new `node_red_state` mount overlays `/home/node/.node-red`: the
**old data remains in home but is hidden from the new workbench mount.**
No automatic migration occurs. The new bundled file is `[]`, so users
who skip migration will see an apparently empty Node-RED editor.

1. **Stop and back up** the old workbench's `home` Docker volume before
   adopting this branch. Do not run `docker compose down -v`.
2. Mount the old `cade-minimal_home` volume in a one-off container and
   copy its `.node-red/` contents to the new dedicated
   `cade-minimal_node_red_state` volume or to the chosen host directory.
   Review ownership and permissions: the workbench runs as UID 1000.
3. Older flows may be named `flows_<hostname>.json` and their credentials
   `flows_<hostname>_cred.json`. Export the *reviewed flow definitions*
   into the Git-controlled `flows/flows.json` or your external repository,
   and migrate the corresponding encrypted credentials file to
   `flows_cred.json` for the new fixed filename. Do not commit credentials.
4. Preserve `NODE_RED_CREDENTIAL_SECRET` or the credential file may
   become unreadable. Verify node palette availability and any filesystem
   context values before deleting the backup.
5. Start the new workbench and check the deployed Git revision and flows.

The deployment script always writes `flows.json` from the chosen source,
so do not expect a runtime `flows_<hostname>.json` to be read implicitly.
Keep a safe backup of old data until verification is complete.

## Multiple repositories

A single Node-RED runtime has a single active `flows.json`. Deploy
separate Node-RED instances for independent repositories or use Node-RED's
optional Projects feature; do not blindly concatenate flow files because
node IDs, credentials and context can collide.
