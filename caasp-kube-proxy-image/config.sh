#!/bin/bash

#======================================
# Functions...
#--------------------------------------
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

ln -sf /usr/bin/kube-proxy /usr/local/bin/kube-proxy
exit 0
