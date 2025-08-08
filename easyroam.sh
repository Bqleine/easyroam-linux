#!/bin/bash

# +----------------------------------------+ #
# | Extract easyroam certificates on linux | #
# | Developed by https://github.com/jahtz  | #
# +----------------------------------------+ #

# easyroam: https://www.easyroam.de/
# DFN: https://www.dfn.de/


cat <<'EOF'
------------------------------------------------------------------------------
easyroam.sh - Easyroam Certificate Extraction Script

This script assists with the extraction of your Easyroam client certificate,
provided as a PKCS#12 (.p12) bundle license file.

Result:
  After running this script, you will have the following files extracted:
  - Client Certificate   (easyroam_client_cert.pem)
  - Private Key          (easyroam_client_pem.key)
  - Root CA Certificate  (easyroam_root_ca.pem)

Where to get your .p12 license file:
  The .p12 (PKCS#12) license/certificate file can be downloaded from
  https://www.easyroam.de

For further instructions, please refer to the README.md file found in this 
repository.
------------------------------------------------------------------------------
EOF

echo
read -n 1 -s -r -p "Press any key to continue..."
echo

# DEFAULT VALUES
OUTDIR="$( getent passwd "$USER" | cut -d: -f6 )/Documents/easyroam"
LEGACY="-legacy"

# DEPENDENCY CHECK
check_dependency() {
    echo -n "$1... "
    if ! type "$1" &> /dev/null; then
        echo "Not found!"
        exit 1
    fi
    echo "Ok"
}

echo
echo "Checking dependencies:"
check_dependency "openssl"

# PROMTS
echo
echo -e "Select PKCS12 (.p12) bundle file:"
read -e p12file
if [[ -z "$p12file" || ! -f "$p12file" || "${p12file##*.}" != "p12" ]]; then
    echo "Invalid PKCS12 file path!"
    exit 1
fi

echo
echo -e "Set output directory [Default: $OUTDIR]:"
read -e outputdir_new
outputdir="${outputdir_new:-$OUTDIR}"
p12name=$(basename "$p12file")

echo
read -sp "Set password for private key: " pkpw
echo
read -sp "Confirm password: " pkpw_confirm
echo
if [[ $pkpw -ne $pkpw_confirm ]]; then
    echo "Passwords do not match!"
    exit 1 
fi

# LOGIC
echo
echo -n -e "Create output directory... "
if [[ ! -d "$outputdir" ]]; then
    mkdir -p "$outputdir" || { echo "Failed to create directory."; exit 1; }
fi
echo "Done"

echo -n "Copy PKCS12 file... "
cp "$p12file" "$outputdir" || { echo "Failed to copy PKCS12 file."; exit 1; }
echo "Done"
cd "$outputdir" || { echo "Failed to change directory."; exit 1; }

echo -n "Build client certificate... "
openssl pkcs12 -in "$p12name" "$LEGACY" -nokeys -passin pass: | openssl x509 > easyroam_client_cert.pem
if [[ $? -ne 0 ]]; then
    LEGACY=""
    openssl pkcs12 -in "$p12name" "$LEGACY" -nokeys -passin pass: | openssl x509 > easyroam_client_cert.pem
    if [[ $? -ne 0 ]]; then
        echo "Failed to build client certificate."
        exit 1
    fi
fi
echo "Done"

cn=$(openssl x509 -noout -subject -in easyroam_client_cert.pem | sed -n 's/^.*CN=\([^,]*\).*$/\1/p')

echo -n "Build private key... "
openssl pkcs12 "$LEGACY" -in "$p12name" -nodes -nocerts -passin pass: | openssl rsa -aes256 -passout pass:"$pkpw" -out easyroam_client_key.pem -legacy 2>/dev/null
if [[ $? -ne 0 ]]; then
    openssl pkcs12 "$LEGACY" -in "$p12name" -nodes -nocerts -passin pass: | openssl rsa -aes256 -passout pass:"$pkpw" -out easyroam_client_key.pem 2>/dev/null
    if [[ $? -ne 0 ]]; then
        echo "Failed to build private key."
        exit 1
    fi
fi
echo "Done"

echo -n "Build RootCA certificate... "
openssl pkcs12 -in "$p12name" "$LEGACY" -cacerts -nokeys -passin pass: > easyroam_root_ca.pem
if [[ $? -ne 0 ]]; then
    echo "Failed to build RootCA certificate."
    exit 1
fi
echo "Done"

echo -e "\nIdentity: $cn"
