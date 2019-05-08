#!/bin/bash

set -e

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
image=$(basename "${1}")
tmp_dir=$(mktemp -d -t "${image}_XXXX")
obs_files="${script_dir}/obs_files/"

log()   { (>&2 echo ">>> $*") ; }
clean() { log "Cleaning temporary directory ${tmp_dir}"; rm -rf "${tmp_dir}"; }
abort() { (>&2 echo ">>> $*") ; clean; exit 1;}

[ $# -ne 1 ] && abort "missing image parameter"
[ ! -d "${image}" ] && abort "Image directory ${image} not found"

trap clean ERR

rm -rf "${obs_files}"
mkdir -p "${obs_files}"

cp "${image}/${image}.kiwi" "${tmp_dir}"
[ -f "${image}/config.sh"  ] && cp "${image}/config.sh" "${tmp_dir}"
[ -d "${image}/root"  ] && tar -caf "${tmp_dir}/root.tar.gz" \
    -C "${image}/root" .
[ -f "${image}/_service"  ] && cp "${image}/_service" "${tmp_dir}"
make CHANGES="${tmp_dir}/${image}.changes.append" suse-changelog

cp "${tmp_dir}"/* "${obs_files}"
log "Find files for RPM package in ${obs_files}"
clean

