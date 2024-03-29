# Custom_Ubuntu
Creating a custom OS can be challenging, so hopefully this repo makes life easier.  The targetted base Ubuntu OS variant is Xubuntu due to its lightweight display manager, but you can apply this approach to any Ubuntu variant.  It takes the base Xubuntu ISO and modifies it with various customizations and repackages it.  This build installs Google chrome to enable kiosk mode that listens to localhost over port 80, but these settings can be modified in `customize_os.sh`.  It also comes with a host of fonts that could be of good use, but could be disabled in `customize_os.sh`.  To build OS, it's relatively straight forward.  Run `make_iso.sh -h` to show possible options.

```
Usage: ./make_iso.sh [OPTION]... [VAR VALUE]...

  Build Options:
    --help                      show script usage
        -h
    --action VALUE              script action (build, update, remove)
        -a                          default: "build"
    --name VALUE                specify name
        -n                          default: "myos"
    --os_var VALUE              specify base OS variant
        -var                        default: "xubuntu"
    --os_pr VALUE               specify base OS point release
        -pr                         default: "20.04.6"
    --os_type VALUE             specify os type (desktop, server)
        -type                       default: "desktop"
    --os_arch VALUE             specify base OS architecture
        -arch                       default: "amd64"
    --base_iso_name VALUE       specify base iso name
        -bin                        default: "xubuntu-20.04.6-desktop-amd64"
    --base_iso_path PATH        specify path of base iso
        -bip                        default: "../base_iso"
    --custom_source_path PATH   specify path of custom source files
        -csp                        default: "../custom_files"
    --custom_output_path PATH   specify path of custom output
        -cop                        default: "."
    --workspace_path PATH       specify path of workspace
        -wp                         default: "iso_resources/myos_20.04.6_desktop_amd64"
    --snap_channel VALUE        specify snap channel (beta, candidate, stable)
        -sc                         default: "candidate"
    --preempt VALUE             specify type preempt=[none, voluntary, full]
        -p                          default: ""
    --date VALUE                specify date
        -d                          default: "2023.03.28"
    --time VALUE                specify time
        -t                          default: "17.13.43"
    --quiet                     less verbose
        -q                          default: "false"

Example: sudo ./make_iso.sh --action "build" -n "test" --os_pr "20.04.6" --os_type "desktop" --os_arch "amd64" -q

[WARN] This only has been tested only on Xubuntu 20.04 and 22.04 variant
```


There are some sub-scripts to install various AWS tools if needed.  They are commented out in `customize_os.sh`, but put them to use if needed.  There is a good amount of comments, but feel free to raise issues as needed.


## High Level Workflow
1. Check and set variables from arguments
1. Update the host operating system and upgrade all packages
1. Install necessary build packages
1. Download base ISO, its SHA256SUMS and gpg signature
1. Determine --action as specified from arguments
    1. If `update`:
        1. Chroot into the workspace
    1. If `build`:
        1. Mount and extract the base ISO
        1. Unsquash the file system as the custom root
    1. If `remove`:
        1. Remove workspace and exit script
1. Mount various points and chroot the workspace
1. Run customization script (`customize_os.sh`)
    1. Update the custom root operating system and upgrade all packages
    1. Install various packages
    1. Purge various packages
    1. ~~Install AWS services~~
    1. Set default OS settings
    1. Generate preseed scripts
    1. Update and upgrade for good measures
    1. Clean up kernels
    1. Build initramfs
    1. Generate manifest
    1. Generate slideshow
1. Copy changelog
1. Update the boot files `vmlinuz` and `initrd`
1. Generate the disk manifest
1. Squash the custom root  using xz compression algorithm (best)
1. Sign the squashfs (optional)
1. Generate various disk info (e.g. loopback, preseed, etc)
1. Generate MD5 sum
1. Generate MBR and EFI for backwards compability boot (i.e. 20.04 or lower)
1. Generate ISO via xorriso