#!/bin/bash

#########################################################
# ToughRADIUS RadSec client certificate generation script
#
# This script generates RadSec client certificates
# Prerequisite: run gen-radsec-certs.sh to generate the CA certificate
#
# Usage:
#   ./scripts/gen-radsec-client.sh <client-name> [options]
#
# Options:
#   -d DIR     CA certificate directory (default: ./rundata/private)
#   -o DIR     Client certificate output directory (default: ./rundata/private/clients)
#   -h HOST    Client hostname (default: use the client name)
#   -i IPS     Client IP addresses, comma-separated (optional)
#   -y DAYS    Certificate validity in days (default: 3650)
#   -g ORG     Organization name (default: ToughRADIUS)
#   -h         Display help information
#
# Examples:
#   # Generate a client certificate for a NAS device
#   ./scripts/gen-radsec-client.sh nas01
#
#   # Specify hostname and IP for the NAS
#   ./scripts/gen-radsec-client.sh nas02 -h nas02.example.com -i "192.168.1.50"
#
#   # Specify a custom output directory
#   ./scripts/gen-radsec-client.sh wifi-controller -o ./certs/clients
#
#########################################################

set -e

# Default configuration
CA_DIR="./rundata/private"
OUTPUT_DIR="./rundata/private/clients"
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
ToughRADIUS RadSec Client certificate generation script

Usage:
    $0 <Client name> [Options]

Arguments:
    Client name      client identifier (required)

Options:
    -d DIR          CA certificate directory (default: ./rundata/private)
    -o DIR          Client certificate output directory (default: ./rundata/private/clients)
    -n HOST         Client hostname (default: client name)
    -i IPS          Client IP addresses, comma separated (optional)
    -y DAYS         Certificate validity in days (default: 3650)
    -g ORG          Organization name (default: ToughRADIUS)
    -c COUNTRY      Country code (default: CN)
    -p PROVINCE     State/province (default: Shanghai)
    -l LOCALITY     City (default: Shanghai)
    -u UNIT         Organizational unit (default: IT)
    -h              Show this help

Examples:
    # Basic usage - generate a certificate for a NAS device
    $0 nas01

    # Specify hostname and IP
    $0 nas02 -n nas02.example.com -i "192.168.1.50"

    # Specify multiple IPs
    $0 wifi-controller -i "192.168.1.100,10.0.0.100"

    # Customize all parameters
    $0 branch-radius -d ./certs -o ./certs/clients -n branch.example.com -y 365

Prerequisites:
    Run gen-radsec-certs.sh first to create the CA certificate
    CA directory must contain: ca.crt and ca.key

Generated files:
    <Client name>.crt    - Client certificate (public key)
    <Client name>.key    - Client private key

EOF
}

# Parse command-line arguments
CLIENT_NAME=""
CLIENT_HOST=""
CLIENT_IPS=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -d)
            CA_DIR="$2"
            shift 2
        ;;
        -o)
            OUTPUT_DIR="$2"
            shift 2
        ;;
        -n)
            CLIENT_HOST="$2"
            shift 2
        ;;
        -i)
            CLIENT_IPS="$2"
            shift 2
        ;;
        -y)
            VALID_DAYS="$2"
            shift 2
        ;;
        -g)
            ORGANIZATION="$2"
            shift 2
        ;;
        -c)
            COUNTRY="$2"
            shift 2
        ;;
        -p)
            PROVINCE="$2"
            shift 2
        ;;
        -l)
            LOCALITY="$2"
            shift 2
        ;;
        -u)
            ORG_UNIT="$2"
            shift 2
        ;;
        -h)
            show_help
            exit 0
        ;;
        -*)
            echo -e "${RED} Error: invalid option $1${NC}" >&2
            show_help
            exit 1
        ;;
        *)
            if [ -z "$CLIENT_NAME" ]; then
                CLIENT_NAME="$1"
            else
                echo -e "${RED} Error: unexpected argument '$1'${NC}" >&2
                show_help
                exit 1
            fi
            shift
        ;;
    esac
done

# Validate the client name
if [ -z "$CLIENT_NAME" ]; then
    echo -e "${RED} Error: client name is required ${NC}" >&2
    echo ""
    show_help
    exit 1
fi

# Use the client name when no hostname is provided
if [ -z "$CLIENT_HOST" ]; then
    CLIENT_HOST="$CLIENT_NAME"
fi

# Verify that the CA certificate exists
if [ ! -f "$CA_DIR/ca.crt" ] || [ ! -f "$CA_DIR/ca.key" ]; then
    echo -e "${RED} Error: CA certificate not found ${NC}"
    echo "Run gen-radsec-certs.sh first to create the CA certificate"
    echo ""
    echo "CA certificate path:"
    echo "  $CA_DIR/ca.crt"
    echo "  $CA_DIR/ca.key"
    exit 1
fi

# Print configuration information
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  ToughRADIUS RadSec Client certificate generation ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN} Configuration:${NC}"
echo -e "  Client name:   ${YELLOW}$CLIENT_NAME${NC}"
echo -e "  Client hostname: ${YELLOW}$CLIENT_HOST${NC}"
if [ -n "$CLIENT_IPS" ]; then
    echo -e "  Client IP:    ${YELLOW}$CLIENT_IPS${NC}"
