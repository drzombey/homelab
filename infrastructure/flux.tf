# Flux bootstrap via local-exec
# Verwendet den Token der lokal eingeloggten gh CLI — kein separates Secret nötig.
# Nach dem Bootstrap verwendet Flux den angelegten SSH Deploy Key für
# alle weiteren Git-Operationen. Der Token verbleibt nicht im Cluster.
resource "terraform_data" "flux_bootstrap" {
  triggers_replace = {
    owner = var.github_owner
    repo  = var.github_repository
    path  = "clusters/homelab"
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      KUBECONFIG_CONTENT = module.kubernetes.talos_kubeconfig
    }
    command = <<-BASH
      set -euo pipefail
      TMPKUBE=$(mktemp)
      trap "rm -f $TMPKUBE" EXIT
      printf '%s' "$KUBECONFIG_CONTENT" > "$TMPKUBE"
      chmod 600 "$TMPKUBE"

      KUBECONFIG="$TMPKUBE" GITHUB_TOKEN="$(gh auth token)" flux bootstrap github \
        --owner="${var.github_owner}" \
        --repository="${var.github_repository}" \
        --branch=main \
        --path=clusters/homelab \
        --personal
    BASH
  }

  depends_on = [module.kubernetes]
}

# Bootstrap Secrets werden vor dem ersten Flux-Sync angelegt:
#   op-token       → External Secrets Operator → 1Password Connect Auth
#   op-credentials → 1Password Connect Server  → 1Password.com Auth
#
# Idempotent via --dry-run=client | kubectl apply
resource "terraform_data" "bootstrap_secrets" {
  triggers_replace = {
    op_token_hash       = sha256(var.op_connect_token)
    op_credentials_hash = sha256(var.op_credentials_json)
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      KUBECONFIG_CONTENT  = module.kubernetes.talos_kubeconfig
      OP_TOKEN            = var.op_connect_token
      OP_CREDENTIALS_JSON = var.op_credentials_json
    }
    command = <<-BASH
      set -euo pipefail
      TMPKUBE=$(mktemp)
      trap "rm -f $TMPKUBE" EXIT
      printf '%s' "$KUBECONFIG_CONTENT" > "$TMPKUBE"
      chmod 600 "$TMPKUBE"

      # Namespaces anlegen (idempotent)
      for ns in external-secrets connect; do
        KUBECONFIG="$TMPKUBE" kubectl create namespace "$ns" \
          --dry-run=client -o yaml | KUBECONFIG="$TMPKUBE" kubectl apply -f -
      done

      # op-token für External Secrets Operator
      KUBECONFIG="$TMPKUBE" kubectl create secret generic op-token \
        --from-literal=token="$OP_TOKEN" \
        --namespace=external-secrets \
        --dry-run=client -o yaml | KUBECONFIG="$TMPKUBE" kubectl apply -f -

      # op-credentials für 1Password Connect Server
      printf '%s' "$OP_CREDENTIALS_JSON" | \
        KUBECONFIG="$TMPKUBE" kubectl create secret generic op-credentials \
          --from-file=1password-credentials.json=/dev/stdin \
          --namespace=connect \
          --dry-run=client -o yaml | KUBECONFIG="$TMPKUBE" kubectl apply -f -
    BASH
  }

  depends_on = [terraform_data.flux_bootstrap]
}
