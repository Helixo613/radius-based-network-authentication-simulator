#!/bin/bash

#########################################################
# ToughRADIUS RadSec server certificate generation script
#
# This script generates certificates required for the RadSec (RADIUS over TLS) server
# Includes the CA certificate, server certificate, and key
#
# Usage:
#   ./scripts/gen-radsec-certs.sh [options]
#
# Options:
#   -d DIR     Output directory (default: ./rundata/private)
#   -h HOST    Server hostname (default: radius.example.com)
#   -i IPS     Server IP addresses, comma-separated (default: 127.0.0.1)
#   -y DAYS    Certificate validity in days (default: 3650)
#   -o ORG     Organization name (default: ToughRADIUS)
#   -h         Display help information
#
# Examples:
#   # Generate certificates using the default configuration
#   ./scripts/gen-radsec-certs.sh
#
#   # Specify hostname and IP
#   ./scripts/gen-radsec-certs.sh -h radius.mycompany.com -i "192.168.1.100,10.0.0.1"
#
#   # Customize all parameters
#   ./scripts/gen-radsec-certs.sh -d ./certs -h radius.local -i 127.0.0.1 -y 1825 -o "My Company"
#
#########################################################

set -e

# Default configuration
OUTPUT_DIR="./rundata/private"
SERVER_HOST="radius.example.com"
SERVER_IPS="127.0.0.1"
VALID_DAYS=3650
ORGANIZATION="ToughRADIUS"
COUNTRY="CN"
PROVINCE="Shanghai"
LOCALITY="Shanghai"
ORG_UNIT="IT"

# Colorized output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Display help information
show_help() {
    cat << EOF
ToughRADIUS RadSec Server certificate generation script

Usage:
    $0 [Options]

Options:
    -d DIR      Output directory (default: ./rundata/private)
    -n HOST     Server hostname (default: radius.example.com)
    -i IPS      Server IP addresses, comma separated (default: 127.0.0.1)
    -y DAYS     Certificate validity in days (default: 3650)
    -o ORG      Organization name (default: ToughRADIUS)
    -c COUNTRY  Country code (default: CN)
    -p PROVINCE State/province (default: Shanghai)
    -l LOCALITY City (default: Shanghai)
    -u UNIT     Organizational unit (default: IT)
    -h          Show this help

Examples:
    # Use the default configuration
    $0

    # Specify hostname and IP
    $0 -n radius.mycompany.com -i "192.168.1.100,10.0.0.1"

    # Full configuration
    $0 -d ./certs -n radius.local -i 127.0.0.1 -y 1825 -o "My Company"

Generated files:
    ca.crt              - CA root certificate (public key)
    ca.key              - CA private key
    radsec.tls.crt      - RadSec Server certificate (public key)
    radsec.tls.key      - RadSec Server private key

EOF
}

# Parse command-line arguments
while getopts "d:n:i:y:o:c:p:l:u:h" opt; do
    case $opt in
        d) OUTPUT_DIR="$OPTARG" ;;
        n) SERVER_HOST="$OPTARG" ;;
        i) SERVER_IPS="$OPTARG" ;;
        y) VALID_DAYS="$OPTARG" ;;
        o) ORGANIZATION="$OPTARG" ;;
        c) COUNTRY="$OPTARG" ;;
        p) PROVINCE="$OPTARG" ;;
        l) LOCALITY="$OPTARG" ;;
        u) ORG_UNIT="$OPTARG" ;;
        h)
            show_help
            exit 0
        ;;
        \?)
            echo -e "${RED} Error: invalid option -$OPTARG${NC}" >&2
            show_help
            exit 1
        ;;
    esac
done

# Print configuration information
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  ToughRADIUS RadSec certificate generation ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN} Configuration:${NC}"
echo -e "  Output directory:     ${YELLOW}$OUTPUT_DIR${NC}"
echo -e "  Server hostname: ${YELLOW}$SERVER_HOST${NC}"
echo -e "  Server IP:    ${YELLOW}$SERVER_IPS${NC}"
echo -e "  Validity:       ${YELLOW}$VALID_DAYS days ${NC}"
echo -e "  Organization:     ${YELLOW}$ORGANIZATION${NC}"
echo -e "  Country:         ${YELLOW}$COUNTRY${NC}"
echo -e "  State/province:         ${YELLOW}$PROVINCE${NC}"
echo -e "  City:         ${YELLOW}$LOCALITY${NC}"
echo -e "  Organizational unit:     ${YELLOW}$ORG_UNIT${NC}"
echo ""

