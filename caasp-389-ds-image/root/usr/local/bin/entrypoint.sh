#!/bin/bash
INSTANCE_NAME=${INSTANCE_NAME:-"localhost"}
ROOT_DN=${ROOT_DN:-"cn=admin,dc=example,dc=com"}
ROOT_PASSWORD=${ROOT_PASSWORD:-"admin1234"}
SUFFIX=${SUFFIX:-"dc=example,dc=com"}
SSCA_DIR=/etc/dirsrv/ssca
SLAP_DIR=/etc/dirsrv/slapd-${INSTANCE_NAME}

echo -e "\n>> Creating persistent folders\n"
mkdir -p /data/config && \
    mkdir -p /data/ssca

if [ ! -e "/data/config/container.inf" ]; then

    echo -e "\n>> Creating instnace configuation...\n"
    cat <<EOT >> /data/config/container.inf
[General] 
FullMachineName=${INSTANCE_NAME}.example.com
;SuiteSpotUserID=dirsrv 
;SuiteSpotGroup=dirsrv
SuiteSpotUserID=root
SuiteSpotGroup=root
StrictHostCheck=false

[slapd] 
ServerPort=389 
ServerIdentifier=${INSTANCE_NAME}
Suffix=${SUFFIX}
RootDN=${ROOT_DN}
RootDNPwd=${ROOT_PASSWORD}
ds_bename=exampleDB
SlapdConfigForMC=Yes 
UseExistingMC=0 
AddSampleEntries=No
start_server=0
with_systemd=0
;self_sign_cert=True

EOT

    echo -e "\n>> Link python3 to python...\n"
    ln -s /usr/bin/python3 /usr/bin/python
    
    echo -e "\n>> Creating Directory from Configuation...\n"
    /usr/sbin/setup-ds.pl --verbose -d --silent --file=/data/config/container.inf

    mv ${SLAP_DIR}/* /data/config && rm -rf ${SLAP_DIR} || true
    mv ${SSCA_DIR}/* /data/ssca && rm -rf ${SSCA_DIR} || true
	
    echo -e "\n>> Creating config folders symbolic links to /data\n"
    ln -s /data/config ${SLAP_DIR} && \
        ln -s /data/ssca ${SSCA_DIR}

    sed -i "/^nsslapd-defaultnamingcontext: .*$/a nsslapd-security: on" ${SLAP_DIR}/dse.ldif

cat <<EOF >>  ${SLAP_DIR}/dse.ldif
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
nsSSLPersonalitySSL: Server-Cert
nsSSLActivation: on
nsSSLToken: internal (software)
cn: RSA

EOF

    echo -e "\n>> Creating pwd, pin, noise in ${SSCA_DIR}...\n" 
    (ps -ef ; w ) | sha1sum | awk '{print $1}' > ${SSCA_DIR}/pwdfile.txt 
    echo 'Internal (Software) Token:'$(cat ${SSCA_DIR}/pwdfile.txt) > ${SSCA_DIR}/pin.txt
    (w ; ps -ef ; date ) | sha1sum | awk '{print $1}' > ${SSCA_DIR}/noise.txt

    echo -e "\n>> Creating pwd, pin, noise in ${SLAP_DIR}...\n" 
    (ps -ef ; w ) | sha1sum | awk '{print $1}' > ${SLAP_DIR}/pwdfile.txt
    echo 'Internal (Software) Token:'$(cat ${SLAP_DIR}/pwdfile.txt) > ${SLAP_DIR}/pin.txt
    (w ; ps -ef ; date ) | sha1sum | awk '{print $1}' > ${SLAP_DIR}/noise.txt

    echo -e "\n>> Create <server-cert> database...\n" 
    /usr/bin/certutil -N -d ${SLAP_DIR} -f ${SLAP_DIR}/pwdfile.txt

    echo -e "\n>> Create <self-signed-ca> database...\n" 
    /usr/bin/certutil -N -d ${SSCA_DIR} -f ${SSCA_DIR}/pwdfile.txt

    echo -e "\n>> Create <self-signed-ca> certificate and add to database...\n" 
    /usr/bin/certutil -S -n Self-Signed-CA -s CN=ssca.389ds.example.com,O=SUSE,L=CaaS,ST=Test,C=DE -x -g 4096 -t CT,, -v 24 --keyUsage certSigning -d ${SSCA_DIR} -z ${SSCA_DIR}/noise.txt -f ${SSCA_DIR}/pwdfile.txt 
    
    echo -e "\n>> Create RootCA file in <self-signed-ca> and <server-cert> directories...\n" 
    /usr/bin/certutil -L -n Self-Signed-CA -d ${SSCA_DIR} -a > ${SSCA_DIR}/ca.crt

    echo -e "\n>> Create <self-signed-ca> hash link...\n" 
    /usr/bin/c_rehash ${SSCA_DIR}

    echo -e "\n>> Create <server-cert> certificate request...\n" 
    /usr/bin/certutil -R --keyUsage digitalSignature,nonRepudiation,keyEncipherment,dataEncipherment --nsCertType sslClient,sslServer --extKeyUsage clientAuth,serverAuth -s CN=${INSTANCE_NAME},givenName=${INSTANCE_NAME},O=SUSE,L=CaaS,ST=Test,C=DE -8 ${INSTANCE_NAME} -g 4096 -d ${SLAP_DIR} -z ${SLAP_DIR}/noise.txt -f ${SLAP_DIR}/pwdfile.txt -a -o ${SLAP_DIR}/Server-Cert.csr  
    
    echo -e "\n>> Use ssca to create <instance> certificate...\n" 
    /usr/bin/certutil -C -d ${SSCA_DIR}/ -f ${SSCA_DIR}/pwdfile.txt -v 24 -a -i ${SLAP_DIR}/Server-Cert.csr -o ${SLAP_DIR}/Server-Cert.crt -c Self-Signed-CA
    
    echo -e "\n>> Create <instance> hash link...\n" 
    /usr/bin/c_rehash ${SLAP_DIR}

    echo -e "\n>> Add rootCA to <server-cert> database...\n" 
    /usr/bin/certutil -A -n Self-Signed-CA -t CT,, -a -i ${SSCA_DIR}/ca.crt -d ${SLAP_DIR} -f ${SLAP_DIR}/pwdfile.txt
    
    echo -e "\n>> Add certificate to <server-cert> database ...\n" 
    /usr/bin/certutil -A -n Server-Cert -t ,, -a -i ${SLAP_DIR}/Server-Cert.crt -d ${SLAP_DIR} -f ${SLAP_DIR}/pwdfile.txt

    echo -e "\n>> Check validaity to certificate in <server-cert> database...\n"
    /usr/bin/certutil -V -d /etc/dirsrv/slapd-localhost -n Server-Cert -u YCV

fi

echo -e "\n>> Starting 389 Directory Server...\n"
/usr/sbin/ns-slapd -D ${SLAP_DIR} -d 266354688