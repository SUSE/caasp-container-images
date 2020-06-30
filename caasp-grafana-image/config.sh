#!/bin/sh
################################################################################
# config.sh runs at the end of the prepare step, after users have been set,
# packages installed, and the overlay filesystem created.
################################################################################
# http://osinside.github.io/kiwi/working_with_kiwi/shell_scripts.html
# include Kiwi functions and vars
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

OLDIFS="$IFS"  # to restore normal behavior
DIRIFS="/$IFS" # to split directory components

entrypoint="./usr/local/bin/entrypoint.sh"
if [ -f "$entrypoint" ]
then
    Debug "Setting recursive permissions on entrypoint '$entrypoint'"
    p=""
    IFS="$DIRIFS"
    for component in $entrypoint
    do
        IFS="$OLDIFS"
        p="${p:-}${p:+/}$component"
        Debug $(chmod -v 0755 "$p")
        IFS="$DIRIFS"
    done
    IFS="$OLDIFS"
else
    Echo "Failed to find entrypoint '$entrypoint'; things will break"
fi
