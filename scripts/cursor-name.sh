#!/bin/sh
#
#   Set the default cursor shape for XMonad Desktop Environment.
#   Define the cursor as the X11 left_ptr shape. This avoid to have the ugly
#   black cross when the cursor is above no window.
#   The size of this cursor is defined by the 'Xcursor.size' property in
#   '/etc/xmde/Xresources'.
#

xsetroot -cursor_name 'left_ptr'
