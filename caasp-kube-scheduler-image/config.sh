#!/bin/bash

#======================================
# Functions...
#--------------------------------------
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

ln -sf /usr/bin/kube-scheduler /usr/local/bin/kube-scheduler
exit 0
