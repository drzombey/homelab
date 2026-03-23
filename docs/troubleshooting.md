# Troubleshooting

## OpenTofu

### Slow `tofu plan`

Possible causes:

- Proxmox VM refresh is slow
- many VM resources are being refreshed

Useful check:

```bash
tofu plan -refresh=false
```

### Interrupted Apply Left A State Lock

If no other OpenTofu process is still running:

```bash
tofu force-unlock <LOCK_ID>
```

## Talos

### Talos Node Got DHCP Instead Of Static IP

Check:

- `talos_config.endpoint`
- network patch template rendering
- whether the NIC MAC changed after node replacement

### Talos Config Apply Fails With Hostname Conflict

Do not set a static hostname twice in Talos patches. The repo already avoids this in the shared network template.

### `talosctl` Cannot Determine Endpoints

If you see `failed to determine endpoints`, you likely set only `-n` and not `-e`.

Use both:

```bash
talosctl -e 10.0.40.10 -n 10.0.40.10 version
```

Or make sure `TALOSCONFIG` points to `~/.talos/config`.

## Proxmox

### Apply Fails With `ide2` Hotplug Or Media Type Error

This repo mitigates that by ignoring later Proxmox `initialization` changes on existing VMs.

## Practical Tips

- keep `talos_config.endpoint` set explicitly when recovering a node whose IP changed unexpectedly
- upgrade workers before controlplanes
- keep controlplane upgrades strictly one-by-one
- export `kubeconfig` and `talosconfig` after bootstrap for daily operations
