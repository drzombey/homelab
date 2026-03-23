# MetalLB BGP On OPNsense

This documents the current homelab MetalLB setup.

## Network Layout

- main LAN: `10.0.30.0/24`
- VM and Kubernetes node network: `10.0.40.0/24`
- OPNsense VMNET gateway: `10.0.40.1`
- MetalLB service pool: `10.0.50.100-10.0.50.150`

The Kubernetes nodes already run in the VM network, so BGP peering happens on `10.0.40.0/24`. The MetalLB service IPs use a separate routed range and are not assigned to any Proxmox bridge, switch port, or OPNsense interface.

## Files

- `cluster-infrastructure/hack/helm/metallb/values.yaml` enables FRR mode in the MetalLB speaker
- `cluster-infrastructure/hack/helm/metallb/bgp.yaml` defines the BGP peer, service pool, and advertisement

## Configuration Summary

- OPNsense FRR local ASN: `64512`
- MetalLB peer ASN: `64513`
- BGP peer address from MetalLB: `10.0.40.1`
- Kubernetes node peer addresses on OPNsense: `10.0.40.10-10.0.40.14`

## OPNsense Setup

1. Install the `os-frr` plugin.
2. Enable FRR and BGP.
3. Set the FRR router ID to `10.0.40.1`.
4. Set the local ASN to `64512`.
5. Add one BGP neighbor for each Kubernetes node in `10.0.40.0/24` with remote ASN `64513`.
6. On the `VMNET` interface, allow `TCP/179` from the Kubernetes nodes to `This Firewall`.

Expected result:

- `vtysh -c "show bgp summary"` shows all Kubernetes neighbors in `Established`
- `vtysh -c "show bgp ipv4 unicast"` shows `/32` routes for MetalLB service IPs

## Kubernetes Setup

1. Install MetalLB with Helm.
2. Use the values from `cluster-infrastructure/hack/helm/metallb/values.yaml`.
3. Apply `cluster-infrastructure/hack/helm/metallb/bgp.yaml`.

Example:

```bash
helm repo add metallb https://metallb.github.io/metallb
helm repo update
helm upgrade --install metallb metallb/metallb \
  --namespace metallb \
  --create-namespace \
  -f cluster-infrastructure/hack/helm/metallb/values.yaml

kubectl apply -f cluster-infrastructure/hack/helm/metallb/bgp.yaml
```

## Pod Security Requirement

The FRR-based MetalLB speaker needs `hostNetwork`, host ports, and additional capabilities. In this cluster the `speaker` DaemonSet was blocked by Pod Security in the `metallb` namespace until the namespace was labeled as `privileged`.

Apply:

```bash
kubectl label namespace metallb \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/audit=privileged \
  pod-security.kubernetes.io/warn=privileged \
  --overwrite
```

If the `speaker` pods were already failing to schedule, restart the DaemonSet after labeling the namespace:

```bash
kubectl rollout restart ds metallb-speaker -n metallb
```

## Verify

Check that the speaker is running on all nodes:

```bash
kubectl get ds -n metallb
kubectl get pods -n metallb -o wide
```

Check BGP on OPNsense:

```bash
vtysh -c "show bgp summary"
vtysh -c "show bgp ipv4 unicast"
vtysh -c "show ip route"
```

Create a test service:

```bash
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port 80 --type LoadBalancer
kubectl get svc
```

Expected result:

- the service gets an external IP from `10.0.50.100-10.0.50.150`
- OPNsense learns a route to that IP via one or more Kubernetes nodes
- the service is reachable from the LAN through OPNsense

## Troubleshooting

- If neighbors stay in `Active`, check that the `metallb-speaker` DaemonSet has running pods and that `TCP/179` is allowed on OPNsense.
- If the `speaker` DaemonSet shows `Desired > 0` but `Current = 0`, inspect `kubectl describe ds metallb-speaker -n metallb` for Pod Security or taint errors.
- If the service has an external IP but no route is learned, confirm the service has healthy endpoints with `kubectl get endpoints -A`.
- The FRR `SO_RCVBUF` and `SO_SNDBUF` warnings seen on OPNsense were harmless in this setup and did not block peering.
