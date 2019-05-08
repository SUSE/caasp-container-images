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
# k8s.gcr.io/debian-hyperkube-base-amd64
# same file structure
#--------------------------------------
cp /usr/bin/hyperkube /hyperkube
ln -sf /hyperkube /usr/local/bin/kube-apiserver 
ln -sf /hyperkube /usr/local/bin/cloud-controller-manager
ln -sf /hyperkube /usr/local/bin/kube-controller-manager
ln -sf /hyperkube /usr/local/bin/kubectl
ln -sf /hyperkube /usr/local/bin/kubelet
ln -sf /hyperkube /usr/local/bin/kube-proxy
ln -sf /hyperkube /usr/local/bin/kube-scheduler

exit 0
