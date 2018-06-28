{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.virtualbox;

in {

  options = {
    virtualbox = {
      baseImageSize = mkOption {
        type = types.int;
        default = 10 * 1024;
        description = ''
          The size of the VirtualBox base image in MiB.
        '';
      };
      memorySize = mkOption {
        type = types.int;
        default = 1536;
        description = ''
          The amount of RAM the VirtualBox appliance can use in MiB.
        '';
      };
      vmDerivationName = mkOption {
        type = types.string;
        default = "nixos-ova-${config.system.nixos.label}-${pkgs.stdenv.system}";
        description = ''
          The name of the derivation for the VirtualBox appliance.
        '';
      };
      vmName = mkOption {
        type = types.string;
        default = "NixOS ${config.system.nixos.label} (${pkgs.stdenv.system})";
        description = ''
          The name of the VirtualBox appliance.
        '';
      };
      vmFileName = mkOption {
        type = types.string;
        default = "nixos-${config.system.nixos.label}-${pkgs.stdenv.system}.ova";
        description = ''
          The file name of the VirtualBox appliance.
        '';
      };
    };
  };

  config = {
    # system.build.virtualBoxOVA = import ../../lib/make-disk-image.nix {
    system.build.virtualBoxOVA = import ./make-disk-image.nix {
      name = cfg.vmDerivationName;

      inherit pkgs lib config;
      partitionTableType = "legacy";
      diskSize = cfg.baseImageSize;

      postVM =
        ''
          export HOME=$PWD
          export PATH=${pkgs.virtualbox}/bin:$PATH

          echo "creating VirtualBox pass-through disk wrapper (no copying invovled)..."
          VBoxManage internalcommands createrawvmdk -filename disk.vmdk -rawdisk $diskImage

          echo "creating VirtualBox VM..."
          vmName="${cfg.vmName}";
          VBoxManage createvm --name "$vmName" --register \
            --ostype ${if pkgs.stdenv.system == "x86_64-linux" then "Linux26_64" else "Linux26"}
          VBoxManage modifyvm "$vmName" \
            --memory ${toString cfg.memorySize} --acpi on --vram 32 \
            ${optionalString (pkgs.stdenv.system == "i686-linux") "--pae on"} \
            --nictype1 virtio --nic1 nat \
            --audiocontroller ac97 --audio alsa \
            --rtcuseutc on \
            --usb on --mouse usbtablet
          VBoxManage storagectl "$vmName" --name SATA --add sata --portcount 4 --bootable on --hostiocache on
          VBoxManage storageattach "$vmName" --storagectl SATA --port 0 --device 0 --type hdd \
            --medium disk.vmdk

          echo "exporting VirtualBox VM..."
          mkdir -p $out
          fn="$out/${cfg.vmFileName}"
          VBoxManage export "$vmName" --output "$fn"

          rm -v $diskImage

          mkdir -p $out/nix-support
          echo "file ova $fn" >> $out/nix-support/hydra-build-products
        '';
    };

    fileSystems."/" = {
      device = "/dev/disk/by-label/nixos";
      autoResize = true;
    };

    boot.growPartition = true;
    boot.loader.grub.device = "/dev/sda";

    virtualisation.virtualbox.guest.enable = true;

  };
}
