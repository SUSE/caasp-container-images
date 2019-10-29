#!/bin/bash
ROOT_DN="cn=Directory Manager"
DS_DM_PASSWORD=${DS_DM_PASSWORD:-"$(echo @dmin\!2345 | base64)"} # Environment Variable
DS_SUFFIX=${DS_SUFFIX:-"dc=example,dc=org"} # Environment Variable
DOMAIN_SUFFIX=$(echo ${DS_SUFFIX} | tr '[:upper:]' '[:lower:]' | sed 's/ou=//g' | sed 's/dc=//g' |  sed 's/\,/\./g')

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
[General]
FullMachineName=localhost.${DOMAIN_SUFFIX}
;SuiteSpotUserID=dirsrv
;SuiteSpotGroup=dirsrv
;Should not run as root
SuiteSpotUserID=root
;Should not run as root
SuiteSpotGroup=root
StrictHostCheck=false

[slapd]
ServerPort=3389
;SecurePort=3636
ServerIdentifier=localhost
Suffix=${DS_SUFFIX}
RootDN=${ROOT_DN}
RootDNPwd=${DS_DM_PASSWORD}
ds_bename=userRoot
SlapdConfigForMC=Yes
UseExistingMC=0
AddSampleEntries=No
start_server=0
with_systemd=0
;self_sign_cert=True

EOT

    echo -e "\n>> Linking Python3 to Python...\n"
    ln -s /usr/bin/python3 /usr/bin/python

    echo -e "\n>> Creating Directory from configuration...\n"
    /usr/sbin/setup-ds.pl -d --silent --file=/data/config/setup.inf

    sed -i "s#/var/lock/dirsrv/slapd-localhost#/data/run/lock#g" ${SLAP_DIR}/dse.ldif
    sed -i "s#/var/lib/dirsrv/slapd-localhost#/data#g" ${SLAP_DIR}/dse.ldif
    sed -i "s#/var/run/dirsrv#/data/run#g" ${SLAP_DIR}/dse.ldif
    sed -i "s#/usr/lib64/dirsrv/slapd-localhost#/data#g" ${SLAP_DIR}/dse.ldif
    sed -i "s#/var/log/dirsrv/slapd-localhost#/data/logs#g" ${SLAP_DIR}/dse.ldif
    sed -i "s#/var/run/slapd-localhost.socket#/data/run/slapd-localhost.socket#g" ${SLAP_DIR}/dse.ldif

    mv ${SLAP_DIR}/* /data/config && rm -rf ${SLAP_DIR} || true
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

    echo -e "\n>> Creating pwd, pin, noise in ${SSCA_DIR}...\n"
    (ps -ef ; w ) | sha1sum | awk '{print $1}' > ${SSCA_DIR}/pwdfile.txt
    echo 'Internal (Software) Token:'$(cat ${SSCA_DIR}/pwdfile.txt) > ${SSCA_DIR}/pin.txt
    (w ; ps -ef ; date ) | sha1sum | awk '{print $1}' > ${SSCA_DIR}/noise.txt

    echo -e "\n>> Creating ${SELF_SIGNED_CA} database in ${SSCA_DIR}...\n"
    /usr/bin/certutil -N -d ${SSCA_DIR} -f ${SSCA_DIR}/pwdfile.txt

    echo -e "\n>> Creating ${SELF_SIGNED_CA} certificate and add to ${SELF_SIGNED_CA} database in ${SSCA_DIR}...\n"
    /usr/bin/certutil -S -n ${SELF_SIGNED_CA} -s CN=ssca.389ds.${DOMAIN_SUFFIX},O=SUSE,L=CaaS,ST=Test,C=DE -x -g 4096 -t CT,, -v 24 --keyUsage certSigning -d ${SSCA_DIR} -z ${SSCA_DIR}/noise.txt -f ${SSCA_DIR}/pwdfile.txt

    echo -e "\n>> Creating RootCA in ${SSCA_DIR}...\n"
    /usr/bin/certutil -L -n ${SELF_SIGNED_CA} -d ${SSCA_DIR} -a -o ${SSCA_DIR}/${ROOT_CA}.crt

    echo -e "\n>> Creating ${SELF_SIGNED_CA} hash link in ${SSCA_DIR}...\n"
    /usr/bin/c_rehash ${SSCA_DIR}


    echo -e "\n>> Creating pwd, pin, noise in ${SLAP_DIR}...\n"
    (ps -ef ; w ) | sha1sum | awk '{print $1}' > ${SLAP_DIR}/pwdfile.txt
    echo 'Internal (Software) Token:'$(cat ${SLAP_DIR}/pwdfile.txt) > ${SLAP_DIR}/pin.txt
    (w ; ps -ef ; date ) | sha1sum | awk '{print $1}' > ${SLAP_DIR}/noise.txt

    echo -e "\n>> Creating ${SERVER_CERT} database in ${SLAP_DIR}...\n"
    /usr/bin/certutil -N -d ${SLAP_DIR} -f ${SLAP_DIR}/pwdfile.txt

    echo -e "\n>> Creating ${SERVER_CERT} certificate request in ${SLAP_DIR}...\n"
    /usr/bin/certutil -R --keyUsage digitalSignature,nonRepudiation,keyEncipherment,dataEncipherment --nsCertType sslClient,sslServer --extKeyUsage clientAuth,serverAuth -s CN=localhost,givenName=localhost,O=SUSE,L=CaaS,ST=Test,C=DE -8 localhost -g 4096 -d ${SLAP_DIR} -z ${SLAP_DIR}/noise.txt -f ${SLAP_DIR}/pwdfile.txt -a -o ${SLAP_DIR}/${SERVER_CERT}.csr

    echo -e "\n>> Using ${SELF_SIGNED_CA} from ${SSCA_DIR} to create ${SERVER_CERT} certificate in ${SLAP_DIR}...\n"
    /usr/bin/certutil -C -d ${SSCA_DIR}/ -f ${SSCA_DIR}/pwdfile.txt -v 24 -a -i ${SLAP_DIR}/${SERVER_CERT}.csr -o ${SLAP_DIR}/${SERVER_CERT}.crt -c ${SELF_SIGNED_CA}

    echo -e "\n>> Creating ${SERVER_CERT} hash link in ${SLAP_DIR}...\n"
    /usr/bin/c_rehash ${SLAP_DIR}


    echo -e "\n>> Adding ${ROOT_CA} to ${SERVER_CERT} database in ${SLAP_DIR}...\n"
    /usr/bin/certutil -A -n ${SELF_SIGNED_CA} -t CT,, -a -i ${SSCA_DIR}/${ROOT_CA}.crt -d ${SLAP_DIR} -f ${SLAP_DIR}/pwdfile.txt

    echo -e "\n>> Adding certificate to ${SERVER_CERT} database in ${SLAP_DIR}...\n"
    /usr/bin/certutil -A -n ${SERVER_CERT} -t ,, -a -i ${SLAP_DIR}/${SERVER_CERT}.crt -d ${SLAP_DIR} -f ${SLAP_DIR}/pwdfile.txt

    echo -e "\n>> Validating certificate in ${SERVER_CERT} database in ${SLAP_DIR}...\n"
    /usr/bin/certutil -V -d ${SLAP_DIR} -n ${SERVER_CERT} -u YCV

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
