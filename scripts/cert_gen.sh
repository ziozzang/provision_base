#!/bin/bash

BIN_PATH=${BIN_PATH:-"/opt/bin/"}
CERT_PATH=${CERT_PATH:-"/opt/certs/"}
INT_CA=${INT_CA:-"int_ca"}
DOMAIN_NAME=${DOMAIN_NAME:-"foo.com"}

###############################################################################
# Generate Root CA
#- "key": {"algo": "ecdsa","size": 256 }
#- "key": {"algo": "rsa","size": 2048 }
#- "262800h" = 30 yr
mkdir -p ${CERT_PATH}/root/ ${CERT_PATH}/intermediate/ ${CERT_PATH}/domain/

cat > ${CERT_PATH}/root/root_ca.cfg <<EOF
{
    "CN": "Internal Infra Root CA",
    "key": {
        "algo": "rsa",
        "size": 4096
    },
    "names": [
        {
            "C":  "KR",
            "ST": "Seoul",
            "L":  "Seoul",
            "O":  "Private",
            "OU": "Internal"
        }
    ],
    "ca": {
    	"expiry": "262800h"
 		}
}
EOF

cd ${CERT_PATH}/root/
${BIN_PATH}/cfssl genkey -loglevel=0 -initca ${CERT_PATH}/root/root_ca.cfg | ${BIN_PATH}/cfssljson -bare root_ca

###############################################################################
# Intermediate CA
mkdir -p ${CERT_PATH}/intermediate/

cat > ${CERT_PATH}/intermediate/${INT_CA}.cfg <<EOF
{
    "CN": "Internal Infra IntermediateCA",
    "key": {
        "algo": "rsa",
        "size": 4096
    },
    "names": [
        {
            "C":  "KR",
            "ST": "Seoul",
            "L":  "Seoul",
            "O":  "Private",
            "OU": "Internal"
        }
    ],
    "ca": {
    	"expiry": "87600h"
 		}
}
EOF

cd ${CERT_PATH}/intermediate/
${BIN_PATH}/cfssl gencert -initca ${CERT_PATH}/intermediate/${INT_CA}.cfg | ${BIN_PATH}/cfssljson -bare ${INT_CA}

# 인터미디엇 CA를 루트 CA로 서명 처리
cat > ${CERT_PATH}/intermediate/root_sign-${INT_CA}.cfg <<EOF
{
   "signing": {
       "default": {
           "usages": ["digital signature","cert sign","crl sign","signing"],
           "expiry": "262800h",
           "ca_constraint": {
               "is_ca": true,
               "max_path_len":0,
               "max_path_len_zero": true
           }
       }
   }
}
EOF
${BIN_PATH}/cfssl sign \
  -ca ${CERT_PATH}/root/root_ca.pem \
  -ca-key ${CERT_PATH}/root/root_ca-key.pem \
  -config ${CERT_PATH}/intermediate/root_sign-${INT_CA}.cfg \
  ${CERT_PATH}/intermediate/${INT_CA}.csr | ${BIN_PATH}/cfssljson -bare ${INT_CA}
  
  
###############################################################################
# Sign Domains


# --------------
# 도메인 인증서 생성
cd ${CERT_PATH}/domain/
cat > ${CERT_PATH}/domain/host_${DOMAIN_NAME}.cfg <<EOF
{
   "CN": "${DOMAIN_NAME}",
   "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C":  "KR",
            "ST": "Seoul",
            "L":  "Seoul",
            "O":  "Private",
            "OU": "Internal"
        }
    ],
    "Hosts": [
      "*.${DOMAIN_NAME}"
    ],
     "default": {
       "expiry": "8760h"
     }
 }
 
EOF
 
 # 도메인 인증서를 인터미디엇으로 싸이닝
 cat > ${CERT_PATH}/domain/sign_${DOMAIN_NAME}.cfg << EOF
 {
   "signing": {
     "profiles": {
       "CA": {
         "usages": ["cert sign"],
         "expiry": "8760h"
       }
     },
     "default": {
       "usages": ["digital signature"],
       "expiry": "8760h"
     }
   }
}
EOF

${BIN_PATH}/cfssl  gencert -loglevel=0 \
  -ca ${CERT_PATH}/intermediate/${INT_CA}.pem \
  -ca-key ${CERT_PATH}/intermediate/${INT_CA}-key.pem \
  -config ${CERT_PATH}/domain/sign_${DOMAIN_NAME}.cfg \
  ${CERT_PATH}/domain/host_${DOMAIN_NAME}.cfg | \
  ${BIN_PATH}/cfssljson -bare host_${DOMAIN_NAME}

openssl req -noout -text -in ${CERT_PATH}/domain/host_${DOMAIN_NAME}.csr

####################

# Server Certs
cat ${CERT_PATH}/domain/host_${DOMAIN_NAME}.pem ${CERT_PATH}/intermediate/${INT_CA}.pem > ${CERT_PATH}/domain/domain_${DOMAIN_NAME}.pem
# Server Keys
cat ${CERT_PATH}/domain/host_${DOMAIN_NAME}-key.pem > ${CERT_PATH}/domain/domain_${DOMAIN_NAME}.key

