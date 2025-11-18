#!/bin/sh

# Script to download Burp Suite JAR file
# This script uses environment variables for configuration
# 
# Required Environment Variables:
#   BURPSUITE_TYPE       - The type of Burp Suite (community, professional, etc.)
#   BURPSUITE_VERSION    - The version to download (e.g., 2025.11)
#   BURPSUITE_MODE       - The mode of operation: "download" or "local" (default: "download")

set -e

# Configuration
BURPSUITE_NAME="burpsuite_${BURPSUITE_TYPE}"
BURPSUITE_FILE="${HOME}/${BURPSUITE_NAME}_v${BURPSUITE_VERSION}.jar"
BURPSUITE_JAR="${HOME}/burpsuite.jar"
DOWNLOAD_URL="https://portswigger.net/burp/releases/download"

# Default mode to "download" if not specified
BURPSUITE_MODE="${BURPSUITE_MODE:-download}"

# Color codes for output (optional, for better visibility)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to validate that burpsuite.jar exists
validate_jar_exists() {
    if [ ! -f "$BURPSUITE_JAR" ]; then
        log_error "burpsuite.jar not found at $BURPSUITE_JAR"
        return 1
    fi
    return 0
}

# Display mode information
log_info "Burp Suite Mode: $BURPSUITE_MODE"

case "$BURPSUITE_MODE" in
    download)
        log_info "Starting in DOWNLOAD mode - fetching Burp Suite from portswigger.net"
        
        # Validate required environment variables
        if [ -z "$BURPSUITE_TYPE" ]; then
            log_error "BURPSUITE_TYPE environment variable not set"
            exit 1
        fi

        if [ -z "$BURPSUITE_VERSION" ]; then
            log_error "BURPSUITE_VERSION environment variable not set"
            exit 1
        fi

        # Check if downloaded file already exists
        if [ -f "$BURPSUITE_FILE" ]; then
            log_warning "Downloaded file already exists: $BURPSUITE_FILE"
            log_info "Skipping download and using existing file"
        else
            # Download the JAR file
            log_info "Downloading Burp Suite (${BURPSUITE_TYPE}, v${BURPSUITE_VERSION})..."
            log_info "Destination: $BURPSUITE_FILE"

            curl -L -o "$BURPSUITE_FILE" \
                "${DOWNLOAD_URL}?product=${BURPSUITE_TYPE}&version=${BURPSUITE_VERSION}&type=Jar" \
                --progress-bar || {
                    log_error "Failed to download Burp Suite"
                    rm -f "$BURPSUITE_FILE"
                    exit 1
                }

            log_info "Download completed successfully"
        fi

        # Rename downloaded file to burpsuite.jar for compatibility
        if [ -f "$BURPSUITE_FILE" ]; then
            log_info "Renaming $BURPSUITE_FILE to $BURPSUITE_JAR"
            mv "$BURPSUITE_FILE" "$BURPSUITE_JAR"
        fi

        log_info "Ready to use: $BURPSUITE_JAR"
        ;;

    local)
        log_info "Starting in LOCAL mode - using pre-copied burpsuite.jar"
        
        # Validate that the JAR file exists
        if ! validate_jar_exists; then
            exit 1
        fi
        
        log_info "Using local Burp Suite JAR: $BURPSUITE_JAR"
        ;;

    *)
        log_error "Invalid BURPSUITE_MODE: $BURPSUITE_MODE"
        log_error "Allowed modes: 'download' or 'local'"
        exit 1
        ;;
esac

log_info "Script completed successfully"