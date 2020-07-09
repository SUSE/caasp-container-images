#!/usr/bin/env bash
ROOT_DN="cn=Directory Manager"
DS_DM_PASSWORD=${DS_DM_PASSWORD:-"$(echo @dmin\!2345 | base64)"} # Environment Variable
DS_SUFFIX=${DS_SUFFIX:-"dc=example,dc=org"}                      # Environment Variable
DOMAIN_SUFFIX=$(echo ${DS_SUFFIX} | tr '[:upper:]' '[:lower:]' | sed 's/ou=//g' | sed 's/dc=//g' | sed 's/\,/\./g')

SELF_SIGNED_CA=Self-Signed-CA
ROOT_CA=ca
SERVER_CERT=Server-Cert
SSCA_DIR=/etc/dirsrv/ssca
SLAP_DIR=/etc/dirsrv/slapd-localhost

DB_DIR=/var/lib/dirsrv/slapd-localhost/db
LOG_DIR=/var/log/dirsrv/slapd-localhost
RUN_LOCK_DIR=/run/lock/dirsrv/slapd-localhost
VAR_LOCK_DIR=/var/lock/dirsrv/slapd-localhost

echo -e "\n>> Creating persistent folders\n"
mkdir -p /data/{config,ssca,db,bak,ldif,run/lock,logs}
mkdir -p /var/run/dirsrv
mkdir -p ${DB_DIR}
mkdir -p ${LOG_DIR}
mkdir -p ${RUN_LOCK_DIR}
mkdir -p ${VAR_LOCK_DIR}

if [ ! -e "/data/config/setup.inf" ]; then

    echo -e "\n>> Creating localhost configuration...\n"
    cat <<EOT >> /data/config/setup.inf
[general]
config_version = 2
;defaults = 999999999
;full_machine_name = localhost.${DOMAIN_SUFFIX}
selinux = False
start = False
strict_host_checking = False
systemd = False
start_server = False
with_systemd = False

[slapd]
backup_dir = /data/bak
;bin_dir = /usr/bin
;cert_dir = /etc/dirsrv/slapd-localhost
;config_dir = /etc/dirsrv/slapd-localhost
;data_dir = /usr/share
db_dir = /data/db
;db_home_dir = /data/db
;group = dirsrv
;initconfig_dir = /etc/sysconfig
inst_dir = /data
instance_name = localhost
ldif_dir = /data/ldif
;lib_dir = /usr/lib64
local_state_dir = /data
lock_dir = /data/run/lock
log_dir = /data/logs
port = 3389
;prefix = /usr
root_dn = ${ROOT_DN}
root_password = ${DS_DM_PASSWORD}
run_dir = /data/run
;sbin_dir = /usr/sbin
;schema_dir = /etc/dirsrv/slapd-localhost/schema
secure_port = 3636
;self_sign_cert = True
;self_sign_cert_valid_months = 24
;sysconf_dir = /etc
;tmp_dir = /tmp
;Should not run as root
user = root
;Should not run as root
group = root
ldapi = /data/run/slapd.socket
access_log = /data/logs/access
error_log = /data/logs/error
audit_log = /data/logs/audit

