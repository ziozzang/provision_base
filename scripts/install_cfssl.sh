#!/bin/bash
# Get Latest CFSSL version



get_latest_github_repo_release() {
  curl --silent "https://api.github.com/repos/$1/releases/latest" | # Get latest release from GitHub api
    grep '"tag_name":' |                                            # Get tag line
    sed -E 's/.*"([^"]+)".*/\1/'                                    # Pluck JSON value
}

#- Acquire Newest Version
VERSIONS="${VERSIONS:-$(get_latest_github_repo_release "cloudflare/cfssl")}"

declare -a CFSSL_PKGS=("cfssl-bundle" "cfssl-newkey" "cfssl-scan" "cfssljson" "cfssl" "mkbundle" "multirootca" )
 
# Iterate the string array using for loop
for CFSSL_PKG in ${CFSSL_PKGS[@]}; do
   wget -O "${CFSSL_PKG}" "https://github.com/cloudflare/cfssl/releases/download/v${VERSIONS}/${CFSSL_PKG}_${VERSIONS}_linux_amd64"
   chmod +x "${CFSSL_PKG}"
done

