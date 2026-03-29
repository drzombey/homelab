# Flux Setup

## Prerequisites

- Talos cluster is running and `kubeconfig` is in place (`~/.kube/config`)
- `flux` CLI installed (`mise` installs it automatically from `mise.toml`)
- `gh` CLI installed and authenticated (`gh auth login`)
- 1Password Connect credentials JSON file and API token

Verify the Flux CLI is available:

```bash
flux version --client
```

Verify GitHub auth:

```bash
gh auth status
```

## Variables

The Flux bootstrap and secret provisioning require four additional variables in `infrastructure/terraform.tfvars`:

| Variable | Description |
| --- | --- |
| `github_owner` | GitHub user or organisation that owns the repository (default: `drzombey`) |
| `github_repository` | Repository name (default: `homelab`) |
| `op_connect_token` | 1Password Connect API token |
| `op_credentials_json` | Contents of the `1password-credentials.json` file |

Example entries to add to `terraform.tfvars`:

```hcl
github_owner        = "drzombey"
github_repository   = "homelab"
op_connect_token    = "your-connect-token"
op_credentials_json = file("path/to/1password-credentials.json")
```

The `op_connect_token` and `op_credentials_json` variables are marked `sensitive` and will not appear in plan output.

## How Bootstrap Works

Bootstrap is handled by two `terraform_data` resources in `infrastructure/flux.tf`:

**`terraform_data.flux_bootstrap`**

Runs `flux bootstrap github` via `local-exec`. It uses the token from the locally authenticated `gh` CLI — no separate GitHub PAT is stored anywhere. After bootstrap, Flux uses an SSH deploy key for all subsequent Git operations.

```bash
GITHUB_TOKEN="$(gh auth token)" flux bootstrap github \
  --owner="<github_owner>" \
  --repository="<github_repository>" \
  --branch=main \
  --path=clusters/homelab \
  --personal
```

This command:
1. installs the Flux controllers into the cluster
2. creates an SSH deploy key and adds it to the GitHub repository
3. commits the `clusters/homelab/flux-system/` manifests to the repository
4. starts reconciliation from `clusters/homelab`

**`terraform_data.bootstrap_secrets`**

Runs after `flux_bootstrap` and creates the two secrets that Flux itself cannot create (because they are needed before ESO and 1Password Connect are running):

- `op-token` in namespace `external-secrets` — used by ESO to authenticate to 1Password Connect
- `op-credentials` in namespace `connect` — used by the 1Password Connect server to authenticate to 1Password.com

Both secrets are applied idempotently using `--dry-run=client | kubectl apply`.

## Running Bootstrap

Bootstrap runs as part of `tofu apply`. There is no separate step.

```bash
tofu apply
```

The Flux bootstrap and secret creation happen after the Talos cluster is healthy. Flux then begins reconciling the `clusters/homelab/infrastructure/` tree.

## Verifying Bootstrap

Check that the Flux controllers are running:

```bash
kubectl get pods -n flux-system
```

Check that the root kustomization is reconciling:

```bash
flux get kustomizations
```

Check all infrastructure components:

```bash
flux get kustomizations --all-namespaces
```

Check HelmReleases:

```bash
flux get helmreleases --all-namespaces
```

All items should show `Ready: True`.

## Re-Running Bootstrap

The `flux_bootstrap` resource has `triggers_replace` set on `github_owner`, `github_repository`, and the cluster path. It will only re-run if those values change.

If you need to force re-bootstrap without changing the triggers, taint the resource:

```bash
tofu taint terraform_data.flux_bootstrap
tofu apply
```

If you accidentally taint `flux_bootstrap` and do not want it to re-run, untaint it:

```bash
tofu untaint terraform_data.flux_bootstrap
```

Re-running `flux bootstrap` on an already-bootstrapped cluster is safe. Flux will update its components in place.

## Re-Applying Bootstrap Secrets

The `bootstrap_secrets` resource triggers on the SHA256 hash of each secret value. If you rotate either credential, update the variable and run:

```bash
tofu apply
```

OpenTofu will detect the hash change and re-apply both secrets.
