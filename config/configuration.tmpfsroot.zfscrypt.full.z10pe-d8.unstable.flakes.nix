# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

# This config is a hybrid of "Erase Your Darlings" and "Tmpfs as Root", with 
# tmpfs on /, UEFI /boot/efi on a FAT32 partition, and all other filesystems on 
# ZFS pools.  Rebooting automatically wipes and rebulds /, ensuring a clean 
# root with minimal cruft buildup, but without the extra drive wear from doing 
# regular zfs rollbacks to the /@blank snapshot (had / also been on a ZFS pool).
#
# TODO:  Move /boot to its own ZFS dataset, and move /boot/efi to a USB drive.
# Goal is to allow ZFS to control the full disk, by moving the /boot/efi FAT32
# partition to USB drive.  Also provdes an extra security layer, system can't
# boot without the USB drive.
#
# Details:
# https://nixos.wiki/wiki/NixOS_on_ZFS
# https://grahamc.com/blog/nixos-on-zfs
# https://grahamc.com/blog/erase-your-darlings
# https://elis.nu/blog/2020/05/nixos-tmpfs-as-root/
# https://elis.nu/blog/2019/08/encrypted-zfs-mirror-with-mirrored-boot-on-nixos/
# https://jrs-s.net/2018/08/17/zfs-tuning-cheat-sheet

{ config, pkgs, ... }:

