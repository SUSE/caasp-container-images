#!/bin/bash

#======================================
# Functions...
#--------------------------------------
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

#======================================
# Greeting...
#--------------------------------------
echo "Configure image: [$kiwi_iname]..."

#======================================
# Imitate upstream image:
# velero/velero-restic-restore-helper
# same file structure
#--------------------------------------
ln -sf /usr/bin/velero-restic-restore-helper /velero-restic-restore-helper

exit 0
