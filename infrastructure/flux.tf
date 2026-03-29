# Flux bootstrap via local-exec
# Verwendet eine GitHub App für Authentifizierung — kein PAT wird benötigt.
# Der private Schlüssel der App wird nur einmalig in eine temporäre Datei geschrieben
# und nach dem Bootstrap sofort gelöscht.
resource "terraform_data" "flux_bootstrap" {
  triggers_replace = {
    owner = var.github_owner
    repo  = var.github_repository
    path  = "clusters/homelab"
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      KUBECONFIG_CONTENT     = module.kubernetes.talos_kubeconfig
      GITHUB_APP_PRIVATE_KEY = var.github_app_private_key
    }
    command = <<-BASH
      set -euo pipefail
      TMPKUBE=$(mktemp)
      TMPKEY=$(mktemp)
      trap "rm -f $TMPKUBE $TMPKEY" EXIT
      printf '%s' "$KUBECONFIG_CONTENT" > "$TMPKUBE"
      chmod 600 "$TMPKUBE"
      printf '%s' "$GITHUB_APP_PRIVATE_KEY" > "$TMPKEY"
      chmod 600 "$TMPKEY"
      KUBECONFIG="$TMPKUBE" flux bootstrap github \
        --owner="${var.github_owner}" \
        --repository="${var.github_repository}" \
        --branch=main \
        --path=clusters/homelab \
        --app-id="${var.github_app_id}" \
        --app-installation-id="${var.github_app_installation_id}" \
        --app-private-key="$TMPKEY"
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
