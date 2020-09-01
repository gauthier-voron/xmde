#!/bin/bash

VDISK='testing/daemon.img'
SSHPORT=8022

if [ ! -f "$VDISK" ] ; then
    echo "$0: require a virtual machine '$VDISK'"
    echo "Please install a virtual system on the specified file with the"
    echo "  required dependencies and an ssh server"
    exit 1
fi >&2

# Install a handler for exit to clean up in case of abrupt termination.
#
tempdir="$(mktemp -d --suffix='.d' 'testing.XXXXXXXXXX')"
atexit() {
    if [ "x${qemu_pid}" != 'x' ] ; then
	kill -TERM ${qemu_pid}
    fi
    rm -rf "$tempdir"
}
trap atexit 'EXIT'

# Boot the virtual system in snapshot mode.
# That way the modification made are not committed to the virtual disk.
#
echo "Launch virtual machine"
mkfifo "$tempdir/qemu.fifo"
(
    while read cmd ; do
	echo "$cmd"
    done < "$tempdir/qemu.fifo"
) | qemu-system-x86_64 -enable-kvm -smp 1 -m '2G' \
	-drive file="$VDISK",media='disk',if='virtio',snapshot=on,format=raw \
	-net user,hostfwd=::"$SSHPORT"-:22 -net nic -monitor stdio \
	> '/dev/null' &
qemu_pid=$!
exec 3> "$tempdir/qemu.fifo"

# Define the function that makes possible to type commands in the virtual
# machine as if typed by the user.
#
sendstring() {
    local str="$1"
    local c code

    while [ "x$str" != 'x' ] ; do
	c="${str:0:1}"
	str="${str:1}"

	case "$c" in
	    ' ') code='spc'   ;;
	    '.') code='dot'   ;;
	    '/') code='slash' ;;
	    *)   code="$c"    ;;
	esac

	echo sendkey "$code" >&3
    done

    echo sendkey 'ret' >&3
}

# Wait for the virtual system to be ready.
#
echo "Wait ssh connection"
sleep 30
while ps ${qemu_pid} > /dev/null 2> /dev/null ; do
    if ssh -p "$SSHPORT" -o ConnectTimeout=3 -o StrictHostKeyChecking=no \
	   -o LogLevel=Quiet -o UserKnownHostsFile='/dev/null' \
	   user@localhost true 2>/dev/null
    then
	break
    fi
done

echo "Virtual machine is ready"
sendstring 'user'
while true ; do
    printf "Press a key to install and launch xmde : "
    read key

    dist="$tempdir/distrib.tgz"
    tar -czf "$dist" 'install.sh' 'config' 'icons' 'scripts'

    ssh -N -f -o ControlMaster=yes -o ControlPath='daemon.sock' \
	-o StrictHostKeyChecking=no -o LogLevel=Quiet \
	-o UserKnownHostsFile='/dev/null' -p "$SSHPORT" \
	user@localhost

    sleep 1

    scp -o ControlMaster=no -o ControlPath='daemon.sock' \
	"$dist" user@localhost:'dist.tgz'
    rm "$dist"

    ssh -o ControlMaster=no -o ControlPath='daemon.sock' user@localhost \
	tar -xzf 'dist.tgz'
    ssh -o ControlMaster=no -o ControlPath='daemon.sock' user@localhost \
	sudo ./install.sh --user='user' --locker='yes'
    ssh -o ControlMaster=no -o ControlPath='daemon.sock' user@localhost \
	killall xinit

    sleep 3

    sendstring 'startx /etc/xmde/rc'
done
