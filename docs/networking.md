# Networking

## Current Homelab Network Layout

- `10.0.30.0/24` is the main LAN
- `10.0.40.0/24` is the VM and Kubernetes node network
- `vmbr0` carries Proxmox management on `10.0.30.5/24`
- `vmbrWAN` is connected directly to the fiber WAN handoff
- `vmbrLAN` and `vmbrLAN2` are mapped into an OPNsense `bridge0` for the main LAN

## Network Summary

| Network | Purpose | Notes |
| --- | --- | --- |
| `10.0.30.0/24` | Main LAN | Used by regular clients, Wi-Fi, and Proxmox management. Routed by OPNsense on `bridge0`. |
| `10.0.40.0/24` | VM and Kubernetes node network | Used by isolated VMs and Talos Kubernetes nodes on `VLAN 40`. Routed by OPNsense on `vlan0.40`. |
| `10.0.50.100-10.0.50.150` | MetalLB service pool | Used only for Kubernetes `LoadBalancer` service IPs announced over BGP. Not assigned to a bridge or interface. |

## Proxmox Bridge Layout

- `vmbr0`: Proxmox management only
- `vmbrWAN`: OPNsense WAN uplink
- `vmbrLAN`: internal LAN uplink to the managed switch
- `vmbrLAN2`: internal LAN uplink that currently feeds the access point

`vmbrLAN` and `vmbrLAN2` are bridged together inside OPNsense through `bridge0`, which carries the untagged main LAN on `10.0.30.0/24`.

## OPNsense Interface Layout

- `bridge0`: main LAN interface with `10.0.30.1/24`
- `vlan0.40`: VM network interface with `10.0.40.1/24`
- `vtnet0` or equivalent WAN interface: internet uplink

The VM network is intentionally not part of `bridge0`. It is routed by OPNsense as a separate network.

## Switch Design

The managed switch carries:

- untagged main LAN traffic for `10.0.30.0/24`
- tagged `VLAN 40` traffic for `10.0.40.0/24`

The switch port facing Proxmox is configured as:

- `VLAN 1` untagged for the main LAN
- `VLAN 40` tagged for the VM network
- `PVID 1`

Normal client-facing ports remain untagged in the main LAN unless a device needs direct access to a tagged VLAN.

## Proxmox VM Placement

- normal LAN VMs: attach NICs to `vmbrLAN` without a VLAN tag
- VM network workloads: attach NICs to `vmbrLAN` with VLAN tag `40`
- Kubernetes nodes: attach NICs to `vmbrLAN` with VLAN tag `40`

Example Kubernetes node settings used in this repo:

- bridge: `vmbrLAN`
- VLAN tag: `40`
- node IPs: `10.0.40.10-10.0.40.14`
- gateway: `10.0.40.1`
- DNS: `10.0.40.1`

## OPNsense Setup Steps

1. Keep the main LAN on `bridge0` with `10.0.30.1/24`.
2. Enable VLAN support on the Proxmox-side LAN path.
3. Create `VLAN 40` on the physical LAN member interface behind `vmbrLAN`.
4. Assign the VLAN as a new interface in OPNsense.
5. Set the new interface IP to `10.0.40.1/24`.
6. Enable DHCP on the interface if non-Talos VMs need dynamic addresses.
7. Add firewall rules that allow VMNET traffic to the destinations you want.

For Kubernetes nodes in this repo, the IPs are statically assigned by Talos and use OPNsense as gateway and DNS.

## Firewall Notes

Useful rules on the `VMNET` interface:

- allow `TCP/179` from Kubernetes nodes to `This Firewall` for MetalLB BGP
- allow DNS from `10.0.40.0/24` to `10.0.40.1`
- allow outbound traffic from `10.0.40.0/24` as needed
- optionally block access from `10.0.40.0/24` to `10.0.30.0/24` except for explicit exceptions

If VM workloads lose name resolution after network isolation, check whether a broad block rule is also blocking DNS to `10.0.40.1` or to another DNS server in the main LAN.

## Why The Main LAN Is Still Untagged

The current setup keeps `10.0.30.0/24` untagged and only tags `VLAN 40`.

That keeps the working LAN stable while still allowing clean separation for VMs and Kubernetes nodes. Moving the main LAN into its own VLAN is possible later, but it is not required for the current design.