else
    echo -e "  Client IP:    ${YELLOW}(not specified)${NC}"
fi
echo -e "  CA directory:      ${YELLOW}$CA_DIR${NC}"
echo -e "  Output directory:     ${YELLOW}$OUTPUT_DIR${NC}"
echo -e "  Validity:       ${YELLOW}$VALID_DAYS days ${NC}"
echo -e "  Organization:     ${YELLOW}$ORGANIZATION${NC}"
echo ""

# Create the output directory
mkdir -p "$OUTPUT_DIR"

# Check whether the certgen tool exists
if ! command -v go &> /dev/null; then
    echo -e "${RED} Error: Go toolchain not found ${NC}"
    echo "Please install Go: https://golang.org/dl/"
    exit 1
fi

# Build the certgen tool if necessary
CERTGEN_BIN="./certgen"
if [ ! -f "$CERTGEN_BIN" ]; then
    echo -e "${YELLOW} Building certgen tool...${NC}"
    go build -o "$CERTGEN_BIN" ./cmd/certgen
    echo -e "${GREEN}✓ certgen tool built ${NC}"
    echo ""
fi

# Prepare a list of DNS names
DNS_NAMES="${CLIENT_HOST},localhost"

# If the output directory differs from the CA directory, copy CA certificates there first
# Because certgen reads CA certificates from the output directory
if [ "$OUTPUT_DIR" != "$CA_DIR" ]; then
    echo -e "${YELLOW} Copy CA certificate to output directory...${NC}"
    cp "$CA_DIR/ca.crt" "$OUTPUT_DIR/"
    cp "$CA_DIR/ca.key" "$OUTPUT_DIR/"
fi

# Build the certgen command
CERTGEN_ARGS=(
    -type client
    -output "$OUTPUT_DIR"
    -days "$VALID_DAYS"
    -org "$ORGANIZATION"
    -ou "$ORG_UNIT"
    -country "$COUNTRY"
    -province "$PROVINCE"
    -locality "$LOCALITY"
    -client-cn "$CLIENT_HOST"
    -client-dns "$DNS_NAMES"
)

# Add specified IP addresses to the command
if [ -n "$CLIENT_IPS" ]; then
    CERTGEN_ARGS+=(-client-ips "$CLIENT_IPS")
fi

# Generate the client certificate
echo -e "${YELLOW} Generating client certificate...${NC}"
echo ""

"$CERTGEN_BIN" "${CERTGEN_ARGS[@]}"

# Remove previously copied CA certificates to keep the output clean
if [ "$OUTPUT_DIR" != "$CA_DIR" ]; then
    rm -f "$OUTPUT_DIR/ca.crt" "$OUTPUT_DIR/ca.key"
fi

# Rename the client certificate files
if [ -f "$OUTPUT_DIR/client.crt" ]; then
    mv "$OUTPUT_DIR/client.crt" "$OUTPUT_DIR/${CLIENT_NAME}.crt"
    echo -e "${GREEN}✓ Client certificate renamed to ${CLIENT_NAME}.crt${NC}"
fi

if [ -f "$OUTPUT_DIR/client.key" ]; then
    mv "$OUTPUT_DIR/client.key" "$OUTPUT_DIR/${CLIENT_NAME}.key"
    echo -e "${GREEN}✓ Client private key renamed to ${CLIENT_NAME}.key${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ RadSec Client certificate generated!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN} Generated files:${NC}"
echo -e "  Client certificate: ${YELLOW}$OUTPUT_DIR/${CLIENT_NAME}.crt${NC}"
echo -e "  Client private key: ${YELLOW}$OUTPUT_DIR/${CLIENT_NAME}.key${NC}"
echo ""
echo -e "${YELLOW} Notes:${NC}"
echo -e "  1. Keep the client private key file safe"
echo -e "  2. Deploy the certificate and private key to the client device"
echo -e "  3. The client also needs the CA certificate for verification:"
echo -e "     ${BLUE}$CA_DIR/ca.crt${NC}"
echo ""
echo -e "${GREEN} Certificate valid until: $(date -v+${VALID_DAYS}d '+%Y-%m-%d' 2>/dev/null || date -d "+${VALID_DAYS} days" '+%Y-%m-%d' 2>/dev/null || echo 'unable to compute')${NC}"
echo ""
echo -e "${YELLOW} Client configuration example (FreeRADIUS):${NC}"
echo -e "  ${BLUE}home_server radsec {${NC}"
echo -e "    ${BLUE}type = auth+acct${NC}"
echo -e "    ${BLUE}ipaddr = <Server IP>${NC}"
echo -e "    ${BLUE}port = 2083${NC}"
echo -e "    ${BLUE}proto = tcp${NC}"
echo -e "    ${BLUE}secret = radsec${NC}"
echo -e "    ${BLUE}status_check = status-server${NC}"
echo -e "  ${BLUE}}${NC}"
echo ""
echo -e "  ${BLUE}tls {${NC}"
echo -e "    ${BLUE}ca_file = $CA_DIR/ca.crt${NC}"
echo -e "    ${BLUE}certificate_file = $OUTPUT_DIR/${CLIENT_NAME}.crt${NC}"
echo -e "    ${BLUE}private_key_file = $OUTPUT_DIR/${CLIENT_NAME}.key${NC}"
echo -e "  ${BLUE}}${NC}"
echo ""
