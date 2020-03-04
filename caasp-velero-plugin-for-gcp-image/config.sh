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
# velero/velero-plugin-for-gcp
# same file structure
#--------------------------------------
mkdir /plugins
ln -sf /usr/bin/velero-plugin-for-gcp /plugins/velero-plugin-for-gcp

exit 0
