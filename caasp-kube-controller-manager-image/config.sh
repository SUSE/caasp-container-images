#!/bin/bash

#======================================
# Functions...
#--------------------------------------
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

ln -sf /usr/bin/kube-controller-manager /usr/local/bin/kube-controller-manager

exit 0