# Create the output directory
mkdir -p "$OUTPUT_DIR"

# Check whether the certgen tool exists
if ! command -v go &> /dev/null; then
    echo -e "${RED} Error: Go toolchain not found ${NC}"
    echo "Please install Go: https://golang.org/dl/"
    exit 1
fi

# Build the certgen tool if needed
CERTGEN_BIN="./certgen"
if [ ! -f "$CERTGEN_BIN" ]; then
    echo -e "${YELLOW} Building certgen tool...${NC}"
    go build -o "$CERTGEN_BIN" ./cmd/certgen
    echo -e "${GREEN}✓ certgen tool built ${NC}"
    echo ""
fi

# Prepare the DNS name list (including hostnames and wildcards)
DNS_NAMES="${SERVER_HOST},*.${SERVER_HOST},localhost"

# Generate certificates
echo -e "${YELLOW} Generating certificates...${NC}"
echo ""

"$CERTGEN_BIN" \
-type all \
-output "$OUTPUT_DIR" \
-days "$VALID_DAYS" \
-org "$ORGANIZATION" \
-ou "$ORG_UNIT" \
-country "$COUNTRY" \
-province "$PROVINCE" \
-locality "$LOCALITY" \
-ca-cn "$ORGANIZATION RadSec CA" \
-server-cn "$SERVER_HOST" \
-server-dns "$DNS_NAMES" \
-server-ips "$SERVER_IPS" \
-client-cn "radius-client"

# Rename the server certificate files to RadSec-standard names
if [ -f "$OUTPUT_DIR/server.crt" ]; then
    mv "$OUTPUT_DIR/server.crt" "$OUTPUT_DIR/radsec.tls.crt"
    echo -e "${GREEN}✓ Server certificate renamed to radsec.tls.crt${NC}"
fi

if [ -f "$OUTPUT_DIR/server.key" ]; then
    mv "$OUTPUT_DIR/server.key" "$OUTPUT_DIR/radsec.tls.key"
    echo -e "${GREEN}✓ Server private key renamed to radsec.tls.key${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ RadSec Server certificates generated!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN} Generated files:${NC}"
echo -e "  CA certificate:          ${YELLOW}$OUTPUT_DIR/ca.crt${NC}"
echo -e "  CA private key:          ${YELLOW}$OUTPUT_DIR/ca.key${NC}"
echo -e "  Server certificate:       ${YELLOW}$OUTPUT_DIR/radsec.tls.crt${NC}"
echo -e "  Server private key:       ${YELLOW}$OUTPUT_DIR/radsec.tls.key${NC}"
echo -e "  Client certificate:       ${YELLOW}$OUTPUT_DIR/client.crt${NC}"
echo -e "  Client private key:       ${YELLOW}$OUTPUT_DIR/client.key${NC}"
echo ""
echo -e "${YELLOW} Notes:${NC}"
echo -e "  1. Keep the private key files (*.key) safe"
echo -e "  2. CA certificate must be distributed to all RadSec clients"
echo -e "  3. Set the certificate paths in toughradius.yml:"
echo -e "     ${BLUE}radiusd:${NC}"
echo -e "       ${BLUE}radsec_ca_cert: $OUTPUT_DIR/ca.crt${NC}"
echo -e "       ${BLUE}radsec_cert: $OUTPUT_DIR/radsec.tls.crt${NC}"
echo -e "       ${BLUE}radsec_key: $OUTPUT_DIR/radsec.tls.key${NC}"
echo ""
echo -e "${GREEN} Certificate valid until: $(date -v+${VALID_DAYS}d '+%Y-%m-%d' 2>/dev/null || date -d "+${VALID_DAYS} days" '+%Y-%m-%d' 2>/dev/null || echo 'unable to compute')${NC}"
echo ""
