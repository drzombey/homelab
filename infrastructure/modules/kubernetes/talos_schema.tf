data "talos_image_factory_extensions_versions" "this" {
  talos_version = var.talos_version
  filters = {
    names = [
      "i915-ucode",       # see https://github.com/siderolabs/talos/issues/9776
      "intel-ucode",      # see https://github.com/siderolabs/talos/issues/9776
      "iscsi-tools",      # for longhorn
      "mei",              # see https://github.com/siderolabs/talos/issues/9776
      "qemu-guest-agent", # for proxmox
    ]
  }
}

resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode(
    {
      customization = {
        systemExtensions = {
          officialExtensions = data.talos_image_factory_extensions_versions.this.extensions_info.*.name
        }
      }
    }
  )
}
