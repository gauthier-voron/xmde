#!/bin/bash
#
#   Installation script for XMDE
#
#   Install the system-wide components for the XMonad Desktop Environment.
#   Depending on specified options, also enable autologin at boot and user
#   specific installation.
#

# Default parameters  - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Default durectory where to install XMDE.
# If the directory does not exist, create it.
#
DEFAULT_PREFIX='/'

# Default behavior for user installation.
# If set to '', does not install anything.
# If set to '/etc/skel', install in the '/etc/skel' directory.
# Otherwise, it is a coma separated list of username to install for.
#
DEFAULT_USER='/etc/skel'

# Default behavior for screen lock enabling.
# If set to 'no', does not enable screen lock.
# If set to 'yes', does not enable screen lock
#
DEFAULT_LOCKER='no'


# Function definitions  - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Parse command line options.
# This is a wrapper around getopt standard function.
#
parseopts() {
    local shortopts="$1" ; shift
    local longopts=""
    local separator=''

    while [ $# -gt 0 ] ; do
	if [ "x$1" = 'x--' ] ; then
	    break
	fi
	longopts="${longopts}${separator}$1"
	separator=','
	shift
    done

    getopt -l "$longopts" -o "$shortopts" "$@"
}


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#                           Main script starts here
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Define options in short and long form.
# Parse command line options and assign default values if needed.
#
OPT_SHORT='hl:p:u:V'
OPT_LONG=('help' 'locker:' 'prefix:' 'user:' 'version')

eval "set -- $(parseopts "$OPT_SHORT" "${OPT_LONG[@]}" -- "$@")"

while true ; do
    case "$1" in
	-h|--help)       usage; exit 0 ;;
	-l|--locker)     shift; LOCKER="$1"; DEFINED_LOCKER=1 ;;
	-p|--prefix)     shift; PREFIX="$1"; DEFINED_PREFIX=1 ;;
	-u|--user)       shift; USERINST="$USERINST,$1"; DEFINED_USER=1 ;;
	-V|--version)    version; exit 0 ;;
	--)              shift; break ;;
    esac
    shift
done

# Assign default values to the unassigned option values.
# This step is necessary because the '--user' option append values instead of
# replacing them.
#
if [ "x${DEFINED_LOCKER}" = 'x' ] ; then
    LOCKER="${DEFAULT_LOCKER}"
fi
if [ "x${DEFINED_PREFIX}" = 'x' ] ; then
    PREFIX="${DEFAULT_PREFIX}"
fi
if [ "x${DEFINED_USER}" = 'x' ] ; then
    USERINST="${DEFAULT_USER}"
else
    USERINST="${USERINST:1}"
fi

# Install system wide, default files.
#   - Executable files
#   - Confgiuration files
#   - Shared resources
#   - Systemd services
#

# Executable files.
#
install -d -m755 "$PREFIX/usr/bin"
for file in 'xmde-appmenu' 'xmde-docmenu' 'xmde-highlight' 'xmde-lock'  \
	    'xmde-menu' 'xmde-mpd-notify' 'xmde-restart' 'xmde-screen' \
	    'xmde-screenmenu' 'xmde-start' 'xmde-statusbar' 'xmde-touchpad' \
	    'xmde-volume' 'xmde-wallpaper' 'xmde-xmobar'
do
    install -m755 "scripts/$file" "$PREFIX/usr/bin/$file"
done

install -d -m755 "$PREFIX/etc/xmde/xinitrc.d"
for file in '10-systemctl-import-display'
do
    install -m755 "scripts/$file" "$PREFIX/etc/xmde/xinitrc.d/$file"
done

# Configuration files.
#
install -d -m755 "$PREFIX/etc/xmde"
for file in 'lockscreen.txt' 'rc' 'Xresources' 'xmenu.conf' 'xmobar.conf'
do
    install -m644 "config/$file" "$PREFIX/etc/xmde/$file"
done
install -m644 "config/xmonad.hs" "$PREFIX/etc/xmde/xmonad.default.hs"

# Shared resources.
#
install -d -m755 "$PREFIX/usr/share/icons/xmde"
for dir in 'icons/'* ; do
    cp -R "$dir" "$PREFIX/usr/share/icons/xmde"
done

# Systemd services.
#
install -d -m755 "$PREFIX/usr/lib/systemd/system"
install -m644 "config/suspend.service" \
	"$PREFIX/usr/lib/systemd/system/suspend.service"



# Install user specific files, depending on USERINST value.
# Be sure to give ownership of installed files to appropriate user.
#
install -d -m755 "$PREFIX/etc/skel/.xmonad"
install -m644 "config/xmonad.hs" "$PREFIX/etc/skel/.xmonad/xmonad.hs"

install -d -m755 "$PREFIX/etc/skel/.config/dunst"
install -m644 "config/dunstrc" "$PREFIX/etc/skel/.config/dunst/dunstrc"

if [ "x$USERINST" != 'x/etc/skel' ] ; then

    while [ "x$USERINST" != 'x' ] ; do
	userinst="$(echo "$USERINST" | cut -d',' -f1)"
	USERINST="${USERINST#$userinst}"
	USERINST="${USERINST#,}"

	if [ "x$(whoami)" != 'xroot' ]  ; then
	    continue
	elif [ ! -d "$PREFIX/home/$userinst" ] ; then
	    continue
	elif ! id "$userinst" > /dev/null 2> /dev/null ; then
	    continue
	fi

	opts="-o $(id --user "$userinst") -g $(id --group "$userinst")"

	install -d -m755 $opts "$PREFIX/home/$userinst/.xmonad"
	install -m644  $opts "config/xmonad.hs" \
	     "$PREFIX/home/$userinst/.xmonad/xmonad.hs"

	install -d -m755 $opts "$PREFIX/home/$userinst/.config/dunst"
	install -m644 $opts "config/dunstrc" \
	     "$PREFIX/home/$userinst/.config/dunst/dunstrc"
    done
fi

# Enable systemd suspend related service if needed by LOCKER.
#
if [ "x${LOCKER}" = 'xyes' ] ; then
    install -d -m755 "$PREFIX/etc/systemd/system/suspend.target.wants"
    ln -s '/usr/lib/systemd/system/suspend.service' \
       "$PREFIX/etc/systemd/system/suspend.target.wants/suspend.service"
fi
