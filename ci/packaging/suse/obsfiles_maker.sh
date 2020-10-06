#!/bin/bash

set -e

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
image=$(basename "${1}")
obs_files="${script_dir}/obs_files/"

log()   { (>&2 echo ">>> $*") ; }
abort() { (>&2 echo ">>> $*") ; exit 1;}

[ $# -ne 1 ] && abort "missing image parameter"
[ ! -d "${image}" ] && abort "Image directory ${image} not found"

trap clean ERR

rm -rf "${obs_files}"
mkdir -p "${obs_files}"

install -p -m 644 "${image}/${image}.kiwi" "${obs_files}"
[ -f "${image}/config.sh"  ] && install -m 755 -p "${image}/config.sh" "${obs_files}"
[ -f "${image}/_service"  ] && install -m 644 -p "${image}/_service" "${obs_files}"
[ -f "${image}/_constraints"  ] && install -m 644 -p "${image}/_constraints" "${obs_files}"

[ -d "${image}/root"  ] && \
    tar --mtime=@1480000000 --owner=0 --group=0 --no-acls --no-xattrs \
    --no-selinux --sort=name --numeric-owner \
    --pax-option=exthdr.name=%d/PaxHeaders/%f,atime:=0,ctime:=0  \
    --mode=a+X,u+r,ug-s,o-t -caf "${obs_files}/root.tar.gz" -C "${image}/root" .


make CHANGES="${obs_files}/${image}.changes.append" suse-changelog

log "Find files for RPM package in ${obs_files}"
