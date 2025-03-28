#!/bin/bash
set -e

# --------------------------
# Default Values
# --------------------------
DEFAULT_DISK="/dev/sda"
DEFAULT_EFI_SIZE="512M"
DEFAULT_USERNAME="user"
DEFAULT_HOSTNAME="archlinux"
DEFAULT_TIMEZONE="Europe/London"

# --------------------------
# Function: User Input Prompts
# --------------------------
gather_user_input() {
    echo "=== Arch Linux Automated Installer (UEFI + KDE Plasma + Pamac) ==="
    lsblk
    read -p "Enter the target disk [$DEFAULT_DISK]: " TARGET_DISK
    TARGET_DISK=${TARGET_DISK:-$DEFAULT_DISK}
    read -p "Create EFI partition size [$DEFAULT_EFI_SIZE]: " EFI_SIZE
    EFI_SIZE=${EFI_SIZE:-$DEFAULT_EFI_SIZE}
    read -p "Enter username for non-root user [$DEFAULT_USERNAME]: " USERNAME
    USERNAME=${USERNAME:-$DEFAULT_USERNAME}
    read -p "Enter hostname [$DEFAULT_HOSTNAME]: " HOSTNAME
    HOSTNAME=${HOSTNAME:-$DEFAULT_HOSTNAME}
    read -p "Enter timezone [$DEFAULT_TIMEZONE]: " TIMEZONE
    TIMEZONE=${TIMEZONE:-$DEFAULT_TIMEZONE}
}

# --------------------------
# Function: Partitioning & Formatting
# --------------------------
partition_and_format() {
    read -p "WARNING: This will erase ALL data on $TARGET_DISK. Continue? [y/N]: " CONFIRM
    [[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }

    echo "Partitioning $TARGET_DISK..."
    parted -s "$TARGET_DISK" mklabel gpt
    parted -s "$TARGET_DISK" mkpart "EFI" fat32 1MiB "$EFI_SIZE"
    parted -s "$TARGET_DISK" mkpart "ROOT" ext4 "$EFI_SIZE" 100%

    EFI_PART="${TARGET_DISK}1"
    ROOT_PART="${TARGET_DISK}2"

    echo "Formatting partitions..."
    mkfs.fat -F32 "$EFI_PART"
    mkfs.ext4 -F "$ROOT_PART"

    mount "$ROOT_PART" /mnt
    mkdir -p /mnt/boot/efi
    mount "$EFI_PART" /mnt/boot/efi
}

# --------------------------
# Function: Install Base System
# --------------------------
install_base() {
    echo "Installing base system..."
    pacstrap /mnt base linux linux-firmware vim sudo networkmanager dhclient modemmanager \
                   grub efibootmgr wpa_supplicant wireless_tools
    genfstab -U /mnt >> /mnt/etc/fstab
}

# --------------------------
# Function: Chroot Configuration
# --------------------------
configure_chroot() {
    arch-chroot /mnt /bin/bash <<EOF
    set -e

    # Timezone & Locale
    ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
    hwclock --systohc
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    locale-gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf

    # Hostname & Hosts
    echo "$HOSTNAME" > /etc/hostname
    cat > /etc/hosts <<HOSTS_EOF
    127.0.0.1   localhost
    ::1         localhost
    127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
HOSTS_EOF

    # User & Sudo
    useradd -m -G wheel -s /bin/bash "$USERNAME"
    echo "Set password for $USERNAME:"
    passwd "$USERNAME"
    echo "%wheel ALL=(ALL) ALL" | EDITOR="tee" visudo -f /etc/sudoers.d/wheel

    # Bootloader
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg

    # Install KDE Plasma & Essentials
    pacman -Sy --noconfirm plasma-desktop sddm dolphin konsole firefox pamac flatpak \
                           xdg-desktop-portal-kde pipewire pipewire-pulse pipewire-alsa \
                           mesa vulkan-intel vulkan-radeon ntfs-3g cups bluez bluez-utils \
                           gst-libav gst-plugins-good gst-plugins-base gst-plugins-bad

    # Enable Services
    systemctl enable sddm NetworkManager bluetooth cups

    # Flatpak & Arch Linux CN Repo
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    echo -e "\n[archlinuxcn]\nServer = https://mirrors.ustc.edu.cn/archlinuxcn/\$arch\nServer = https://repo.archlinuxcn.org/\$arch" >> /etc/pacman.conf
    pacman -Sy --noconfirm archlinuxcn-keyring

    # Disable Root Login
    passwd -l root
EOF
}

# --------------------------
# Function: Post-Install Notes
# --------------------------
post_install_notes() {
    echo "Installation complete!"
    echo "1. Log in as $USERNAME"
    echo "2. Open Pamac → Preferences → enable Flatpak"
    echo "3. For printing: Open 'system-config-printer' to add printers."
}

# --------------------------
# Function: Reboot Prompt
# --------------------------
prompt_reboot() {
    read -p "Reboot now? [Y/n]: " REBOOT_CHOICE
    if [[ "$REBOOT_CHOICE" =~ ^[Nn]$ ]]; then
        echo "Unmount manually with 'umount -R /mnt' before rebooting."
    else
        umount -R /mnt
        reboot
    fi
}

# --------------------------
# Main Script Execution
# --------------------------
gather_user_input
partition_and_format
install_base
configure_chroot
post_install_notes
prompt_reboot
