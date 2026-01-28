#!/bin/bash
# -----------------------------------------------------------------------------
# Build Lambda Authoriser
# -----------------------------------------------------------------------------
# Installs dependencies and prepares the Lambda package for Terraform.
# Run this before terraform plan/apply if you've modified the authoriser code.
# -----------------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${SCRIPT_DIR}/../modules/authoriser/src"
DIST_DIR="${SCRIPT_DIR}/../modules/authoriser/dist"

echo "Building Lambda authoriser..."

# Clean previous build
rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}"

# Install production dependencies
cd "${SRC_DIR}"
npm ci --omit=dev

# Terraform will handle the zip via the archive_file data source
echo "Dependencies installed. Terraform will create the deployment package."
echo "Done."
