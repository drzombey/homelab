# Flux Troubleshooting

## Kustomization Stuck In "Not Ready"

Check the status and message on the kustomization:

```bash
flux get kustomization <name>
kubectl describe kustomization <name> -n flux-system
```

Common causes:

- a `dependsOn` target is itself not ready — check the dependency chain first
- a referenced secret does not exist yet
- a CRD has not been installed yet and a resource of that type is in the manifest

## CRD Not Found After Installing A Controller

After a new controller (such as External Secrets Operator) is installed, the kustomize-controller may not immediately discover the new CRDs it registered. Symptoms: a kustomization that creates resources of the new CRD type fails with `no matches for kind`.

Fix: restart the kustomize-controller to force CRD cache refresh:

```bash
kubectl rollout restart deployment/kustomize-controller -n flux-system
```

Then reconcile the stuck kustomization:

```bash
flux reconcile kustomization cluster-secret-store
```

## ClusterSecretStore Not Ready

The `ClusterSecretStore` uses `apiVersion: external-secrets.io/v1`. In ESO 2.x, the `v1beta1` API version is no longer served. Using `v1beta1` will produce a `no matches for kind` error even though ESO is running.

Confirm the correct API version is in use:

```bash
kubectl get clustersecretstore -o yaml | grep apiVersion
```

It should show `external-secrets.io/v1`.

## 1Password Connect Not Starting

The `1password-connect` HelmRelease requires the `op-credentials` secret in the `connect` namespace to exist before the pod can start. If the pod is in `CrashLoopBackOff` or `Pending`, check that the secret exists:

```bash
kubectl get secret op-credentials -n connect
```

If it does not exist, it was not created by the bootstrap process. Re-apply bootstrap secrets:

```bash
tofu apply
```

Or create it manually:

```bash
kubectl create secret generic op-credentials \
  --from-file=1password-credentials.json=path/to/1password-credentials.json \
  --namespace=connect
```

## External Secrets Operator Not Syncing

If `ExternalSecret` resources are failing, check:

1. the `ClusterSecretStore` is ready:

   ```bash
   kubectl get clustersecretstore
   ```

2. the `op-token` secret exists in `external-secrets`:

   ```bash
   kubectl get secret op-token -n external-secrets
   ```

3. the 1Password Connect pod is running and reachable:

   ```bash
   kubectl get pods -n connect
   ```

4. the ESO pods are running:

   ```bash
   kubectl get pods -n external-secrets
   ```

## Kubelet Serving Cert CSRs Not Being Approved

The `kubelet-serving-cert-approver` automatically approves CSRs for kubelet serving certificates. If `kubectl top nodes` fails with a TLS error, check pending CSRs:

```bash
kubectl get csr
```

CSRs with `Pending` condition should be approved automatically. If they are not:

1. check that the cert approver pod is running:

   ```bash
   kubectl get pods -n kubelet-serving-cert-approver
   ```

2. check that Talos has `rotate-server-certificates: true` set in the kubelet extra args. This is configured in `infrastructure/modules/kubernetes/templates/talos-base-patch.yaml.tftpl` and applied via `main.tf`. Verify it is set on a node:

   ```bash
   talosctl -e 10.0.40.10 -n 10.0.40.10 get kubeletconfig -o yaml | grep rotate
   ```

## `flux bootstrap` Taint Causes Unintended Re-Bootstrap

If `terraform_data.flux_bootstrap` was accidentally tainted, do not run `tofu apply`. Untaint it first:

```bash
tofu untaint terraform_data.flux_bootstrap
```

Re-running `flux bootstrap` is not destructive — it will update Flux in place — but it commits changes to `flux-system/` and re-deploys the controllers.

## Flux Not Picking Up Changes From Git

Check the GitRepository source status:

```bash
flux get source git flux-system -n flux-system
```

If the last fetched commit is outdated, force a reconcile:

```bash
flux reconcile source git flux-system -n flux-system
```

Then reconcile the root kustomization:

```bash
flux reconcile kustomization flux-system
```

## HelmRelease Fails To Install Or Upgrade

Check the HelmRelease status:

```bash
flux get helmrelease <name> -n <namespace>
kubectl describe helmrelease <name> -n <namespace>
```

Check the helm-controller logs for the specific failure:

```bash
kubectl logs -n flux-system deploy/helm-controller | grep <name>
```

Common causes:

- chart version does not exist in the repository
- values are invalid for the chart version
- namespace does not exist (each component directory includes a `namespace.yaml`)
- a dependency pod (e.g. 1Password Connect) is not yet running

## MetalLB BGP Not Advertising Routes

See [MetalLB BGP](metallb-bgp.md) for the full BGP troubleshooting section. Quick checks:

```bash
kubectl get bgppeer -n metallb
kubectl get bgpadvertisement -n metallb
kubectl get ipaddresspool -n metallb
kubectl get pods -n metallb
```

## Terraform Provisioner Output Suppressed

When sensitive environment variables (like `OP_TOKEN` or `OP_CREDENTIALS_JSON`) are passed to a `local-exec` provisioner, Terraform/OpenTofu suppresses the provisioner output in the terminal. This is expected behavior.

To see debug output, set the `TF_LOG` environment variable before running `tofu apply`:

```bash
TF_LOG=DEBUG tofu apply 2>debug.log
```

Then inspect `debug.log` for the provisioner execution details.
