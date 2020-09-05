#!/bin/bash


DISK='/dev/vda'
ROOT='/dev/vda1'


DEPENDENCIES=(
    'bash'
    'dmenu' 'dunst'
    'feh'
    'imagemagick'
    'libnotify'
    'perl' 'physlock'
    'rxvt-unicode'
    'ttf-liberation'
    'xcompmgr' 'xmobar' 'xmonad' 'xmonad-contrib' 'xorg-server' 'xorg-xinit'
    'xorg-xinput' 'xorg-xprop' 'xorg-xrandr' 'xorg-xset'
)

# Note: transset-df is not in the official repository anymore but still the
#       only option to have per application transparency


echo "Create root parition on '$DISK'"
{
    printf 'label: dos\n'
    printf 'bootable, type=%s\n' "83"
} | sfdisk -q "$DISK"

echo "Wait for kernel update ..."
sleep 1

echo "Format partition '$ROOT'"
yes | mkfs.ext4 -q "$ROOT"

echo "Mount partition"
mount "$ROOT" '/mnt'

echo "Install base system"
pacstrap '/mnt' 'base' 'dhcpcd' 'linux' 'linux-firmware' 'grml-zsh-config' \
	 'grub' 'netctl' 'openssh' 'sudo' 'zsh' "${DEPENDENCIES[@]}"

echo "Generate '/etc/fstab'"
genfstab -U '/mnt' >> '/mnt/etc/fstab'

echo "Generate ethernet profile"
ip addr show scope global | sed -nr 's/^[[:digit:]]+: (e[^:]*):.*$/\1/p' \
    | while read if ; do
    (
	printf "Description='Ethernet on %s / no security'\n" "$if"
	printf 'Connection=ethernet\n'
	printf 'Interface=%s\n' "$if"
	printf 'IP=dhcp\n'
    ) > "/mnt/etc/netctl/ethernet"
done


echo "Install chrooted system"
perl -wnle 'print if ( $ac ); $ac = 1 if ( /^### arch-chroot ###$/ );' "$0" \
     > '/mnt/root/install.sh'
chmod 755 '/mnt/root/install.sh'
arch-chroot '/mnt' '/root/install.sh'

echo "Umount installed system"
umount '/mnt'


echo "Install complete"
poweroff


### arch-chroot ###
#!/bin/bash


DISK='/dev/vda'


echo "Install GRUB on '$DISK'"
grub-install --target=i386-pc "$DISK"
sed -ri 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=2/' '/etc/default/grub'
grub-mkconfig -o '/boot/grub/grub.cfg'

echo "Setup sudo configuration"
groupadd --system --force 'sudo'
(
    echo 'root ALL=(ALL) ALL'
    echo '%sudo ALL=(ALL) ALL'
) > '/etc/sudoers.d/privileged-users'

echo "Create new user"
useradd --gid 'users' --groups 'sudo' --create-home --no-user-group \
	--shell '/usr/bin/zsh' 'user'

echo "Setup default shell"
chsh -s '/usr/bin/zsh'
chsh -s '/usr/bin/zsh' 'user'

echo "Remove passwords"
passwd -d 'user'
passwd -d 'root'

echo "Enable network"
netctl enable 'ethernet'

echo "Setup OpenSSH server"
sed -ri 's/^.*PermitEmptyPassword.*$/PermitEmptyPasswords yes/' \
    '/etc/ssh/sshd_config'

systemctl enable 'sshd.service'
