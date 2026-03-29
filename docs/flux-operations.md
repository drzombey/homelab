# Flux Operations

## Checking Status

Get all Flux kustomizations and their reconciliation state:

```bash
flux get kustomizations --all-namespaces
```

Get all HelmReleases:

```bash
flux get helmreleases --all-namespaces
```

Get all sources (HelmRepositories, GitRepositories):

```bash
flux get sources all --all-namespaces
```

Get a summary of everything:

```bash
flux get all --all-namespaces
```

## Forcing Reconciliation

Flux reconciles on a schedule (default interval varies per object). To trigger an immediate reconciliation:

```bash
flux reconcile kustomization infrastructure
```

Force a specific HelmRelease to reconcile:

```bash
flux reconcile helmrelease metrics-server -n metrics-server
```

Force a source to re-fetch:

```bash
flux reconcile source helm metallb -n flux-system
```

## Suspending And Resuming

Suspend a kustomization to pause reconciliation (useful when making manual changes):

```bash
flux suspend kustomization metallb-config
```

Resume it:

```bash
flux resume kustomization metallb-config
```

Suspend a HelmRelease:

```bash
flux suspend helmrelease metallb -n metallb
```

Resume a HelmRelease:

```bash
flux resume helmrelease metallb -n metallb
```

While suspended, Flux will not apply changes from Git. Manual `kubectl apply` commands take effect but will be overwritten when reconciliation resumes.

## Adding A New Component

1. Create a directory for the component under `clusters/homelab/infrastructure/`:

   ```
   clusters/homelab/infrastructure/my-component/
   ├── kustomization.yaml
   ├── namespace.yaml
   └── helmrelease.yaml
   ```

2. If the component needs a Helm chart, add a `HelmRepository` source in `clusters/homelab/infrastructure/sources/`:

   ```yaml
   # clusters/homelab/infrastructure/sources/my-component.yaml
   apiVersion: source.toolkit.fluxcd.io/v1
   kind: HelmRepository
   metadata:
     name: my-component
     namespace: flux-system
   spec:
     interval: 1h
     url: https://charts.example.com
   ```

   Add the new file to `clusters/homelab/infrastructure/sources/kustomization.yaml`.

3. Create a Flux `Kustomization` CRD in `clusters/homelab/infrastructure/`:

   ```yaml
   # clusters/homelab/infrastructure/my-component.yaml
   apiVersion: kustomize.toolkit.fluxcd.io/v1
   kind: Kustomization
   metadata:
     name: my-component
     namespace: flux-system
   spec:
     interval: 10m
     path: ./clusters/homelab/infrastructure/my-component
     prune: true
     sourceRef:
       kind: GitRepository
       name: flux-system
     dependsOn:
       - name: sources
   ```

4. Add the new `Kustomization` file to `clusters/homelab/infrastructure/kustomization.yaml`:

   ```yaml
   resources:
     - ...existing entries...
     - my-component.yaml
   ```

5. Commit and push. Flux will detect the change within one reconciliation interval (default: 1 minute for the `flux-system` GitRepository).

## Removing A Component

1. Remove the entry from `clusters/homelab/infrastructure/kustomization.yaml`
2. Delete the `my-component.yaml` Kustomization CRD file
3. Delete the `clusters/homelab/infrastructure/my-component/` directory
4. Remove the source entry from `sources/` if it is no longer needed
5. Commit and push

Because `prune: true` is set on all kustomizations, Flux will delete the resources it previously applied once they are no longer in Git.

## Upgrading A Component

### HelmRelease Version

Edit the `spec.chart.spec.version` field in the component's `helmrelease.yaml`:

```yaml
spec:
  chart:
    spec:
      version: "1.2.3"   # update this
```

Commit and push. Flux will upgrade the Helm release on the next reconciliation.

### Flux Itself

Upgrade the Flux controllers by re-running bootstrap with the new version:

```bash
flux bootstrap github \
  --owner="<github_owner>" \
  --repository="<github_repository>" \
  --branch=main \
  --path=clusters/homelab \
  --personal
```

Or run `tofu apply` after updating `flux2` in `mise.toml` (which controls the installed CLI version).

The new manifests will be committed to `clusters/homelab/flux-system/` and Flux will update itself.

## Viewing Logs

View logs for the kustomize-controller (applies manifests):

```bash
kubectl logs -n flux-system deploy/kustomize-controller
```

View logs for the helm-controller:

```bash
kubectl logs -n flux-system deploy/helm-controller
```

View logs for the source-controller (fetches Git and Helm sources):

```bash
kubectl logs -n flux-system deploy/source-controller
```

## Checking Events On A Resource

```bash
kubectl describe kustomization infrastructure -n flux-system
kubectl describe helmrelease metallb -n metallb
```

The `Events` and `Status.Conditions` sections show the most recent reconciliation result and any errors.