[backend-userroot]
;create_suffix_entry = True
;require_index = False
;sample_entries = No
;sample_entries = Yes
suffix = ${DS_SUFFIX}
EOT

    echo -e "\n>> Linking Python3 to Python...\n"
    ln -s /usr/bin/python3 /usr/bin/python

    echo -e "\n>> Creating Directory from configuration...\n"
    sed -i "s/with_systemd.*/with_systemd = 0/" /usr/share/dirsrv/inf/defaults.inf
    /usr/sbin/dscreate -v from-file /data/config/setup.inf

    sed -i "s#/var/lock/dirsrv/slapd-localhost#/data/run/lock#g" ${SLAP_DIR}/dse.ldif
    sed -i "s#/var/lib/dirsrv/slapd-localhost#/data#g" ${SLAP_DIR}/dse.ldif
    sed -i "s#/var/run/dirsrv#/data/run#g" ${SLAP_DIR}/dse.ldif
    sed -i "s#/usr/lib64/dirsrv/slapd-localhost#/data#g" ${SLAP_DIR}/dse.ldif
    sed -i "s#/var/log/dirsrv/slapd-localhost#/data/logs#g" ${SLAP_DIR}/dse.ldif
    sed -i "s#/var/run/slapd-localhost.socket#/data/run/slapd-localhost.socket#g" ${SLAP_DIR}/dse.ldif

    mv ${SLAP_DIR}/* /data/config && rm -rf ${SLAP_DIR} || true
    mv ${SSCA_DIR}/* /data/ssca && rm -rf ${SSCA_DIR} || true
    mv ${DB_DIR}/* /data/db && rm -rf ${DB_DIR} || true
    mv ${LOG_DIR}/* /data/logs && rm -rf ${LOG_DIR} || true

    echo -e "\n>> Creating config folders symbolic links to /data\n"
    ln -s /data/config ${SLAP_DIR} && \
    ln -s /data/ssca ${SSCA_DIR}

    sed -i "/^nsslapd-defaultnamingcontext: .*$/a nsslapd-security: on" ${SLAP_DIR}/dse.ldif

cat <<EOF >> ${SLAP_DIR}/dse.ldif
dn: cn=encryption,cn=config
objectClass: top
objectClass: nsEncryptionConfig
cn: encryption
nsSSLSessionTimeout: 0
nsSSLClientAuth: off
nsSSL3: off
nsSSL2: off

dn: cn=RSA,cn=encryption,cn=config
objectClass: top
objectClass: nsEncryptionModule
nsSSLPersonalitySSL: ${SERVER_CERT}
nsSSLActivation: on
nsSSLToken: internal (software)
cn: RSA

EOF

    /usr/bin/sha1sum ${SSCA_DIR}/${ROOT_CA}.crt ${SLAP_DIR}/${SERVER_CERT}.csr ${SLAP_DIR}/${SERVER_CERT}.crt > /tmp/certsum_new
    /bin/cp /tmp/certsum_new /data/.certsum
else
    echo -e "\n>> Linking Python3 to Python...\n"
    if [ ! -e "/usr/bin/python" ]; then
        ln -s /usr/bin/python3 /usr/bin/python
    fi

    echo -e "\n>> Creating symbolic links of config folders to data folder\n"
    rm -rf ${DB_DIR} || true
    rm -rf ${LOG_DIR} || true

    if [ ! -e "${SLAP_DIR}" ]; then
        ln -s /data/config ${SLAP_DIR}
    fi

    if [ ! -e "${SSCA_DIR}" ]; then
        ln -s /data/ssca ${SSCA_DIR}
    fi

    if [ ! -e "${DB_DIR}" ]; then
        ln -s /data/db ${DB_DIR}
    fi

    if [ ! -e "${LOG_DIR}" ]; then
        ln -s /data/logs ${LOG_DIR}
    fi

    /usr/bin/sha1sum ${SSCA_DIR}/${ROOT_CA}.crt ${SLAP_DIR}/${SERVER_CERT}.csr ${SLAP_DIR}/${SERVER_CERT}.crt > /tmp/certsum_new
    if cmp -s /data/.certsum /tmp/certsum_new; then
        echo "Certificate Database is Up-to-date."
    else

        echo -e "\n>> Creating ${SERVER_CERT} hash link in ${SLAP_DIR}...\n"
        /usr/bin/c_rehash ${SLAP_DIR}

        echo -e "\n>> Deleting ${SERVER_CERT} database in ${SLAP_DIR}...\n"
        # /usr/bin/certuti -d ${SLAP_DIR} -D -n "${SERVER_CERT}" # Remove certificate
        # /usr/bin/certuti -d ${SLAP_DIR} -F -n "${SERVER_CERT}" # Remove key
        echo > ${SLAP_DIR}/pwdfile.txt
        rm -f ${SLAP_DIR}/*.db
        /usr/bin/certutil -N --empty-password -d ${SLAP_DIR}

        echo -e "\n>> Importing the ${ROOT_CA} to ${SERVER_CERT} database in ${SLAP_DIR}...\n"
        /usr/bin/certutil -A -n ${SELF_SIGNED_CA} -t "CT,," -a -i ${SSCA_DIR}/${ROOT_CA}.crt -d ${SLAP_DIR} -f ${SLAP_DIR}/pwdfile.txt

        echo -e "\n>> Importing the certificate to ${SERVER_CERT} database in ${SLAP_DIR}...\n"
        if [ -e "${SLAP_DIR}/pwdfile-import.txt" ]; then
            /usr/bin/openssl pkcs12 -export -inkey ${SLAP_DIR}/${SERVER_CERT}-Key.pem -in ${SLAP_DIR}/${SERVER_CERT}.crt -out ${SLAP_DIR}/${SERVER_CERT}.p12 -nodes -name "${SERVER_CERT}" -passin file:${SLAP_DIR}/pwdfile-import.txt -passout file:${SLAP_DIR}/pwdfile.txt
            /usr/bin/pk12util -i ${SLAP_DIR}/${SERVER_CERT}.p12 -d ${SLAP_DIR} -w ${SLAP_DIR}/pwdfile.txt
        else
            /usr/bin/openssl pkcs12 -export -inkey ${SLAP_DIR}/${SERVER_CERT}-Key.pem -in ${SLAP_DIR}/${SERVER_CERT}.crt -out ${SLAP_DIR}/${SERVER_CERT}.p12 -nodes -name "${SERVER_CERT}" -passout file:${SLAP_DIR}/pwdfile.txt
            /usr/bin/pk12util -i ${SLAP_DIR}/${SERVER_CERT}.p12 -d ${SLAP_DIR}
        fi
        /bin/rm -f ${SLAP_DIR}/${SERVER_CERT}.p12

        echo "Certificate Database is now Up-to-date."
        /bin/cp /tmp/certsum_new /data/.certsum
    fi

fi

# remove stray lockfiles
rm -f ${VAR_LOCK_DIR}/server/*
rm -f /data/run/lock/server/*

echo -e "\n>> Starting 389 Directory Server...\n"
exec /usr/sbin/ns-slapd -D ${SLAP_DIR} -d 266354688
