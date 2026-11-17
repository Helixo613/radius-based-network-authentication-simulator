#!/bin/bash

set -e

echo "Building ToughRADIUS v9 Web UI..."

# Enter the web directory
cd "$(dirname "$0")"

# Install dependencies
echo "Installing dependencies..."
npm install

# Build production bundle
echo "Building production bundle..."
npm run build

echo "Build completed! Output: web/dist/"
echo ""
echo "To embed into Go binary, run:"
echo "  cd .. && go build"
