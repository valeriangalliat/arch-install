# Mountpoint
declare MNT=/mnt

# Executes given command in chroot.
#
# $@: Arguments for `arch-chroot`
chrootx() {
    arch-chroot "$MNT" "$@"
}

# Retrieves a mirrorlist in `/etc/pacman.d/mirrorlist` for given
# country code.
#
# $1: Country code (`US`, `GB`, `FR`, etc)
mirrorlist() {
    local country=$1; shift
    local tmp=$(mktemp)

    # Retrieve mirrorlist from server
    curl -o "$tmp" "https://www.archlinux.org/mirrorlist/?country=$country"


    if ! cat "$tmp" | head -n 1 | grep -q "^##$"; then
        echo "Unable to find a mirrorlist for country '$country'." >&2
        return 1
    fi

    # Uncomment server lines
    sed -i "s/^#Server/Server/g" "$tmp"

    # Write new mirrorlist
    cat "$tmp" > /etc/pacman.d/mirrorlist
}

# Bootstraps the system in mountpoint. The packages `base` and `base-devel`
# are always installed.
#
# $@: Additional arguments for `pacstrap`
bootstrap() {
    pacstrap "$MNT" base base-devel "$@"
}

# Generates the fstab in mountpoint.
#
# $@: Arguments for `genfstab`
fstab() {
    genfstab "$@" "$MNT" >> "$MNT/etc/fstab"
}

# Generates given locale in mountpoint.
#
# $1: Locale (`en_US`, `en_US.UTF-8`, etc)
locale() {
    local locale=$1; shift

    if ! grep -q "^#$locale " "$MNT/etc/locale.gen"; then
        echo "Given locale '$locale' does not exists in '$MNT/etc/locale.gen'." >&2
        return 1
    fi

    # Uncomment locale
    sed -i "/^#$locale /s/^#//g" "$MNT/etc/locale.gen"

    # Generate
    chrootx locale-gen
}

# Creates initial RAM disk for Linux.
linux() {
    chrootx mkinitcpio -p linux
}

# Installs Syslinux in mointpoint.
#
# $1: Disk to boot (`sda1`, `sda2`, etc)
syslinuxi() {
    local disk=$1; shift

    # Install package and init
    pacstrap "$MNT" syslinux
    chrootx syslinux-install_update -aim

    # Change default disk to real disk
    sed -i "s/sda3/$disk/g" "$MNT/boot/syslinux/syslinux.cfg"
}

# Prompts for root password, unmount mountpoint recursively,
# appends configure script to root profile and reboots.
finish() {
    chrootx passwd &&
    umount -R "$MNT" &&
    echo "# AUTORUN ARCH CONFIGURE" >> .profile &&
    echo arch-deploy/bin/arch-configure >> .profile &&
    reboot
}

# Execute install script
. install
