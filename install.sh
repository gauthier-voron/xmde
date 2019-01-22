#!/bin/sh

DESTDIR="$1"

install -d -m755 "$DESTDIR/etc/skel/.xmonad"
install -m644 "config/xmonad.hs" "$DESTDIR/etc/skel/.xmonad/xmonad.hs"

install -d -m755 "$DESTDIR/etc/systemd/system"
install -m644 "config/suspend@.service" \
	"$DESTDIR/etc/systemd/system/suspend@.service"

install -d -m755 "$DESTDIR/etc/xmde"
for file in 'lockscreen.txt' 'rc' 'Xresources' 'xmenu.conf' 'xmobar.conf'
do
    install -m644 "config/$file" "$DESTDIR/etc/xmde/$file"
done

install -d -m755 "$DESTDIR/etc/xmde/xinitrc.d"
install -m644 "scripts/cursor-name.sh" \
	"$DESTDIR/etc/xmde/xinitrc.d/90-cursor-name.sh"

install -d -m755 "$DESTDIR/usr/bin"
for file in 'xmde-appmenu' 'xmde-docmenu' 'xmde-highlight' 'xmde-lock' \
	    'xmde-menu' 'xmde-restart' 'xmde-screen' 'xmde-screenmenu' \
	    'xmde-start' 'xmde-statusbar' 'xmde-volume' 'xmde-wallpaper' \
	    'xmde-xmobar'
do
    install -m755 "scripts/$file" "$DESTDIR/usr/bin/$file"
done

install -d -m755 "$DESTDIR/usr/share/icons/xmde"
for dir in 'icons/'* ; do
    cp -R "$dir" "$DESTDIR/usr/share/icons/xmde"
done
