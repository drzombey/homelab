# Infrastructure Upgrades

## Current Upgrade Model

With the Talos provider version used in this repo, there is no dedicated in-place Talos OS upgrade resource.

That means:

- `talos_machine_configuration_apply` updates configuration only
- Talos OS upgrades are modeled in this repo as rolling node replacement

## Rolling Replace Upgrade

### How It Works

- each node can define `talos_config.version`
- each node can define `rollout_generation`
- a node is replaced when its rollout trigger changes
- nodes with `rollout_generation = 0` keep using the legacy ISO name
- nodes with `rollout_generation > 0` use a versioned ISO name like `talos-1.12.6-nocloud-amd64.iso`

## Recommended Order

1. worker nodes one by one
2. verify workload and storage health after each worker
3. controlplane nodes one by one
4. never replace multiple controlplane nodes at once

## Single Worker Upgrade Example

Current node:

```hcl
node04 = {
  type      = "worker"
  node_name = "proxmox"
  talos_config = {
    version = "v1.12.0"
  }
  rollout_generation = 0
}
```

Upgrade node04:

```hcl
node04 = {
  type      = "worker"
  node_name = "proxmox"
  talos_config = {
    version = "v1.12.6"
  }
  rollout_generation = 1
}
```

Then run:

```bash
tofu plan
tofu apply
```

For the next upgrade of the same node, increment again:

```hcl
rollout_generation = 2
```

## Controlplane Upgrade Example

Upgrade only one controlplane at a time:

```hcl
node01 = {
  type      = "controlplane"
  node_name = "proxmox"
  talos_config = {
    version = "v1.12.6"
  }
  rollout_generation = 1
}
```

Wait until:

- Talos node is healthy
- Kubernetes node is `Ready`
- etcd quorum is healthy

Then continue with the next controlplane.

## PVC And Storage Guidance

PVC handling depends on the storage backend.

### Usually Safe

Rolling replacement is usually safe if PVCs use:

- Longhorn
- Ceph / Rook
- NFS
- iSCSI-backed shared storage
- any replicated or network-backed storage

Recommended sequence:

1. cordon node
2. drain node safely
3. verify storage health and replica status
4. replace the node
5. wait until workloads and storage return healthy
6. continue with the next node

### Risky

Be careful if workloads use local-only storage or local PVs.

In that case:

- replacing a node can strand data on the old node
- in-place upgrade is often safer than replacement
- migration planning is required before touching the node

## Suggested Upgrade Runbook

1. verify cluster health
2. verify storage health
3. choose one worker
4. cordon and drain it
5. update `talos_config.version`
6. increment `rollout_generation`
7. run `tofu plan`
8. run `tofu apply`
9. wait until node and workloads are healthy again
10. repeat for remaining workers
11. repeat for controlplanes one by one

## In-Place Upgrade Discussion

Talos itself supports in-place OS upgrades, typically with `talosctl upgrade`, but this repo does not currently model that path in OpenTofu.

So today:

- supported and documented path in this repo: rolling replace
- possible outside this repo: `talosctl`-driven in-place upgrades
