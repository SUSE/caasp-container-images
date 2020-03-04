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
# velero/velero-plugin-for-microsoft-azure
# same file structure
#--------------------------------------
mkdir /plugins
ln -sf /usr/bin/velero-plugin-for-microsoft-azure /plugins/velero-plugin-for-microsoft-azure

exit 0
