#!/bin/bash

set -e

dashes="-------------------------------------------------------------------"
header="${dashes}%n%cd - %an <%ae>"
datef="%a %b %e %H:%M:%S %Z %Y"
ver_regex="([[:digit:]]+(\.[[:digit:]]+){0,2})"
img_ver_regex="<version>${ver_regex}</version>"

image=$1
changes=${2:-${image}.changes.append}

log()   { (>&2 echo ">>> $*") ; }
abort() { (>&2 echo ">>> $*") ; exit 1;}
usage() {
    cat <<USAGE
Usage: $0 IMAGE [CHANGELOG_FILE]

By default the change log file is set to <IMG>.changes.append
USAGE
}

if [ $# -ne 1 ] && [ $# -ne 2 ]; then
    usage && abort "Bad parameter number"
fi

[ ! -d "${image}" ] && abort "Image directory ${image} not found"
[ -f "${changes}" ] && rm "${changes}"

mapfile -t cmts < <( git log --no-merges -G"${img_ver_regex}" --format=%h \
    "${image}" | sort -r | head -n2 )
version=$(git show "${cmts[1]-${cmts[0]}}" -- "${image}" | grep "^+.*</version>" |\
    grep -Eo "${ver_regex}")
scope="${cmts[0]}..${cmts[1]}"

[ -z "${version}" ] && abort "No image version found"

{
    if [ -z "${cmts[1]}" ]; then
        git show --format="${header}%n%n- Initial release of version ${version}" \
            --date="format-local:${datef}" -s "${cmts[0]}"
    else
        git show --format="${header}%n%n- Update to version ${version}:" \
            --date="format-local:${datef}" -s "${cmts[1]}"
        git log -s --format="%w(77,2,10)* %h %s" --no-merges "${scope}" \
            "${image}"
	fi
	# Add empty line
	echo
} >> "${changes}"
