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
# velero/velero-plugin-for-aws
# same file structure
#--------------------------------------
mkdir /plugins
ln -sf /usr/bin/velero-plugin-for-aws /plugins/velero-plugin-for-aws

exit 0
