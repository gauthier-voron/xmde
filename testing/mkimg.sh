#!/bin/bash

set -e

VDISK='testing/daemon.img'
ISOSOURCE='https://www.archlinux.org/download'
ISOMIRROR='https://mirror.aarnet.edu.au/pub/archlinux/iso'
INSTALL='testing/install.sh'
SIZE='4G'


echo "Create working directory"
TEMPDIR="$(mktemp -d --tmp --suffix='.d' 'xmde-mkimg.XXXXXX')"

trap "rm -rf '$TEMPDIR'" 'EXIT'


download_iso() {
    local dest="$1" ; shift
    local wdir isodate

    wget "$ISOSOURCE" --quiet -O "$TEMPDIR/source.html"
    isodate="$(perl -wnle \
        's/^.*Current Release.*(\d{4}\.\d{2}\.\d{2}).*$/$1/ and print' \
        "$TEMPDIR/source.html")"

    wget --quiet "$ISOMIRROR/$isodate/archlinux-$isodate-x86_64.iso" -O "$dest"
}

wait_idle() {
    local precision="$1"
    local valid line

    valid=0

    if [ "x$precision" = 'x' ] ; then
	precision=30
    fi

    while read line ; do
	if echo "$line" | grep -q '^(qemu)' ; then
	    sleep .01
	    echo info registers
	fi

	if echo "$line" | grep -q 'HLT=1' ; then
	    valid=$(( valid + 1 ))
	elif echo "$line" | grep -q 'HLT=0' ; then
	    valid=0
	fi

	if [ $valid -eq $precision ] ; then
	    valid=0
	    break
	fi
    done
}

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

	echo sendkey "$code"
    done

    echo sendkey 'ret'
}


if [ -f "$VDISK" ] ; then
    echo "$0: cannot create virtual disk '$VDISK'"
    echo "This file already exists"
    exit 1
fi >&2

echo "Download latest archiso"
download_iso "$TEMPDIR/archlinux.iso"

echo "Allocate virtual disk '$VDISK'"
truncate --size="$SIZE" "$VDISK"

mkfifo "$TEMPDIR/qemu-stdin"
mkfifo "$TEMPDIR/qemu-stdout"

(
    exec 3>&1
    exec > "$TEMPDIR/qemu-stdin"

    read line < "$TEMPDIR/qemu-stdout"
    sleep 1
    echo info registers

    echo "Wait for archiso boot menu..." >&3
    wait_idle 10 < "$TEMPDIR/qemu-stdout" > "$TEMPDIR/qemu-stdin"
    sendstring '' > "$TEMPDIR/qemu-stdin"

    sleep 3
    echo "Wait for archiso root prompt..." >&3
    wait_idle 10 < "$TEMPDIR/qemu-stdout"

    echo "Run install script on virtual machine" >&3
    sendstring 'cp /dev/vdb install.sh'
    sendstring 'chmod 755 install.sh'
    sendstring './install.sh'
) &
starter_pid=$!

echo "Boot install virtual machine"
qemu-system-x86_64 -enable-kvm -smp 1 -m '2G' \
    -drive file="$TEMPDIR/archlinux.iso",media='cdrom',format=raw \
    -drive file="$VDISK",media='disk',if='virtio',format=raw \
    -drive file="$INSTALL",media='disk',if='virtio',snapshot=on,format=raw \
    -net user -net nic -monitor stdio \
    < "$TEMPDIR/qemu-stdin" > "$TEMPDIR/qemu-stdout"