{

  ################################################################################
  # System 
  ################################################################################

  imports = [ # Include the results of the hardware scan.
    ./hardware-configuration.nix
    #./configuration.z10pe-d8.nix
    #./patches/lutris-patch.nix  # fixed in 22.05; # 21.11: use an overlay to update the version instead, bug is fixed in latest version
  ];
  
  # https://nixos.wiki/wiki/Storage_optimization
  nix = {
    package = pkgs.nixFlakes;
    settings.cores = 2;
    settings.auto-optimise-store = true;
    # garbage collect weekly
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 60d";
    };
    # enable flakes
    # garbage collect when less than 100MiB
    extraOptions = ''
      experimental-features = nix-command flakes 
      min-free = ${toString (100 * 1024 * 1024)}
      max-free = ${toString (1024 * 1024 * 1024)}
    '';
  };

  # fixed in 22.05
  #nixpkgs.overlays = [
  #  ( import ./overlays/lutris-overlay.nix )
  #];

  # Default nixPath.  Uncomment and modify to specify non-default nixPath
  # https://search.nixos.org/options?query=nix.nixPath
  #nix.nixPath =
  #  [
  #    "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
  #    "nixos-config=/etc/nixos/configuration.nix"
  #    "/nix/var/nix/profiles/per-user/root/channels"
  #  ];

  # Enable non-free packages (Nvidia driver, etc)
  # Reboot after rebuilding to prevent possible clash with other kernel modules
  nixpkgs.config = { allowUnfree = true; };

  # nixos-rebuild will snapshot the new configuration.nix to 
  # /run/current-system/configuration.nix
  # With this enabled, every new system profile contains the configuration.nix
  # that created it.  Useful in troubleshooting broken build, just diff 
  # current vs prior working configurion.nix.  This will only copy configuration.nix
  # and no other imported files, so put all config in this file.  
  # Configuration.nix should have no imports besides hardware-configuration.nix.
  # https://search.nixos.org/options?query=system.copySystemConfiguration
  system.copySystemConfiguration = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.05"; # Did you read the comment?

  #Auto Updates & Upgrades
  # https://nixos.org/manual/nixos/stable/index.html#sec-upgrading-automatic  
  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
    channel = "https://nixos.org/channels/nixos-unstable";
  };

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  time.timeZone = "America/Los_Angeles";

  # Good for laptop battery
  #services.tlp.enable = true;

  ################################################################################
  # System TODO:
  ################################################################################

  # 1.  Hardening
  # - https://nixos.wiki/wiki/Systemd_Hardening
  # - https://github.com/alegrey91/systemd-service-hardening
  # - https://christine.website/blog/paranoid-nixos-2021-07-18
  # - https://restoreprivacy.com/firefox-privacy/
  # - https://www.sshaudit.com/hardening_guides.html
  # - https://madaidans-insecurities.github.io/linux.html
  # - https://madaidans-insecurities.github.io/guides/linux-hardening.html
  # - https://madaidans-insecurities.github.io/security-privacy-advice.html
  # - https://www.reddit.com/r/linuxquestions/comments/pendlc/what_can_a_beginner_do_to_secure_their_system/hayyat2/
  # - https://www.reddit.com/r/linuxquestions/comments/pendlc/what_can_a_beginner_do_to_secure_their_system/haykpwu/
  # - dnsmasq: https://github.com/NixOS/nixpkgs/issues/61617

  ################################################################################
  # Boot
  ################################################################################

  # Enable sshd during boot, useful for troubleshooting remote server boot 
  # problems.  Shuts down after stage-1 boot is finished. 
  # https://search.nixos.org/options?channel=21.05&show=boot.initrd.network.ssh.enable&query=sshd
  #boot = {
  #	included in boot section below
  #};

  # import /persist into initial ramdisk so that tmpfs can access persisted data like user passwords
  # https://www.reddit.com/r/NixOS/comments/o1er2p/tmpfs_as_root_but_without_hardcoding_your/h22f1b9/
  # https://search.nixos.org/options?channel=21.05&show=fileSystems.%3Cname%3E.neededForBoot&query=fileSystems.%3Cname%3E.neededForBoot
  fileSystems."/persist".neededForBoot = true;

  # only use this for testing, required for building broken packages
  #nixpkgs.config.allowBroken = true;

  # Use EFI boot loader with Grub.
  # https://nixos.org/manual/nixos/stable/index.html#sec-installation-partitioning-UEFI
  boot = {
    # use the lastest kernel if possible, rather than stable.  
    # make sure this is option not repeated in ZFS or Nvidia sections below
    # https://nixos.wiki/wiki/Linux_kernel
    #kernelPackages = pkgs.linuxPackages_latest;  # currently 5.15
    kernelPackages =
      config.boot.zfs.package.latestCompatibleLinuxPackages; # available in NixOS 21.11
    #kernelPackages = pkgs.linuxPackages_5_14; # latest kernel compatible with this build's ZFS v2.0.6-1; use with 21.05

    # specialized kernels
    #kernelPackages = pkgs.linuxPackages_xen;
    #kernelPackages = pkgs.linuxPackages_xanmod;
    #kernelPackages = pkgs.linuxPackages_latest-libre; 

    # old
    #kernelPackages = pkgs.linuxPackages_5_13;  # EOL 9/18/21, removed from nixpkgs
    #kernelPackages = pkgs.linuxPackages_5_12;  # EOL 7/20/21, removed from nixpkgs
    #kernelPackages = pkgs.linuxPackages;  # 5.10

    # broken 
    #kernelPackages = config.zfs.package.latestCompatibleLinuxPackages;  # broken
    #kernelPackages = config.zfs.pkgs.latestCompatibleLinuxPackages;  # broken
    #kernelPackages = zfs.package.latestCompatibleLinuxPackages;  # broken
    #kernelPackages = pkgs.zfs.latestCompatibleLinuxPackages;  # broken

    supportedFilesystems = [ "vfat" "zfs" ];
    initrd = {
      network.ssh.enable = true;
      supportedFilesystems = [ "vfat" "zfs" ];
    };
    zfs = {
      requestEncryptionCredentials = true; 
      # enable if using ZFS encryption, ZFS will prompt for password during boot
      # TODO: import and mount dpoolX at boot.  Currently no timeout limit, need 1m30s like other boot timeouts. 
      # Requires keyformat=password,keylocation=file:///etc/zfs/dpool0 (or keylocation=file:///persist/etc/zfs/dpool0)
      # https://search.nixos.org/options?channel=21.05&show=boot.zfs.extraPools&from=0&size=50&sort=relevance&query=zfs
      #extraPools = [ "dpool0" ];  # use for pools not legacy mounted. 
    };
    loader = {
      #systemd-boot.enable = true;  # redundant with grub bootloader, disallowed in 22.05
      efi = {
        #canTouchEfiVariables = true;  # must be disabled if efiInstallAsRemovable=true
        #efiSysMountPoint = "/boot/efi";  # using the default /boot for this config
      };
      grub = {
        enable = true;
        device = "nodev"; # "/dev/sdx", or "nodev" for efi only
        efiSupport = true;
        efiInstallAsRemovable =
          true; # grub will use efibootmgr; mutually exclusive with canTouchEfiVariables
        zfsSupport = true;
        copyKernels = true; # https://nixos.wiki/wiki/NixOS_on_ZFS
      };
    };
  };
  
  ################################################################################
  # ECC RAM
  ################################################################################
  
  # Rasdaemon ECC monitor
  # https://news.ycombinator.com/item?id=34303386
  # https://www.setphaserstostun.org/posts/monitoring-ecc-memory-on-linux-with-rasdaemon/
  hardware.rasdaemon = {
    enable = true;
    mainboard = "z10pe-d8";
  };
  
  ################################################################################
  # ZFS
  ################################################################################

  # Set the disk’s scheduler to none. ZFS takes this step automatically 
  # if it controls the entire disk, but since it doesn't control the /boot 
  # partition we must set this explicitly.
  # source: https://grahamc.com/blog/nixos-on-zfs
  #boot.kernelParams = [ "elevator=none" ];
  # Kernel parameter elevator= does not have any effect anymore.
  # Please use sysfs to set IO scheduler for individual devices.
  # TODO: system.activationScripts = { #sysfs set disk IO scheduler to none }
  # https://gist.github.com/mx00s/ea2462a3fe6fdaa65692fe7ee824de3e
  # https://www.reddit.com/r/zfs/comments/iluh00/zfs_linux_io_scheduler/g3uxm3m/
  # https://github.com/cole-h/nixos-config/blob/3589d53515921772867065150c6b5a500a5b9a6b/hosts/scadrial/modules/services.nix#L70
  #services.udev.extraRules = ''
  #  KERNEL=="sd[a-z]*[0-9]*|mmcblk[0-9]*p[0-9]*|nvme[0-9]*n[0-9]*p[0-9]*", ENV{ID_FS_TYPE}=="zfs_member", ATTR{../queue/scheduler}="none"
  #'';

  services.zfs = {
    trim.enable = true;
    autoScrub.enable = true;
    autoSnapshot = {
      enable = true;
      # number of each type of snapshot to keep
      frequent = 0;
      hourly = 0;
      daily = 2;
      weekly = 3;
      monthly = 4;
      # -k = keep zero-sized snapshots, -p = create snapshots in parallel, 
      # and use UTC time format to avoid duplicates on daylights savings day
      flags = "-k -p --utc";
    };
    # TODO: autoReplication to separate backup device, use zfs-send to send
    # encrypted pools
  };

  ################################################################################
  # ZRAM  # deprecated in 23.05, to be replaced with pkgs.zram-generator
  ################################################################################

  # https://search.nixos.org/options?channel=21.05&query=zram
  # https://www.maketecheasier.com/zram-zcache-zswap/
  # https://askubuntu.com/questions/471912/zram-vs-zswap-vs-zcache-ultimate-guide-when-to-use-which-one
  zramSwap = {
    enable = true;
    algorithm = "zstd"; # zstd is default
    priority = 5;  # 5 is default, just needs to be higher than disk cache
    swapDevices = 1;  # default = 1
    memoryPercent = 50; # default = 50.  use zramctl for info.
    #memoryMax = ;  # let memoryPercent handle this
  };

  ################################################################################
  # Networking
  ################################################################################

  # alternate systemd option
  #systemd.network.enable = true
  #networking.useNetworkd = true  # probably mutually exclusive with above

  networking = {
    networkmanager.enable = true;
    #hostId = "$(head -c 8 /etc/machine-id)";  # required by zfs. hardware-specific, set in hardware-configuration.nix
    #hostName = "";  # hardware-specific, set in hardware-configuration.nix
    # also need to move interfaces = { ... }; section to hardware-configuration.nix
    # sed '\:// START TEXT:,\:// END TEXT:d' file
    # https://serverfault.com/questions/137829/how-to-remove-a-tagged-block-of-text-in-a-file

    #wireless.enable = true;  # Wireless via wpa_supplicant. Unecessary with Gnome & KDE, 
    # but necessary with others that don't provide this.

    # The global useDHCP flag is deprecated, therefore explicitly set to false here.
    # Per-interface useDHCP will be mandatory in the future, so this generated config
    # replicates the default behaviour.
    # (hardware-specific, needs to be in hardware-configuration.nix, but won't build,
    # networking.interfaces property not recognized in that file)

    #z10pe-d8 network interfaces
    useDHCP = false;
    interfaces = {
      #enp6s0.useDHCP = true;
      #enp7s0.useDHCP = true;
      enp8s0.useDHCP = true;
      enp9s0.useDHCP = true;
      wlp2s0u1.useDHCP = true;  # Panda USB network adapter
      wlp129s0.useDHCP = true;  # Asus RT-88 PCI card
      #wlp130s0.useDHCP = true;  # Asus RT-88 PCI card (old)
    };

    # Open ports in the firewall.
    firewall = {
      # allowedTCPPorts = [ ... ];
      # allowedUDPPorts = [ ... ];
      # Or disable the firewall altogether.
      enable = true;
      allowPing = true;

      # always allow traffic from your Tailscale network
      trustedInterfaces = [ "tailscale0" ];

      # allow the Tailscale and Samba UDP ports through the firewall
      allowedUDPPorts = [ config.services.tailscale.port 22 80 137 138 139 445 ];

      # Port index
      # use `grep -i NETBIOS /etc/services` to find Samba ports
      # 22 = ssh
      # 80 = gnome-remote-desktop
      # 137 = samba
      # 138 = samba
      # 139 = netbios-ssn (samba)
      # 389 = LDAP (Active Directory Mode, may Samba)
      # 445 = microsoft-ds (samba)
      # 631 = ipp
      # 873 = rsyncd
      # 901 = SWAT service (maybe Samba)
      # 3389 = (maybe gnome-remote-desktop?)
      # 5000 = (maybe gnome-remote-desktop?)
      # 6600 = mpd
      # 9090 = (maybe gnome-remote-desktop?)
      # 34445 = unknown (samba?)
      # 60022 = qemu ssh port forwarding
      allowedTCPPorts = [ 22 80 137 138 139 389 445 631 873 901 3389 6600 9090 34445 60022 ];

      # needed for mullvad-vpn app and daemon
      # https://github.com/NixOS/nixpkgs/issues/113589#issuecomment-893233499
      # TODO: fix conflict with Mulvad wireguard.  FIX: https://discourse.nixos.org/t/anyone-running-both-mullvad-and-tailscale-both-wireguard/17136
      # This is automatically set to loose when services.mullvad.enable = true:  https://search.nixos.org/options?channel=22.05&show=services.mullvad-vpn.enable&from=0&size=50&sort=relevance&type=packages&query=mullvad
      #checkReversePath = "loose";  # may kill internet connection

    };

    # Configure network proxy if necessary
    #proxy = {
    # default = "http://user:password@proxy:port/";
    # noProxy = "127.0.0.1,localhost,internal.domain";
    #};

  };

  # Mullvad
  # reqs:  https://github.com/NixOS/nixpkgs/issues/113589#issuecomment-893233499
  services.mullvad-vpn.enable = true;
  
  # how to use tailscale with mullvad:
  # https://discourse.nixos.org/t/anyone-running-both-mullvad-and-tailscale-both-wireguard/17136
  # 1. allow the tailscale daemon to bypass the VPN
      # $> mullvad split-tunnel pid add (pgrep tailscaled)
  # 2. SSH through tailscale
      # $> sudo mullvad-exclude ssh remoteuser@remotetailscaleip

  # Avahi (LAN DNS)
  # https://www.reddit.com/r/linuxquestions/comments/m8bwxi/is_there_a_solution_for_offline_decentralized/grgi3el/
  services.avahi = {
    enable = true;
    nssmdns = true;
    openFirewall = true;
    #hostName = ;
    #package = ;
    #cacheEntriesMax
    #allowInterfaces
    #denyInterfaces
    #wideArea
    #reflector
    #ipv6
    #ipv4
    #domainName
    #browseDomains
    #allowPointToPoint
    #publish = {
    #  workstation = ;
    #  userServices = ;
    #  hinfo = ;
    #  enable = ;
    #  domain = ;
    #  addresses = ;
    #};
    #extraConfig = "";
    #extraServiceFiles = {};
  };

  # Firejail (similar to Opensnitch) - use bubblewrap instead, doesn't require root
  # Namespace-based sandboxing tool for Linux
  # https://search.nixos.org/options?channel=21.05&show=programs.firejail.wrappedBinaries&query=firejail
  #programs.firejail = {
  #  enable = true;
  #  wrappedBinaries = {
  #	  firefox = {
  #      executable = "${lib.getBin pkgs.firefox}/bin/firefox";
  #      profile = "${pkgs.firejail}/etc/firejail/firefox.profile";
  #    };
  #    mpv = {
  #      executable = "${lib.getBin pkgs.mpv}/bin/mpv";
  #      profile = "${pkgs.firejail}/etc/firejail/mpv.profile";
  #    };
  #  };
  #};

  services.opensnitch.enable = true; # 21.11

  # bubblewrap not a service, in systemPackages.

  ################################################################################
  # Persisted Artifacts
  ################################################################################

  #Erase Your Darlings & Tmpfs as Root:
  # config/secrets/etc to be persisted across tmpfs reboots and rebuilds.  This sets up
  # soft-links from /persist/<loc on root> to their expected location on /<loc on root>
  # https://github.com/barrucadu/nixfiles/blob/master/hosts/nyarlathotep/configuration.nix
  # https://grahamc.com/blog/erase-your-darlings
  # https://elis.nu/blog/2020/05/nixos-tmpfs-as-root/

  environment.etc = {

    # /etc/nixos: requires /persist/etc/nixos 
    "nixos".source = "/persist/etc/nixos";

    # user password files
    "users".source = "/persist/etc/users";

    # machine-id is used by systemd for the journal, if you don't persist this 
    # file you won't be able to easily use journalctl to look at journals for 
    # previous boots.  Also required for Tailscale.
    "machine-id".source = "/persist/etc/machine-id";

    # wifi and wired network connections bound to the mac address of this machine's adapater
    "NetworkManager/system-connections".source =
      "/persist/etc/NetworkManager/system-connections/";

    # if you want to run an openssh daemon, you may want to store the host keys 
    # across reboots.
    "ssh/ssh_host_rsa_key".source = "/persist/etc/ssh/ssh_host_rsa_key";
    "ssh/ssh_host_rsa_key.pub".source = "/persist/etc/ssh/ssh_host_rsa_key.pub";
    "ssh/ssh_host_ed25519_key".source = "/persist/etc/ssh/ssh_host_ed25519_key";
    "ssh/ssh_host_ed25519_key.pub".source =
      "/persist/etc/ssh/ssh_host_ed25519_key.pub";
    #"ssh".source = "/persist/etc/ssh/";  # can't use this b/c other ssh files linked here from nix store, this will attempt to overwrite everything in /etc/ssh and will fail

    # Tailscale keys
    # https://tailscale.com/blog/nixos-minecraft/
    "tailscale".source = "/persist/etc/tailscale/";

    # LXC system config
    #"lxc".source = "/persist/etc/lxc/";  # doesn't work, build fails
    #"lxc/default.conf".source = "/persist/etc/lxc/default.conf";  # broken in 21.11
    #"lxc/lxc-usernet".source = "/persist/etc/lxc/lxc-usernet";  # broken in 21.11
    #"lxc/lxc.conf".source = "/persist/etc/lxc/lxc.conf";  # broken in 21.11

    # ZNC confg
    # https://nixos.wiki/wiki/ZNC
    # https://wiki.znc.in/Configuration
    # https://discourse.nixos.org/t/znc-config-without-putting-password-hash-in-configuration-nix/14236
    # ZNC does not support a separate secrets file, but does support separate config file.  Put pwd 
    # hash in the config file and use git secret/nix age/sops/etc to secure it.
    #"znc".source = "/persist/etc/znc/";

    # persist user accounts to /persist/etc, useful for restoring accidentally deleted user account
    # WARNING: must comment this out during initial install.  Can be activated later, but ONLY after
    # copying the respective /etc files into /persist/etc.  Activating before these files are created
    # on first install, and before copying the files into /persist/etc, deletes /etc/passwd and all
    # users with it, locking you out of the system.
    #"passwd".source = "/persist/etc/passwd"; 
    #"shadow".source = "/persist/etc/shadow"; 
    #"group".source = "/persist/etc/group"; 
    #"gshadow".source = "/persist/etc/gshadow";
    #"subgid".source = "/persist/etc/subgid";
    #"subuid".source = "/persist/etc/subuid";

  };

  #2. Wireguard:  requires /persist/etc/wireguard/
  networking.wireguard = {
    enable = true;
    interfaces.wg0 = {
      generatePrivateKeyFile = true;
      privateKeyFile = "/persist/etc/wireguard/wg0";
    };
  };

  #3. Bluetooth: requires /persist/var/lib/bluetooth
  #4. ACME certificates: requires /persist/var/lib/acme  
  #5. LXC/LXD containers  (/persist/var/lib/{lxc,lxd} require 0755 permissions
  #6. NetworkManager files for XMonad: https://mt-caret.github.io/blog/posts/2020-06-29-optin-state.html

  # (/var rules optional if /var gets its own partition on zfs and not on tmpfs
  # persist /var/lib/tailscaled.state and /etc/machine-id to prevent duplicate tailscale machine-ids 
  # from being created on nixos-rebuild.
  systemd.tmpfiles.rules = [
    "L /var/lib/acme - - - - /persist/var/lib/acme"
    "L /var/lib/bluetooth - - - - /persist/var/lib/bluetooth"
    "L /var/lib/tailscale/tailscaled.state - - - - /persist/var/lib/tailscale/tailscaled.state"
    "L /var/lib/NetworkManager/secret_key - - - - /persist/var/lib/NetworkManager/secret_key"
    "L /var/lib/NetworkManager/seen-bssids - - - - /persist/var/lib/NetworkManager/seen-bssids"
    "L /var/lib/NetworkManager/timestamps - - - - /persist/var/lib/NetworkManager/timestamps"
  ];

  #  Optional:

  #  persisting all of /var/lib and /var/log doesn't work, just put /var on zfs rpool/local/var instead of tmpfs
  #  "L /var/lib - - - - /persist/var/lib"    
  #  "L /var/log - - - - /persist/var/log"

  #  not needed
  #  "L /var/lib/samba - - - - /persist/var/lib/samba" 
  #  "L /var/lib/weechat - - - - /persist/var/lib/weechat"     
  #  "L /var/lib/lxd/storage-pools - - - - /persist/var/lib/lxd/storage-pools"

  #  breaks the service
  #  "L /var/lib/lxc - - - - /persist/var/lib/lxc"  # doesn't work with lxcfs on fuse.lxcfs
  #  "L /var/lib/lxd - - - - /persist/var/lib/lxd"  # doesn't work with lxcfs on fuse.lxcfs
  #  "L /var/lib/lxd/storage-pools - - - - /persist/var/lib/lxd/storage-pools"
  #  "L /var/lib/lxcfs - - - - /persist/var/lib/lxcfs"
  #  "L /var/lib/libvirt - - - - /persist/var/lib/libvirt"
  #  "L /var/lib/tailscale - - - - /persist/var/lib/tailscale"   

  #  also /var back to tmpfs, and /var/lib/lxd/storage-pools/ to /persist/var/lib/lxd/storage-pools/, and /var/lib/lxcfs to lxcfs:	
  #├─/var                                                    rpool/local/var                   zfs             rw,relatime,xattr,posixacl
  #│ ├─/var/lib/lxcfs                                        lxcfs                             fuse.lxcfs      rw,nosuid,nodev,relatime,user_id=0,group_id=0,allow_other
  #│ ├─/var/lib/lxd/shmounts                                 tmpfs                             tmpfs           rw,relatime,size=100k,mode=711
  #│ ├─/var/lib/lxd/devlxd                                   tmpfs                             tmpfs           rw,relatime,size=100k,mode=755
  #│ └─/var/lib/lxd/storage-pools/lxdpool/containers/ae-test rpool/safe/lxd/containers/ae-test zfs             rw,noatime,xattr,posixacl

  # Try moving /var back to tmpfs, and /var/lib/lxd/storage-pools/ to /persist/var/lib/lxd/storage-pools/, and /var/lib/lxcfs to lxcfs
  # Doesn't work, need to also explicitly mount /var/lib/lxcfs to an lxcfs filesystem of type fuse.lxcfs, instead of letting the system automatically mount it to tmpfs along with everything else in / and /var.

  ################################################################################
  # Environment
  ################################################################################

  # configure zsh to work with gnome; and direnv to persist between nix-shells
  # https://www.reddit.com/r/NixOS/comments/ocimef/users_not_showing_up_in_gnome/h40j3x7/
  # https://github.com/nix-community/nix-direnv
  environment.pathsToLink = [ 
    "/share/zsh"
    "/share/nix-direnv"
  ];
  
  environment.shells = [ pkgs.zsh ];
  # also include these lines in user config:
  #users.<user>.shell = pkgs.zsh;
  #users.<user>.useDefaultShell = false;

  # use sudo, and stop sudo lectures after each nixos-rebuild and reboot
  security.sudo = {
    enable = true;
    extraConfig = ''
      Defaults lecture = never
    '';
  };
  
  # use doas instead of sudo. disable sudo above.
  # https://www.reddit.com/r/NixOS/comments/rts8gm/sudo_or_doas/
  #security.doas = {
  #  enable = true;
  #  extraRules = [{
  #    users = [ "bgibson" "guest" ];
  #    keepEnv = true;
  #    persist = true;  
  #  }];
  #};

  ################################################################################
  # Video Drivers
  ################################################################################

  # this doesn't seem to be needed, leaving here just in case something needs it
  #nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "nvidia-x11" ];

  hardware.opengl = {
    enable = true;
    driSupport =
      true; # install and enable Vulkan: https://nixos.org/manual/nixos/unstable/index.html#sec-gpu-accel
    driSupport32Bit = true;
    #extraPackages = with pkgs; [ libvdpau-va-gl vaapiVdpau ];  # Nvidia gfx
    #extraPackages32 = with pkgs; [ libvdpau-va-gl vaapiVdpau ];  # Nvidia gfx
    extraPackages = with pkgs; [
      amdvlk
      rocm-opencl-icd
      libvdpau-va-gl
      vaapiVdpau
    ]; # AMD/ATI gfx
    extraPackages32 = with pkgs; [
      driversi686Linux.amdvlk
      libvdpau-va-gl
      vaapiVdpau
    ]; # AMD/ATI gfx
    #extraPackages = with pkgs; [ vaapiIntel intel-ocl libvdpau-va-gl vaapiVdpau ];  # Intel gfx
    #extraPackages32 = with pkgs; [ vaapiIntel intel-ocl libvdpau-va-gl vaapiVdpau ];  # Intel gfx
  };

  # Nvidia
  #boot.extraModulePackages = [ config.boot.kernelPackages.nvidia_x11 ];
  #boot.extraModulePackages = [ config.boot.kernelPackages.nvidia_x11_beta ];
  #boot.extraModulePackages = with config.boot.kernelPackages; [ nvidia_x11_beta ];  # working
  #boot.extraModulePackages = with config.boot.kernelPackages; [ nvidia_x11_beta wireguard ];

  # https://www.reddit.com/r/NixOS/comments/or7pvq/what_are_the_options_for_hardwarenvidiapackage/
  # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/os-specific/linux/nvidia-x11/default.nix
  #hardware.nvidia = {
  #  modesetting.enable = true;
  #  nvidiaPersistenced = true;
  #  powerManagement.enable = true;
  #  package = "config.boot.kernelPackages.nvidiaPackages.stable";  # 460 series.  not of type package
  #  package = config.boot.kernelPackages.nvidiaPackages.beta;  # 470 series.  not of type package
  #  package = "config.boot.kernelPackages.nvidiaPackages.vulkan_beta";  # not of type package
  #  package = "config.boot.kernelPackages.nvidiaPackages.legacy_390";  # not of type package
  #  package = "config.boot.kernelPackages.nvidiaPackages.legacy_340";  # not of type package
  #};

  # https://search.nixos.org/options?channel=21.05&show=services.xserver.videoDrivers&query=nvidia
  # https://github.com/NixOS/nixpkgs/issues/98328
  # https://github.com/NixOS/nixpkgs/issues/147805
  #services.xserver = {
  #  videoDrivers = [ "nvidia" ];  # (can't boot)
  #  videoDrivers = [ "nvidia_x11" ];  # (can't boot)
  #  videoDrivers = [ "modesetting" "nvidia" ];  
  #  videoDrivers = [ "nvidia_x11_beta" ];
  #  videoDrivers = [ "modesetting" "nvidia_x11_beta" ];
  #  videoDrivers = [ "nvidiaLegacy390" ];  # maybe try this one
  #  videoDrivers = [ "modesetting" "nvidiaLegacy390" ];  # or this one
  #  enable = true;
  #  exportConfiguration = true;
  #  displayManager.startx.enable = true;
  #  deviceSection = ''
  #    Option      "AllowEmptyInitialConfiguration"
  #  '';
  #};

  # maybe needed for Nvidia: https://nixos.org/manual/nixos/stable/#sec-profile-all-hardware
  #hardware.enableAllFirmware = true;

  # Virtualisation with GPU passthrough
  #virtualisation.docker.enableNvidia = true;
  #virtualisation.podman.enableNvidia = true;

  # Nvidia info & tools
  programs.atop = {
    enable = true;
    atopService.enable = true;
    #atopgpu.enable = true;  # build fails, maybe out of /build space, even with /build at 10GB tmpfs?  or maybe requires Nvidia drivers
    netatop.enable = true;
    #setuidWrapper.enable = true;
    #settings = {};
  };

  # AMD/ATI
  # https://nixos.org/manual/nixos/stable/#sec-gpu-accel-vulkan-amd
  # For amdvlk
  #environment.variables.VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/amd_icd64.json";
  # For radv
  #environment.variables.VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json";

  ################################################################################
  # Choose a Display Option (pick one, comment the others):
  ################################################################################  
  ################################################################################
  # 1.  Display Option: GDM + Gnome
  ################################################################################

  # X11 + GDM + Gnome
  # https://nixos.org/manual/nixos/unstable/index.html#sec-gnome-gdm
  services.xserver = {
    enable = true; # enable X11
    layout = "us";
    xkbOptions = "eurosign:e";
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
  };

  # https://search.nixos.org/options?channel=unstable&from=0&size=50&sort=relevance&type=packages&query=services.gnome
  services.gnome = {
    core-shell.enable = true;
    gnome-keyring.enable = true;
    gnome-remote-desktop.enable = true;
    gnome-settings-daemon.enable = true;
    gnome-online-accounts.enable = true;
    gnome-browser-connector.enable = true;
    #core-developer-tools.enable = true;
  };

  ################################################################################
  # 2.  Display Option: SDDM + KDE Plasma
  ################################################################################

  # Guides:  https://nixos.wiki/wiki/KDE
  # Theme:  https://www.youtube.com/watch?v=2GYT7BK41zk&lc=z22bglkx4wmfj3rmbacdp43ayexuyzthvotydzzcmpxw03c010c

  #services.xserver = {
  #  enable = true;
  #  layout = "us";
  #  xkbOptions = "eurosign:e";
  #  displayManager.sddm.enable = true;
  #  desktopManager.plasma5.enable = true;
  #};

  # (add kde-gtk-config to environment.systemPackages for GTK themes)

  # also add below after environment.systemPackages package list for full KDE distro apps
  # https://discourse.nixos.org/t/solved-plasma-desktop-on-18-03-is-it-all-there/293/10
  #environment.systemPackages = [...] 
  # Enable for full KDE metapackage
  # ++ builtins.filter lib.isDerivation (builtins.attrValues plasma5Packages.kdeGear)
  # ++ builtins.filter lib.isDerivation (builtins.attrValues plasma5Packages.kdeFrameworks)
  # ++ builtins.filter lib.isDerivation (builtins.attrValues plasma5Packages.plasma5)
  #;

  ################################################################################
  # 3.  Display Option: X11 + Pantheon
  ################################################################################

  # ElementaryOS's Pantheon Desktop
  # Cannot enable both Pantheon and Gnome, so one must be commented out at all
  # times.  https://nixos.org/manual/nixos/unstable/index.html#sec-pantheon-faq
  #services.xserver = {
  #  enable = true;
  #  layout = "us";
  #  xkbOptions = "eurosign:e";
  #	 desktopManager.pantheon = {
  #	   enable = true;
  #	   extraWingpanelIndicators = [];
  #    extraSwitchboardPlugs = [];
  #  };
  #};	

  ################################################################################
  # 4.  Display Option: Wayland+Sway and X11+i3 using LightDM
  ################################################################################

  # https://www.reddit.com/r/NixOS/comments/otnfq6/i3_or_sway_why_not_both_how_to_have_duel_window/
  # https://stel.codes/blog-posts/i3-or-sway-why-not-both/

  # i3 config
  #services.xserver.enable = true;
  #services.xserver.libinput.enable = true;
  #services.xserver.desktopManager.xterm.enable = false;
  #services.xserver.displayManager.lightdm.enable = true;
  #services.xserver.displayManager.defaultSession = "none+i3";
  #services.xserver.windowManager.i3.enable = true;
  #services.xserver.windowManager.i3.configFile = ./i3-config;

  # Sway config
  #programs.sway.enable = true;
  #environment.etc."sway-config".source = ./sway-config;

  # Just change ./i3-config and ./sway-config to the location of your configuration files and create a symbolic link to your Sway config by running this command:

  # mkdir -p $HOME/.config/sway && ln -s /etc/sway-config $HOME/.config/sway/config

  # And that's it! Putting these lines of code into your NixOS configuration will give you the exact same setup.

  ################################################################################
  # 5.  Display Option: Wayland Sway only
  ################################################################################

  # Install dual window managers: i3 and Sway:
  # https://www.reddit.com/r/NixOS/comments/otnfq6/i3_or_sway_why_not_both_how_to_have_duel_window/ 

  # Wayland + Sway 
  #programs.sway.enable = true;
  #programs.wshowkeys.enable = true;
  #programs.xwayland.enable = true;

  # Nvidia in Wayland (probably won't work, see: https://drewdevault.com/2017/10/26/Fuck-you-nvidia.html)
  # https://www.reddit.com/r/NixOS/comments/ndi68c/is_there_a_way_to_start_gnome3_in_wayland_mode/		    
  # https://search.nixos.org/options?channel=21.05&show=services.xserver.displayManager.gdm.wayland&query=nvidia
  #services.xserver.displayManager.gdm = {
    #wayland = true; 
    # or 
    #nvidiaWayland = true;  
  #};

  ################################################################################
  # 6.  Display Option: i3 only
  ################################################################################

  # i3 twm
  #services.xserver.windowManager = {
  #	i3 = {
  #	  enable = true;
  #	  package = pkgs.i3;
  #	  extraPackages = [ ];
  #	};
  #	default = "i3";
  #};

  # i3-gaps twm
  # https://github.com/Airblader/i3/wiki/installation
  #services.xserver.windowManager = {
  #	i3-gaps = {
  #	  enable = true;
  #	  package = pkgs.i3-gaps;
  #	  extraPackages = [ ];
  #	};
  #	default = "i3-gaps";
  #};

  ################################################################################
  # 7.  Hyprland
  ################################################################################
  # https://www.youtube.com/watch?v=61wGzIv12Ds
  #environment.sessionVariables = {
    # If your cursor becomes invisible
  #  WLR_NO_HARDWARE_CURSORS = "1";
    # Hint electron apps to use wayland
  #  NIXOS_OZONE_WL = "1";
  #};

  # enable both gnome and hyprland, select at login
  #services.xserver.displayManager.gdm.wayland = true;  

  #programs.hyprland = {
  #  enable = true;
  #  xwayland.enable = true;
  #};
  
  # rofi keybind, add this to hyprland config on first boot
  #bind = $mainMod, S, exec, rofi -show drun -show-icons

  ################################################################################
  # 8.  Display Option: other TWM
  ################################################################################

  # other twm
  # check for required package too
  #services.xserver.windowManager.xmonad.enable = true;
  #services.xserver.windowManager.twm.enable = true;
  #services.xserver.windowManager.icewm.enable = true;
  #services.xserver.windowManager.wmii.enable = true;

  ################################################################################
  # 9.  Redshift (for wm's and de's that don't already have it)
  ################################################################################  

  # https://search.nixos.org/options?channel=21.05&show=services.redshift.enable&query=redshift
  #services.redshift = {
  #  enable = true;
  #  latitude = "43.365";
  #  longitude = "-8.41";
  #  temperature.day = 6500;
  #  temperature.night = 2700;
  #};

  ################################################################################
  # End Display Configuration
  ################################################################################  
  ################################################################################
  # System Activation Scripts
  ################################################################################

  # Run shell commands at startup 
  # https://search.nixos.org/options?channel=21.05&show=system.activationScripts&query=system.activation
  # https://mdleom.com/blog/2021/03/15/rsync-setup-nixos/
  #system.activationScripts = {
  # 
  #}

  ################################################################################
  # Fonts
  ################################################################################

  # https://nixos.wiki/wiki/Fonts
  fonts.packages = with pkgs; [
    font-awesome
    powerline-fonts
    powerline-symbols
    (nerdfonts.override { fonts = [ "NerdFontsSymbolsOnly" ]; })
  ];

  ################################################################################
  # Print
  ################################################################################

  # Enable CUPS to print documents.
  services.printing.enable = true;
  services.printing.drivers = with pkgs; [ brlaser ];

  ################################################################################
  # Sound
  ################################################################################

  # Enable sound via Pulse Audio
  # must set both to false if using Pipewire below
  sound.enable = false;
  hardware.pulseaudio = {
    enable = false;
    support32Bit = true;
  };

  # Enable sound via Pipewire
  # 1. RealtimeKit system service, for pipewire
  security.rtkit.enable = true;
  # 2. Pipewire config
  # https://search.nixos.org/options?channel=21.05&query=pipewire
  # https://nixos.wiki/wiki/PipeWire
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    socketActivation = true;
    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now.
    #media-session.enable = true;
  };

  ################################################################################
  # Input
  ################################################################################

  # Enable touchpad support (enabled by default in most desktopManagers).
  # services.xserver.libinput.enable = true;

  # Razer hardware support
  # 21.11 requires hardware.openrazer.users:  https://nixos.org//manual/nixos/stable/options.html#opt-hardware.openrazer.users
  hardware.openrazer = {
    enable = true;
    users = [ "bgibson" ]; # required for NixOS 21.11 and higher
    #mouseBatteryNotifier = true;
    #keyStatistics = true;
    #verboseLogging = true;
    #syncEffectsEnabled = true;
    #devicesOffOnScreensaver = true;
  };

  ################################################################################
  # Secure Comms
  ################################################################################
  ################################################################################
  # ssh
  ################################################################################

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;
    };
    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
      {
        path = "/etc/ssh/ssh_host_rsa_key";
        type = "rsa";
        bits = 4096;
      }
    ];
  };

  # https://search.nixos.org/options?show=programs.ssh.knownHosts&from=0&size=50&sort=relevance&type=packages&query=ssh
  #programs.ssh = 
  #  startAgent = true;
  #  knownHosts = 
  #};

  ################################################################################
  # Mosh 
  ################################################################################

  programs.mosh.enable = true;

  ################################################################################
  # GnuPG
  ################################################################################

  # Enable GnuPG Agent
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  ################################################################################
  # Tailscale
  ################################################################################

  # Tailscale systemd config, based on:
  # https://tailscale.com/blog/nixos-minecraft/
  # make a reusable key in your Tailscale.com account and save it as 
  # [/persist]/etc/tailscale/tskey-reusable
  services.tailscale.enable = true;  
  
  # create a systemd oneshot job to authenticate to Tailscale.com at login
  systemd.services.tailscale-autoconnect = {
    description = "Automatic connection to Tailscale.com";

    # make sure tailscale is running locally before trying to connect to Tailscale.com
    after = [ "network-pre.target" "tailscale.service" ];
    wants = [ "network-pre.target" "tailscale.service" ];
    wantedBy = [ "multi-user.target" ];

    # set this service as a oneshot job
    serviceConfig.Type = "oneshot";

    # have the job run this shell script to authenticate with Tailscale.com
    script = with pkgs; ''
      # wait for tailscaled to settle
      # (as of tailscale 1.4 this should no longer be necessary, but I find it still is)
      echo "Waiting for tailscale service start completion ..." 
      sleep 5

      # check if we are already authenticated to tailscale
      echo "Checking if already authenticated to Tailscale ..."
      status="$(${tailscale}/bin/tailscale status -json | ${jq}/bin/jq -r .BackendState)"
      if [ $status = "Running" ]; then  # exit
      	echo "Already authenticated to Tailscale.com, exiting."
        exit 0
      fi
        
      # otherwise authenticate with tailscale
      echo "Authenticating with Tailscale ..."
      ${tailscale}/bin/tailscale up --auth-key file:/etc/tailscale/tskey-reusable
    '';
  };

  ################################################################################
  # ToxVPN
  ################################################################################

  #services.toxvpn = {
    #enable = false;
    #port = ;
    #localip = ;
    #auto_add_peers = [];
  #};

  ################################################################################
  # X2Go VNC Server
  ################################################################################

  # https://search.nixos.org/options?channel=unstable&from=0&size=50&sort=relevance&type=packages&query=x2goserver
  # disable gnome-remote-desktop
  #services.x2goserver = {
    #enable = true;
    #superenicer.enable = true;
    #nxagentDefaultOptions = ;
    #settings = ;
  #};

  ################################################################################
  # Searx Federated Search Engine
  ################################################################################

  # https://sagrista.info/blog/2021/searx-or-duckduckgo/
  # https://searx.github.io/searx/
  # https://github.com/searx/searx
  # https://searx.space/
  # https://search.nixos.org/options?query=searx
  #services.searx = {
  #  enable = true;
  #  settings = '' '';
  #};

  ################################################################################
  # ACME
  ################################################################################

  # ACME certificates: https://nixos.org/manual/nixos/unstable/index.html#module-security-acme
  #security.acme = {
    #acceptTerms = true;
    #defaults.email = "fbg111@gmail.com";
    #defaults.server = # ACME Directory Resource URI. Defaults to Let’s Encrypt’s production endpoint, https://acme-v02.api.letsencrypt.org/directory, if unset.
  #};

  ################################################################################
  # End Secure Comms
  ################################################################################
  ################################################################################
  # Containers & Virtualisation
  ################################################################################

  # Using only LXC/LXD and Qemu.  Not Virtualbox b/c it installs an unstable 
  # kernel module.  Not Docker, prefer LXC/LXD, podman, and eventually 
  # Kata Containers when packaged for NixOS
  # https://nixos.wiki/wiki/LXD
  # https://nixos.wiki/wiki/Virt-manager
  # https://nixos.org/manual/nixos/stable/#ch-containers
  # https://search.nixos.org/options?channel=21.05&query=lxc
  # https://www.srid.ca/lxc-nixos
  # https://www.reddit.com/r/VFIO/comments/p4kmxr/tips_for_single_gpu_passthrough_on_nixos/
  # https://www.christitus.com/vm-setup-in-linux
  virtualisation = {
    containers.enable = true;
    containerd.enable = true;
    libvirtd = {
      enable = true;
      onBoot = "ignore";
      onShutdown = "shutdown";
      qemu = {
        ovmf.enable = true;
        runAsRoot = false;
      };
    };
    lxd = {
      enable = true;
      zfsSupport = true;
      recommendedSysctlSettings = true;
    };
    lxc = {
      enable = true;
      lxcfs.enable = true;
      #systemConfig = ''  # man lxc.system.conf 
      #  lxc.lxcpath = /var/lib/lxd/containers  # The location in which all containers are stored.
      #  lxc.lxcpath = /var/lib/lxd/storage-pools/lxdpool/containers
      #  lxc.bdev.zfs.root = rpool/safe/lxd  # Default ZFS root name.
      #'';
      systemConfig = ''
        lxc.lxcpath = /var/lib/lxd/containers
        lxc.bdev.zfs.root = rpool/safe/lxd  
      '';
      #usernetConfig =  '' # man lxc-usernet
      #user type bridge number
      #@group type bridge number
      #bgibson veth lxdbr0 10
      #'';
      #defaultConfig =  #'' # man lxc.container.conf 
      #lxc.arch = x86_64
      #lxc.uts.name = z10pe-d8-lxc01
      #lxc.net.0.type = veth
      #lxc.net.0.flags = up
      #lxc.net.0.link = br0
      #lxc.net.0.name = eth0
      #lxc.net.0.hwaddr = 4a:49:43:49:79:bf
      #lxc.net.0.ipv4.address = 10.152.2.1/24
      #lxc.net.0.ipv4.address = auto
      #lxc.net.0.ipv6.address = fd42:c9e4:a454:4aae::1/64
      #lxc.net.0.ipv6.address = auto
      #'';
    };
    podman = {
      enable = true;
      #networkSocket = {
      #  enable = ;
      #};
      #defaultNetwork = {
      #  dnsname.enable = 
      #};
    };
    # Don't install virtualbox, kernel modules unstable
    # https://news.ycombinator.com/item?id=28189638
    virtualbox = {
      host = {
        enable = false;
        enableExtensionPack = false;
        addNetworkInterface = false;
      };
      guest = {
        enable = false;
        x11 = false;
      };
    };
    # prefer LXC to docker
    docker = {
      enable = false;
      #enableOnBoot = true;  # fails to start
      #enableNvidia = true;
      #storageDriver = "zfs";  # fails to start
    };
    # vmware service fails to start, need more config
    #vmware.guest = {
    #  enable = true;
    #  headless = false;
    #};
  };

  # SPICE for Gnome Box shared folders
  # https://search.nixos.org/options?channel=21.05&query=spice
  programs.dconf.enable = true;
  services.spice-vdagentd.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;

  ################################################################################
  # Samba
  ################################################################################

  # https://search.nixos.org/options?channel=21.05&query=services.samba
  services.samba = {
    enable = true;
    package = pkgs.samba4Full;
    securityType = "user";
    invalidUsers = [ "root" ];
    openFirewall = true;
    #enableWinbindd
    #enableNmbd
    #nsswins
    # Verbatim contents of smb.conf. If null (default), use the autogenerated file from NixOS instead. 
    #configText = {};
    extraConfig = ''
      workgroup = ATLAS
      server string = smbnix
      server role = standalone server
      ;server min protocol = SMB3  ; enable encrypted comms
      ;smb encrypt = required  ; require encrypted comms
      ;netbios name = smbnix
      ;"guest account" = nobody  ; unrecognized
      ;"map to guest" = "bad user"  ; unrecognized
      ;#use sendfile = yes
      ;#max protocol = smb2
      ;"hosts allow" = 192.168.0 localhost
      ;"hosts deny" = 0.0.0.0/0
    '';
    shares = {
      z10pe-d8-home-bgibson = { 
        path = "/home/bgibson/";
        "guest ok" = "no";
        public = "yes";
        writable = "yes";
        printable = "no";
        browseable = "yes";
        "read only" = "no";
        #"create mask" = "0765";
        #";directory mask" = "0755";
        #"force user" = "ALLOWEDUSER";
        #"force group" = "ALLOWEDGROUP";
        comment = "z10pe-d8 /home/bgibson/ samba share.";
      };
      z10pe-d8-zdata0 = {
        path = "/zdata0/";
        "guest ok" = "no";
        public = "yes";
        writable = "yes";
        printable = "no";
        browseable = "yes";
        "read only" = "no";
        #"create mask" = "0765";
        #";directory mask" = "0755";
        #"force user" = "ALLOWEDUSER";
        #"force group" = "ALLOWEDGROUP";
        comment = "z10pe-d8 /zdata0/ samba share.";
      };
    };
  };
  
  services.samba-wsdd = {
    enable = true;
    discovery = true;  
    openFirewall = true;
    #interface = null;  # default
    #interface = tailscale0;
    #interface = wlp175s0;
    #hostname = ;  # Override (NetBIOS) hostname to be used (default hostname)
    #workgroup = ;
    #domain = ;  # disables workgroup
    #hoplimit = ;  # default = null = 1
    #listen = ;
    extraOptions = [
      "--verbose"
      #"--no-http"
      #"--ipv4only"
      #"--no-host"
    ];
  };

  ################################################################################
  # TODO: Yggdrasil
  ################################################################################

  # https://nixos.org/manual/nixos/unstable/index.html#module-services-networking-yggdrasil-configuration
  # Yggdrasil is an early-stage implementation of a fully end-to-end encrypted, self-arranging IPv6 network. 

  ################################################################################
  # Backups
  ################################################################################
  ################################################################################
  # Rsyncd
  ################################################################################

  # rsyncd network shared dirs
  # syntax error somewhere
  # https://discourse.nixos.org/t/how-to-translate-rsyncd-conf-into-services-rsyncd-settings/13783
  # https://search.nixos.org/options?channel=21.05&show=services.rsyncd.settings&query=rsyncd
  services.rsyncd = {
    enable = true;
    settings = {
      development = {
        "auth users" = "bgibson";
        path = "/home/bgibson/Development/USBDrives/";
        comment = "sharing /home/bgibson/Development/USBDrives/";
        "read only" = "no";
        list = "yes";
        "use chroot" = false;
        #"secrets file" = "/etc/rsyncd.secrets";
      };
      zdata0 = {
        "auth users" = "bgibson";
        path = "/zdata0/";
        comment = "sharing /zdata0/";
        "read only" = "no";
        list = "yes";
        "use chroot" = false;
        #"secrets file" = "/etc/rsyncd.secrets";
      };
      global = {
        gid = "nobody";
        "max connections" = 4;
        uid = "nobody";
        "use chroot" = true;
      };
    };
  };

  ################################################################################
  # TODO: Duplicati
  ################################################################################

  # https://www.duplicati.com/
  # https://search.nixos.org/options?channel=21.05&query=duplicati
  #services.duplicati = { enable = true; };

  ################################################################################
  # TODO: Syncthing
  ################################################################################

  # Syncthing, continuous folder syncing
  # Not for backups:  https://www.reddit.com/r/Syncthing/comments/oxsvd9/couple_of_newbie_questions/h7ote7u/
  # https://discourse.nixos.org/t/syncthing-systemd-user-service/11199/2
  # https://discourse.nixos.org/t/syncthing-systemd-user-service/11199/7
  # use nixos-option services.syncthing.<command> to control the service
  # https://beyermatthias.de/tag:syncthing
  #services.syncthing = {
  #  enable = true;
  #  systemService = true;
  #  user = "bgibson";
  #  configDir = "/home/bgibson/.syncthing";
  #  dataDir = "/home/bgibson/Development/USBDrives/";
  #};

  ################################################################################
  # TODO: Sanoid (ZFS snapshot backups)
  ################################################################################

  # Sanoid/Syncoid
  # https://search.nixos.org/options?channel=21.05&from=0&size=50&sort=relevance&query=sanoid
  # https://search.nixos.org/options?channel=21.05&from=0&size=50&sort=relevance&query=syncoid
  # http://www.openoid.net/transcend/
  #services.sanoid.enable = true;
  #services.syncoid.enable = true;

  ################################################################################
  # TODO: Resilio
  ################################################################################

  # Resilio, formerly Bittorrent Sync: https://www.resilio.com/individuals/
  # https://search.nixos.org/options?channel=21.05&show=services.resilio.enable&from=0&size=50&sort=relevance&query=resilio
  #services.resilio = {
  #	enable = true;
  #	sharedFolders = [ 
  #{
  #  deviceName = "z10pe-d8";
  #  directory = "/home/user/sync_test";
  #  knownHosts = [
  #    "192.168.1.2:4444"
  #    "192.168.1.3:4444"
  #  ];
  #  searchLAN = true;
  #  secret = "?";
  #  useDHT = false;
  #  useRelayServer = true;
  #  useSyncTrash = true;
  #  useTracker = true;
  #}
  #];
  #};

  ################################################################################
  # TODO: Borg
  ################################################################################

  # Borg
  # https://nixos.org/manual/nixos/unstable/index.html#opt-services-backup-borgbackup-local-directory
  # {
  #    opt.services.borgbackup.jobs = {
  #      { 
  #        rootBackup = {
  #          paths = "/";
  #          exclude = [ "/nix" "/path/to/local/repo" ];
  #          repo = "/path/to/local/repo";
  #          doInit = true;
  #          encryption = {
  #            mode = "repokey";
  #            passphrase = "secret";
  #          };
  #         compression = "auto,lzma";
  #         startAt = "weekly";
  #       };
  #     }
  #   };
  # }

  ################################################################################
  # End Backups
  ################################################################################
  ################################################################################
  # Screen & Tmux
  ################################################################################

  # Tmux
  # https://nixos.wiki/wiki/Tmux
  # https://search.nixos.org/options?channel=21.05&query=tmux
  # https://github.com/srid/nix-config/blob/master/nixos/tmux.nix
  # https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/programs/tmux.nix
  programs.tmux = {
    enable = true;
    clock24 = true;
    #  extraTmuxConf = '' # used for less common options, intelligently combines if defined in multiple places.
    #    ...
    #  '';
  };

  # Needed for Weechat
  # https://christine.website/blog/irc-stuff-nixos-2021-05-29
  #programs.screen.screenrc = ''
    #multiuser on
    #acladd normal_user
  #'';

  ################################################################################
  # IRC, ZNC, Freenet, Tox
  ################################################################################

  # https://nixos.wiki/wiki/ZNC
  # https://wiki.znc.in/Configuration
  # https://discourse.nixos.org/t/znc-config-without-putting-password-hash-in-configuration-nix/14236
  # ZNC does not support a separate secrets file, but does support separate config file.  Put pwd 
  # hash in the config file and use git secret/nix age/sops/etc to secure it.
  #services.znc = {
  #  enable = true;
  #  mutable = false;  # Overwrite configuration set by ZNC from the web and chat interfaces.
  #  useLegacyConfig = false;  # Turn off services.znc.confOptions and their defaults.
  #  openFirewall = true;  # ZNC uses TCP port 5000 by default.
  #  #configFile = /etc/znc/config;  # /persist/etc/znc/
  #};

  # Weechat IRC client
  # Runs in detached screen;
  # Re-attach with:  screen -x weechat/weechat-screen
  # https://nixos.org/manual/nixos/unstable/index.html#module-services-weechat
  #services.weechat.enable = true;

  #services.freenet = {
    #enable = true;
    #nice = ;
  #};

  # https://search.nixos.org/options?channel=21.11&show=services.mattermost.enable&query=Mattermost
  #services.mattermost = {
  #  enable = true;
  #};

  # tox-node
  # https://github.com/tox-rs/tox-node
  #services.tox-node = {
  #  enable = true;
  #  logType = "Syslog";
  #  keysFile = "/var/lib/tox-node/keys";
  #  udpAddress = "0.0.0.0:33445"; 
  #  tcpAddresses = [ "0.0.0.0:33445" ];
  #  tcpConnectionLimit = 8192;
  #  lanDiscovery = true;
  #  threads = 1;
  #  motd = "Hi from tox-rs! I'm up {{uptime}}. TCP: incoming {{tcp_packets_in}}, outgoing {{tcp_packets_out}}, UDP: incoming {{udp_packets_in}}, outgoing {{udp_packets_out}}";
  #};
  
  ################################################################################
  # Peertube
  ################################################################################
  
  #services.peertube = {
    #package = ;
    #enable
    #settings
    #group
    #user
    #localDomain
    #configureNginx
    #dataDirs
    #enableWebHttps
    #listenWeb
    #listenHttp
    #database = {
      #createLocally
      #user
      #port
      #passwordFile
      #name
      #host
    #};
    #redis = {
      #createLocally
      #port
      #passwordFile
      #host
      #enableUnixSocket
    #};
    #smtp = {
      #createLocally
      #passwordFile
    #};
    #serviceEnvironmentFile
    #secrets.secretsFile
  #};

  ################################################################################
  # Users
  ################################################################################

  # When using a password file via users.users.<name>.passwordFile, put the 
  # passwordFile in the specified location *before* rebooting, or you will be 
  # locked out of the system.  To create this file, make a single file with only 
  # a password hash in it, compatible with `chpasswd -e`.  Or you can copy-paste 
  # your password hash from `/etc/shadow` if you first built the system with hardcoded
  # `password=`, `hashedPassword=`, initialPassword-, or initialHashedPassword=.
  # `sudo cat /etc/shadow` will show all hashed user passwords.
  # More info:  https://search.nixos.org/options?channel=21.05&show=users.users.%3Cname%3E.passwordFile&query=users.users.%3Cname%3E.passwordFile

  users = {
    mutableUsers = false;
    defaultUserShell = "/var/run/current-system/sw/bin/zsh";
    users = {
      root = {
        # disable root login here, and also when installing nix by running `nixos-install --no-root-passwd`
        # https://discourse.nixos.org/t/how-to-disable-root-user-account-in-configuration-nix/13235/3
        hashedPassword = "!"; # disable root logins, nothing hashes to !
      };
      test = {
        isNormalUser = true;
        shell = pkgs.zsh;
        useDefaultShell = false;
        description = "Test Account";
        #description = "Test account for new config options that could break user login.  When not testing, disable sudo.  Remove 'wheel' from extraGroups and rebuild.";
        passwordFile =
          "/etc/users/test"; # make sure to copy this file into /mnt/persist/etc/users/ immediately after installation complete and before rebooting. If the file is not there on reboot you can't login.
        extraGroups =
          [ "wheel" "networkmanager" ]; # incldue "wheel" for testing
        #openssh.authorizedKeys.keys = [ "${AUTHORIZED_SSH_KEY}" ];
      };
      bgibson = {
        isNormalUser = true;
        shell = pkgs.zsh;
        useDefaultShell = false;
        description = "Byron Gibson";
        passwordFile =
          "/persist/etc/users/bgibson"; # make sure to copy this file into /persist/etc/users/ immediately after installation complete and before rebooting. If the file is not there on reboot you can't login.
        extraGroups = [
          "wheel"
          "networkmanager"
        ]; # may need to include "libvirtd" "lxd" but prefer these to require sudo
        #openssh.authorizedKeys.keys = [ "${AUTHORIZED_SSH_KEY}" ];
      };
    };
  };

  ################################################################################
  # Applications
  ################################################################################

  # Permit Electron-13.6.9 (EOL but required by some apps) 
  # TODO: Test periodicially if still needed, remove when no longer needed
  #nixpkgs.config.permittedInsecurePackages = [ "electron-13.6.9" ];

  # List packages installed in system profile. To search, run:
  # $ nix search <packagename>
  environment.systemPackages = with pkgs; [

    # system core (use these for a minimal first install)
    nix-index  # locate package providing specified file in nixpkgs
    nix-diff  # explain why two nix derivations differ
    nixfmt  # nix language linter
    vulnix  # nixos vulnerability scanner
    nvd  # nix/os pkg version diff tool
    nix-melt  # terminal flake-lock viewer
    nix-ld  # Run unpatched dynamic binaries on NixOS
    efibootmgr
    efivar
    efitools
    pciutils
    sysfsutils
    progress
    libcgroup
    coreutils-full
    cryptsetup
    openssl
    # uutils-coreutils  # rust version of coreutils 
    libkrb5
    krb5
    shishi  # kerberos, some apps especially Wine ones may require
    parted
    gparted
    gptfdisk
    openssh
    ssh-copy-id
    ssh-import-id
    #avahi  # local network service discovery, use services.avahi for this
    mkpasswd
    scrypt
    aescrypt
    libscrypt
    libargon2
    htop
    ncdu
    lshw
    xplr
    firefox
    irssi
    git
    transcrypt
    xscreensaver
    mlocate
    pwgen-secure
    ntfs3g
    desktop-file-utils
    lsof
    usbutils
    #zram-generator  # use zramSwap.enable till EOL
    
    # system extras
    # DBUS
    dbus
    dbus-map
    dbus-broker
    
    # debugging
    strace
    nfstrace
    dnstracer
    time
    
    # system management
    cron
    earlyoom
    
    # system monitoring
    atop
    powertop
    gotop
    iotop
    btop
    bottom
    procs
    nload
    wavemon
    glances
    conky
    vmtouch
    #nvtop (broken) 
    
    # system info
    psmisc
    lm_sensors
    neofetch
    gnome-usage
    dmidecode
    fontconfig
    freetype
    ftgl
    xorg.libxcb
    libxkbcommon
    cairo
    trace-cmd
    kernelshark
    perf-tools
    #rust-motd
    
    # ZFS
    zfs
    aide  # file and directory integrity checker
    httm  # time machine for zfs
    zfs-prune-snapshots
    #sanoid 

    # network extras
    #inetutils  # mutually exclusive with whois
    whois
    networkmanagerapplet
    bandwhich
    #ncat  # removed in 22.05
    ngrep
    nmap
    #nmap-graphical  # removed in 22.05
    nmapsi4
    rustscan
    tcptrack
    gping
    wireshark
    termshark
    httpx
    mitmproxy

    #gnunet
    #gnunet-gtk
    #libgnurl

    # Security
    keychain
    yubikey-manager
    yubikey-manager-qt

    # OpenSSH extras 
    ssh-chat
    ssh-tools
    pssh
    fail2ban
    sshguard

    # printer
    brlaser

    # gnome
    rhythmbox
    gnome_mplayer
    gnome.gnome-tweaks
    gnome.dconf-editor
    gnome.gnome-disk-utility
    gnome-extension-manager
    gnomeExtensions.vitals
    gnomeExtensions.gamemode
    gnomeExtensions.overview-navigation
    #gnomeExtensions.transparent-shell
    #gnomeExtensions.new-mail-indicator
    gnomeExtensions.wireguard-indicator
    gnomeExtensions.advanced-alttab-window-switcher

    # https://www.reddit.com/r/gnome/comments/p3m4uk/really_enjoying_my_new_gnome_desktop/
    # https://github.com/andyrichardson/simply-workspaces
    #gnomeExtensions.just-perfection
    #gnomeExtensions.workspaces-bar
    #gnomeExtensions.blur-me
    #https://github.com/pop-os/shell
    #gnomeExtensions.pop-shell

    # gnome dock
    #dockbarx  # unclear if compatible with gnome4: https://launchpad.net/dockbar/
    # Dash-to-Dock
    # extensions.gnome.org says both are incompatible, need to test: 
    # https://micheleg.github.io/dash-to-dock/
    # https://github.com/ewlsh/dash-to-dock/tree/ewlsh/gnome-40

    # gnome (broken)
    #gnomeExtensions.paperwm
    #gnomeExtensions.tilingnome 
    #gnomeExtensions.material-shell (incompatible with gnome4)
    #gnomeExtensions.gnome-shell-extension-systemd-manager (broken)
    #gnomeExtensions.gnome-shell-extension-tiling-assistant (broken)
    #gnomeExtensions.material-shell  # test when upgraded to version 40 (currently version 12 in nixpkgs, version 40a in alpha)
    #gnomeExtensions.gnome-shell-extension-gtile (broken)
    #gnomeExtensions.gnome-shell-extension-wg-indicator (broken)
    #gnomeExtensions.gnome-shell-extension-extension-list (broken)
    #gnomeExtensions.gnome-shell-extension-tiling-assistant (broken) 
    #gnomeExtensions.gnome-shell-extension-wireguard-indicator (broken)

    # KDE
    #kde-gtk-config
    #libsForQt5.qtstyleplugin-kvantum
    #themechanger
    #latte-dock

    # Wayland, Sway, & Wayfire
    # https://github.com/nix-community/nixpkgs-wayland
    # https://github.com/WayfireWM/wayfire/wiki
    #wayland
    #wayland-protocols
    #wayland-utils
    #wayfire
    #sway
    #waybar
    #dmenu-wayland 
    #swaywsr
    #swaycwd
    #swaybg
    #swaylock
    #swaylock-effects
    #workstyle
    #i3-wk-switch
    #wlogout
    #pass-wayland
    #kodi-wayland
    #firefox-wayland
    #vimPlugins.vim-wayland-clipboard
    
    # Hyprland
    # Bar
    #eww  # pick this or waybar       
    #waybar  # pick this or eww
    # may be required for waybar to show workspaces on hyprland
    #(waybar.overrideAttrs (oldAttrs: {
    #    mesonFlags = oldAttrs.mesonFlags ++ [ "-Dexperimental=true" ];
    #  })
    #)
    # Notifications
    #dunst  # wayland + x11
    #mako  # pure wayland
    libnotify  # dependency
    # Copy-paste & screenshots
    #wl-clipboard  # xclip alternative
    #slurp  # select utility
    #grim  # screenshot utility
    # Wallpaper daemon
    #hyprpaper
    #swaybg
    #wpaperd
    #mpvpaper
    #swww
    # Terminal  # see CLI section
    #kitty  # default
    #alacritty
    #wezterm
    # Launcher
    #rofi-wayland  # most popular
    #wofi
    #bemenu
    #fuzzel
    #tofi
    
    # X11 Tiling WMs
    #i3-gap  # c twm, i3 with gaps b/t windows, https://github.com/Airblader/i3
    #leftwm  # rust twm https://github.com/leftwm/leftwm 
    #xmonad  #haskell twm 
    #awesome  # c + lua twm, https://awesomewm.org/
    #dwm dwm-status dmenu 

    # CLI
    # terminals
    alacritty
    wezterm
    kitty
    st
    termpdfpy
    
    # shells
    zsh
    oh-my-zsh
    zsh-navigation-tools
    fzf-zsh
    zsh-fzf-tab
    zsh-forgit
    zsh-git-prompt
    #spaceship-prompt
    #zplug  # home-manager only, see config here: https://nixos.wiki/wiki/Zsh
    elvish
    mosh
    nushell
    nu_scripts
    vscode-extensions.thenuprojectcontributors.vscode-nushell-lang
    wezterm
    
    # terminal multiplexers
    screen
    #tmux  # handled by programs.tmux
    tmuxPlugins.vim-tmux-navigator
    tmuxPlugins.vim-tmux-focus-events
    #zellij  # (requires nerdfonts)
    
    # terminal graphics 
    ncurses
    chroma
    timg
    #termbox
    
    # cross-shell customization
    #starship 
    
    # directory tools
    zoxide
    
    # file tools
    file
    findutils
    agedu
    broot
    choose
    bat
    eza
    du-dust
    lsd
    fd
    deer
    dfc
    diskonaut
    trash-cli
    speedread
    grc
    fzf
    skim
    lf
    nnn
    duf
    duff
    silver-searcher
    fzf
    vgrep
    mcfly
    cheat
    agrep
    bingrep
    grin
    gron
    igrep
    qgrep
    #ripgrep-all
    ripgrep
    sgrep
    sift
    ucg
    ugrep
    vgrep
    xclip
    ranger
    joshuto
    
    # networking tools
    dig
    
    # http tools
    httpie
    xh
    curlie
    
    # Markdown tools
    mdcat
    
    # man pages
    tealdeer # (alias to tldr)
    
    # sed
    sd
    jq
    
    # diff
    colordiff
    meld
    icdiff
    diffutils
    delta
    xdelta
    #bsdiff ydiff patdiff vbindiff diffoscope xxdiff
    #dhex 
    # patch
    gnupatch
    # fonts
    #nerdfonts (broken) 
    # benchmarking
    hyperfine
    bitwise
    programmer-calculator

    # Editors
    #vim  # let programs.vim handle this
    #vim-full
    spacevim
    vimPlugins.SpaceVim
    powerline-rs
    amp  # rust terminal IDE
    helix  # rust terminal IDE
    kakoune  # rust terminal IDE
    #kakoune-unwrapped
    #kak-lsp  # kakoune language server
    vifm  # vim-like file manager
    vimPlugins.vifm-vim
    vimPlugins.direnv-vim
    vimPlugins.zk-nvim  # zk neovim plugin
    vimPlugins.zenburn
    vimPlugins.zenbones-nvim
    vimPlugins.vim-tmux
    vimPlugins.vim-tmux-navigator
    vimPlugins.vim-tmux-clipboard
    vimPlugins.vim-tmux-focus-events
    vimPlugins.vim-dispatch
    vimPlugins.vim-dispatch-neovim
    #vimPlugins.Vundle-vim  # installed manually
    #neovim  # let programs.neovim.enable handle this
    #emacs 
    emacs-nox
    texinfo
    hexdino
    xxv
    micro
    cmatrix
    tmatrix
    gomatrix
    pixd
    unrtf
    ted
    trace-cmd
    kernelshark
    perf-tools

    # hardware support
    # let programs.openrazer handle this if possible
    #openrazer-daemon 

    # Secure Comms & Networking
    shadowsocks-rust
    #tailscale  # services.tailscale
    wireguard-tools
    boringtun
    innernet
    nebula
    #firejail  # programs.firejail
    #opensnitch  # services.opensnitch.enable
    opensnitch-ui
    #firehol
    librewolf
    tor-browser-bundle-bin
    mullvad  # still need these even with services.mullvad.enable=true
    mullvad-vpn
    mullvad-browser
    gnomeExtensions.mullvad-indicator

    # App Sandbox
    bubblewrap
    #selinux-sandbox mbox

    #File transfer
    wget
    uget
    magic-wormhole
    webwormhole
    rsync
    zsync # grsync

    # File compression
    p7zip
    unzip
    zlib
    zlib-ng
    lz4
    #rarcrack (compile warnings) 

    # Screen extender
    barrier
    #synergy virtscreen 

    # Backups 
    duplicity
    deja-dup
    duply
    unison # diskrsync
    #syncthing syncthingtray # syncthing-gtk (broken)
    #pcloud 
    #resilio-sync
    #backintime

    # Containers & virtualisation
    #qemu_full  # virtualisation.libvirtd.qemu
    #qemu_kvm
    #qemu_xen-light
    #xen-light  # current version xen-4.10.4 EoL and marked insecure 
    qemu-utils
    qtemu
    #lxc lxd  # let virtualisation.{lxc,lxd} handle this
    #aqemu 	# broken
    firecracker
    ignite
    firectl
    podman-compose
    distrobox  # wrapper for podman
    crosvm
    libvirt
    bridge-utils
    virt-top
    virt-viewer
    virt-manager
    virt-manager-qt
    gnome.gnome-boxes
    spice
    spice-vdagent
    spice-gtk
    nerdctl
    #docker docker-client docker-ls docker-gc docker-slim docker-machine-kvm2 lazydocker #udocker 
    #docui rootlesskit  
    #virtualbox #virtualboxExtpack  # let virtualisation.virtualbox handle this
    #virtualboxWithExtpack  # will break otherwise
    #remotebox
    #dosbox-staging

    # development-core
    patchelf
    # Nix
    lorri
    #direnv  # as of 23.11 use programs.direnv
    #nix-direnv  # as of 23.11 use programs.direnv
    niv
    nix-template
    # Python
    python311Full
    # Go 
    go
    # haskell: 
    # - https://nixos.wiki/wiki/Haskell
    # - https://notes.srid.ca/haskell-nix
    ghc
    cabal-install
    cabal2nix
    stack
    #haskell-language-server
    # rust: 
    # - https://nixos.wiki/wiki/Rust
    # - https://christine.website/blog/how-i-start-nix-2020-03-08
    rustc
    rustfmt
    cargo
    rust-code-analysis
    rust-analyzer
    rustpython
    rusty-man

    # IDE
    #vscode
    #vscode-fhs
    #vscode-with-extensions
    #https://vscodium.com/
    #vscodium
    vscodium-fhs
    vscode-extensions.denoland.vscode-deno
    vscode-extensions.mkhl.direnv
    vscode-extensions.svelte.svelte-vscode
    # Database
    #kgt  # broken in 23.05
    
    # development-extras
    # use direnv/nix-shell for different dev environments
    #clang llvm 
    # https://discourse.nixos.org/t/how-do-i-install-rust/7491/8
    # Node.js / Deno  # use direnv/nix-shell for these
    #deno nodejs 
    # Erlang
    #erlangR24 elixir gleam lfe 
    # Pony  # use direnv
    #ponyc
    #pony-stable  # broken in 21.11 & 22.05
    #pony-corral
    #vimPlugins.vim-pony
    #vimPlugins.pony-vim-syntax
    #vimPlugins.nvim-treesitter-parsers.pony
    # Zig lang
    #zig
    #zls
    #vimPlugins.zig-vim
    #vimPlugins.nvim-treesitter-parsers.zig
    #Odin # use direnv
    #odin
    #ols
    #vimPlugins.nvim-treesitter-parsers.odin
    # WASM
    #wasm-pack wasmer
    # ada
    #gnat11  # failing in 22.05
    # agda
    #agda
    # idris
    #idris2 
    # formal analysis
    #beluga z3 
    # Machine Learning
    #cudnn (broken)
    # https://github.com/jetpack-io/devbox
    # https://news.ycombinator.com/item?id=32600821
    #devbox
    
    # development - web
    #html5validator  # lint & pretty-print for HTML, JS, CSS and others, use in direnv
    #rome  # lint & pretty-print for HTML, JS, CSS and others, use in direnv
    
    # knowledge management
    obsidian
    logseq
    #gollum  # server-based
    zk

    # Git extras
    git-extras
    git-lfs
    gitui
    gh
    lazygit
    oh-my-git
    pass-git-helper
    git-credential-gopass
    git-credential-keepassxc
    #TODO: git-branchless  # https://blog.waleedkhan.name/git-undo/, https://github.com/arxanas/git-branchless

    # Database
    sqlite
    sqlitebrowser
    
    # Secrets
    keepassxc
    gopass
    sops
    cotp
    #age
    #rage

    # browser extras 
    ungoogled-chromium
    brave
    nyxt
    #vieb  # vim-inspired electron browser
    opera
    microsoft-edge
    chrome-gnome-shell
    #w3m
    #lynx
    #vivaldi  # broken in 23.05
    #vivaldi-widevine
    #vivaldi-ffmpeg-codecs

    # Productivity
    #watson
    #timewarrior
    #gnomeExtensions.arbtt-stats # haskellPackages.arbtt  # let services.arbtt handle installation

    # Notes
    #joplin joplin-desktop simplenote nvpy standardnotes 
    #tomboy  # abandonned
    #gnote (broken)
    rnote
    typst
    typst-fmt
    #typst-lsp

    # IRC & chat 
    #znc
    #lynx
    #irssi_fish  # broken in 22.11
    haxor-news
    #tox-node
    #hexchat
    #weechat  # services.weechat.enable
    #weechatScripts.weechat-matrix
    jitsi
    discord
    ripcord
    #element-desktop  # matrix # broken in 23.11  # OpenSSL dependency marked insecure in 23.11
    #cinny-desktop  # matrix, Tauri  # OpenSSL dependency marked insecure in 23.11
    cinny  # matrix
    fluffychat  # matrix
    #fractal  # matrix app
    #gomuks  # matrix app
    #whalebird  # mastodon  # Electron dependency marked insecure in 23.11
    #nextcloud-client  # big kubernetes dependency
    #keybase  # let services.keybase handle this
    keybase-gui # may need to install manually:  nix-env -iA nixos.keybase-gui
    kbfs
    signal-desktop
    slack-dark
    #zulip  # broken in 23.05
    #zulip-term  # broken in 23.05
    #pidgin
    #purple-slack
    #purple-discord
    telegram-desktop
    #telegram-purple  # broken in 22.05
    #toxprpl  # gone in 22.11
    aether

    # PDF
    #pdfcrack pdfslicer pdftag pdfdiff  # all depend on xpdf, marked as insecure 
    pdfgrep
    pdfarranger
    zathura

    # ebooks
    calibre

    # Photos
    #digikam
    #darktable 

    # Office
    gnucash
    libreoffice
    onlyoffice-bin
    scribus
    pinpoint  # presentations

    # LaTeX
    #texstudio groff sent 

    # Mail
    thunderbird
    #alpine
    #mutt
    #neomutt
    #maddy 

    # Cryptocurrency
    bitcoin
    bitcoind
    miniscript
    electrum
    electrs
    #exodus  # build failing 22.05
    cointop
    cryptop
    pycoin

    # Research
    zotero
    qnotero

    # Math
    #julia
    #julia-stable  # broken in 21.11
    julia-stable-bin
    rWrapper
    #sageWithDoc  # broken 23.11 unstable
    #python39Packages.numpy
    gap
    #gap-full
    
    # Provers
    # Want Lean4 but seems not in packages.
    # https://github.com/leanprover/lean4
    # Use elan installation manager to get lean4 (or other version) instead.
    elan  # small tool to manage installations of the lean theorem prover
    #lean
    #lean2  # broken in 21.11
    minisat
    minizinc
    #minizincide  # Qt dependency marked insecure in 23.11
    gappa
    semgrep
    yices

    # Octave
    #octave
    
    # Science
    #python39Packages.scipy
    #spyder  # broken in 23.11-unstable

    # CAD
    #freecad

    # Image Viewers
    #vimiv (marked as broken) 

    # Graphics
    #gimp  # slightly higher minor version than gimp-with-plugins 
    gimp-with-plugins
    obs-studio
    imagemagick
    krita
    inkscape-with-extensions
    #akira-unstable  # and get Photogimp plugin from github
    #blender  # broken in 23.11 unstable
    #natron  # broken, pulls ffmpeg which has CVE.  also check out Fusion, not FOSS but free

    # Media
    mpv
    mpvc
    mplayer
    smplayer
    vlc
    libvlc
    ffmpeg
    freetube
    streamlink-twitch-gui-bin
    #tvheadend  # only if HDHomeRun enabled

    # Audio Editing
    audacity
    #lmms
    #ardour
    #zrythm
    #libav  # marked as broken in 21.11

    # Music
    #general clients
    audacious
    
    # mpd & friends
    # for mpd and mopidy config see services.mpd and services.mopidy
    #mopidy-mpd
    #ncmpcpp
    #vimpc
    
    # Jellyfin & friends
    # use services.jellyfin.enable for server
    #jellyfin
    #jellycli  # tui client
    #jftui  # tui client
    #sonixd  # desktop client
    #jellyfin-media-player  # plex-based desktop player
    #mopidy-jellyfin
    
    # Logitech Media Server (LMS/slimserver)
    # services.slimserver.enable=true
    # services.slimserver.dataDir=/zdata0/Music/LMS/
    #slimserver
    
    # cmus 
    #cmus
    #cmusfm  # scrobbler
    #gnomeExtensions.cmus-status

    # spotify
    spotify
    #ncspot
    #spotify-tui
    #termusic

    # Music tag editing & library managers
    #beets
    #beets-unstable

    # CD / DVD
    brasero
    handbrake
    lxdvdrip

    # Download
    #axel
    httrack
    #python39Packages.aria2p persepolis  # aria build fails
    youtube-dl
    #tartube
    #aria
    #persepolis

    # Torrents
    rtorrent
    qbittorrent
    #enhanced-ctorrent
    deluge
    transmission-qt
    #vuze  # big java build process, don't install unless specifically needed
    #webtorrent_desktop
    #bittorrent-nox  (broken)
    #tribler (broken)
    #megasync

    # Remote Desktop (RDP, VNC) 	
    #x11vnc
    #tightvnc
    #turbovnc
    #tigervnc
    #gtk-vnc
    #x2goclient
    #remmina
    #gnomeExtensions.remmina-search-provider
    #nomachine-client
    #rustdesk  # long compile time, only install if needed

    # Home Assistant, Home Automation, & Security Cameras
    #home-assistant  # broken in 21.11
    #home-assistant-cli  # broken in 21.11
    #gnomeExtensions.home-assistant-extension  # broken in 21.11

    # AMD/ATI
    radeon-profile
    radeontop
    radeontools

    # Nvdia

    # WINE (wineWow are 64bit)
    #wine
    #wine-staging
    #wineWowPackages.base
    #wineWowPackages.full
    wineWowPackages.fonts
    #wineWowPackages.minimal
    #wineWowPackages.stable
    wineWowPackages.stableFull
    #wineWowPackages.staging
    #wineWowPackages.stagingFull
    #wineWowPackages.unstable
    #wineWowPackages.unstableFull
    #wineWowPackages.wayland
    #wineWowPackages.waylandFull
    winetricks
    protontricks
    protonup-qt
    vulkan-tools
    #bottles
    
    # Lutris
    #lutris-unwrapped
    lutris

    # Lutris dependencies
    # https://github.com/lutris/docs/blob/master/Battle.Net.md
    gnutls
    openldap
    libgpgerror
    freetype
    #corefonts
    libxml2
    xml2
    SDL2

    # Steam
    # all handled by programs.steam.enable and steam.override
    #steam # steamPackages.steamcmd steam-tui
    # https://discourse.nixos.org/t/fix-steam-black-library-store/14965/9?u=bgibson
    #pango
    #libthai
    #harfbuzz
    steam-run
    
    # Games
    #factorio (use Steam, Lutris, or direct download appimage instead)
    #eidolon
    # Heroic Games Launcher
    #heroic-unwrapped  # broken in 23.11-unstable, was working, probably temporary unstable build bug
    #heroic  # broken in 23.11-unstable
    gogdl
    # Misc
    appimage-run
    appimagekit
    ajour
    jstest-gtk
    sdl-jstest

  ]
  # Enable for full KDE metapackage
  #++ builtins.filter lib.isDerivation(builtins.attrValues plasma5Packages.kdeGear)
  #++ builtins.filter lib.isDerivation(builtins.attrValues plasma5Packages.kdeFrameworks)
  #++ builtins.filter lib.isDerivation(builtins.attrValues plasma5Packages.plasma5)
  ;

  ################################################################################
  # Program Config
  ################################################################################

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs.mtr.enable = true;

  # https://github.com/nix-community/nix-direnv
  # direnv config
  nix.settings = {
    keep-outputs = true;
    keep-derivations = true;
  };

  programs.direnv = {
    enable = true;
    package = pkgs.direnv;
    silent = false;
    #persistDerivations = true;  # removed in 23.11
    loadInNixShell = true;
    direnvrcExtra = "";
    nix-direnv = {
      enable = true;
      package = pkgs.nix-direnv;
    };
  };

  # : https://nixos.org/manual/nixos/unstable/index.html#module-services-flatpak
  services.flatpak.enable = true;
  xdg.portal.enable = true;

  # Hyprland
  #xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  programs.zsh = {
    enable = true;
    ohMyZsh = {
      enable = true;
      #plugins = [ "ansible" "ant" "aws" "branch" "cabal" "colored-man-pages" "colorize" "command-not-found" "common-aliases" "copydir" "cp" "copyfile" "dotenv" "docker" "docker-compose" "docker-machine" "emacs" "fzf" "git" "git-extras" "git-lfs" "golang" "grc" "history" "lxd" "man" "mosh" "mix" "nmap" "node" "npm" "npx" "nvm" "pass" "pip" "pipenv" "python" "ripgrep" "rust" "rsync" "safe-paste" "scd" "screen" "stack" "systemadmin" "systemd" "tig" "tmux" "tmux-cssh" "ufw" "urltools" "vi-mode" "vscode" "wd" "z" "zsh-interactive-cd" ];
      plugins = [
        "cabal"
        "colored-man-pages"
        "colorize"
        "command-not-found"
        "emacs"
        "git"
        "git-extras"
        "git-lfs"
        "golang"
        "history"
        "man"
        "mosh"
        "nmap"
        "ripgrep"
        "rust"
        "rsync"
        "safe-paste"
        "scd"
        "screen"
        "stack"
        "systemd"
        "tig"
        "tmux"
        "tmux-cssh"
        "urltools"
        "vi-mode"
        "z"
        "zsh-interactive-cd"
      ];
      #theme = "spaceship";
      #theme = "jonathan"; 
      theme = "juanghurtado";
      # themes w/ commit hash: juanghurtado peepcode simonoff smt theunraveler sunrise sunaku 
      # cool themes: linuxonly agnoster blinks crcandy crunch essembeh flazz frisk gozilla itchy gallois eastwood dst clean bureau bira avit nanotech nicoulaj rkj-repos ys darkblood fox 
    };
  };

  #programs.fish = {
    #enable = true;
    #useBabelfish = ;
    #shellInit = ;
    #shellAliases = ;
    #shellAbbrs = ;
    #promptInit = ;
    #vendor = {
    #  functions.enable = true;
    #  config.enable = true;
    #  completions.enable = true;
    #};
    #loginShellInit = ;
    #interactiveShellInit = ;
  #};

  programs.vim = {
    defaultEditor = true;
    package = pkgs.vim;
    #package = pkgs.vim-full;
  };

  programs.neovim = {
    enable = true;
    defaultEditor = false;
    #vimAlias = true;
    #viAlias = true;
    #withRuby = true;
    #withPython3 = true;
    #withNodeJs = true;
    #configure = {};
    #runtime = {
      #<name> = {
        #source = /path/to/source/file;
        #target = /name/of/symlink;
        #text = '' strings concatenated with "\n" '';
      #};
    #};
  };

  services.keybase.enable = true;
  services.kbfs = {
    enable = true;
    #mountPoint = ;
    #extraFlags = ;
    #enableRedirector = ;
  };

  # https://search.nixos.org/options?channel=21.05&show=services.arbtt.enable&query=arbtt
  #services.arbtt = {
    #enable = true;
    #package = ;
    #sampleRate = ;
    #logFile = ;
  #};

  # periodically updatedb
  # https://search.nixos.org/options?channel=21.05&show=services.locate.enable&query=services.locate
  services.locate = {
    enable = true;
    prunePaths = [ "/zdata0" ]; # no trailing /
  };

  # enable acpi
  # https://search.nixos.org/options?channel=21.05&show=services.acpid.enable&query=services.acpid
  services.acpid.enable = true;

  # Plotinius
  # https://nixos.org/manual/nixos/unstable/index.html#module-program-plotinus
  # Plotinus is a searchable command palette in every modern GTK application. 
  #programs.plotinus.enable = true;

  # Emacs server
  # https://nixos.org/manual/nixos/unstable/index.html#module-services-emacs-running
  # Ensure that the Emacs server is enabled for your user's Emacs 
  # configuration, either by customizing the server-mode variable, or by 
  # adding (server-start) to ~/.emacs.d/init.el. 
  # To start the daemon, execute the following:
  #systemctl --user daemon-reload  # force systemd reload
  #systemctl --user start emacs.service  # start the Emacs daemon
  # To connect to the emacs daemon, run one of the following:
  #emacsclient FILENAME
  #emacsclient --create-frame  # opens a new frame (window)
  #emacsclient --create-frame --tty  # opens a new frame on the current terminal
  #services.emacs = {
  #enable = true;
  #defaultEditor = true;  # (make sure no EDITOR var in .profile, .zshenv, etc)
  #package = import /home/bgibson/.emacs.d { pkgs = pkgs; };
  #};

  # enable Steam: https://linuxhint.com/how-to-instal-steam-on-nixos/
  # proton logs: https://github.com/ValveSoftware/Proton/wiki/Proton-FAQ#how-to-enable-proton-logs
  programs.steam.enable = true;
  #hardware.steam-hardware.enable = true  # for Steam controllers and VR hardware
  # no longer needed:
  # https://www.reddit.com/r/NixOS/comments/pnwhmz/does_anybody_else_have_this_problem_with_steam_no/
  # https://github.com/NixOS/nixpkgs/pull/137475
  # https://github.com/NixOS/nixpkgs/issues/137279#issuecomment-917311661 (temporary until solution backported)

  # Docs: https://github.com/FeralInteractive/GameMode
  # Example: https://github.com/FeralInteractive/gamemode/blob/master/example/gamemode.ini
  programs.gamemode = {
    enable = true;
    enableRenice = true;
    settings = {
      general = {
        renice = 5;  # 0 is default, means no change. can set 0 - 20.
      };

      # Warning: GPU optimisations have the potential to damage hardware
      #gpu = {
        #apply_gpu_optimisations = "accept-responsibility";
        #gpu_device = 0;
        #amd_performance_level = "high";
      #};

      custom = {
        start = "${pkgs.libnotify}/bin/notify-send 'GameMode started'";
        end = "${pkgs.libnotify}/bin/notify-send 'GameMode ended'";
      };
    };
  };

  # Mopidy
  #services.mopidy = {
  #  #dataDir = ;  # default is /var/lib/mopidy/data
  #  extensionPackages = [
  #    pkgs.mopidy-mpd
  #    pkgs.mopidy-mpris
  #    pkgs.mopidy-local
  #    pkgs.mopidy-youtube
  #    pkgs.mopidy-podcast
  #    pkgs.mopidy-spotify
  #    pkgs.mopidy-soundcloud
  #  ];
  #  #configuration = "";
  #  #extraConfigFiles = [];      
  #};

  # mpd
  #services.mpd = {
  #enable = true;
    #dataDir = "~/.local/share/mpd/data/";  # default is /var/lib/mpd
  #  startWhenNeeded = false;
    #extraConfig = "";
    #credentials = [
    #  {
    #    passwordFile = "/var/lib/secrets/mpd_readonly_password";
    #    permissions = [
    #      "read"
    #    ];
    #  }
    #  {
    #    passwordFile = "/var/lib/secrets/mpd_admin_password";
    #    permissions = [
    #      "read"
    #      "add"
    #      "control"
    #      "admin"
    #    ];
    #  };
    #];    
  #};

  # https://www.navidrome.org/
  # https://nixos.org//manual/nixos/stable/options.html#opt-services.navidrome.enable
  #services.navidrome = {
  #  enable = true;
  #  settings = ;
  #};

  # Trezor
  #https://nixos.org/manual/nixos/unstable/index.html#trezor
  #services.trezord.enable = true;

  # Digital Bitbox
  #https://nixos.org/manual/nixos/unstable/index.html#module-programs-digitalbitbox
  #programs.digitalbitbox.enable = true;
  #hardware.digitalbitbox.enable = true;

}
