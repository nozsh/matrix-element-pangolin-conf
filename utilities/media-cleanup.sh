#!/bin/bash

# Matrix Synapse Media Cleanup Script
# This script logs in to Matrix Synapse, deletes old media files, and logs out

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# Configuration
URL="http://10.10.10.2:8008"
USER="@admin:domain.org"
PASS="abrakadabra"
DELAFTERMS=60000  # Delete media older than this many milliseconds, 60000 = 1m (for test)
LOGOUTALL=false # If true, logout all tokens; if false, logout only current token

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Login to Matrix Synapse
log_info "Authenticating to Matrix Synapse server..."
LOGIN_RESP=$(curl -s -X POST "$URL/_matrix/client/v3/login" \
    -H "Content-Type: application/json" \
    -d "{\"type\":\"m.login.password\",\"user\":\"$USER\",\"password\":\"$PASS\"}")

if [[ -z "$LOGIN_RESP" ]]; then
    log_error "Failed to get login response"
    exit 1
fi

echo "Login response: $LOGIN_RESP"

# Extract access token
TOKEN=$(echo "$LOGIN_RESP" | grep -oP '"access_token":"\K[^"]+')

if [[ -z "$TOKEN" ]]; then
    log_error "Failed to extract access token from login response"
    exit 1
fi

log_info "Successfully authenticated. Token: $TOKEN"

# Calculate timestamp for media deletion
BEFORE_TS=$(($(date +%s%3N) - DELAFTERMS))
log_info "Deleting media files older than $(date -d "@$((BEFORE_TS/1000))" '+%Y-%m-%d %H:%M:%S')"

# Delete old media files
log_info "Starting media cleanup..."
CLEANUP_RESP=$(curl -s -X POST \
    -H "Authorization: Bearer $TOKEN" \
    "$URL/_synapse/admin/v1/media/delete?before_ts=$BEFORE_TS")

if [[ $? -eq 0 ]]; then
    log_info "Media cleanup completed successfully"
    echo "Cleanup response: $CLEANUP_RESP"
else
    log_error "Media cleanup failed"
fi

# Logout and invalidate tokens
if [[ "$LOGOUTALL" == "true" ]]; then
    log_info "Logging out and invalidating all tokens..."
    LOGOUT_ENDPOINT="$URL/_matrix/client/v3/logout/all"
else
    log_info "Logging out and invalidating current token only..."
    LOGOUT_ENDPOINT="$URL/_matrix/client/v3/logout"
fi

LOGOUT_RESP=$(curl -s -X POST "$LOGOUT_ENDPOINT" \
    -H "Authorization: Bearer $TOKEN")

if [[ $? -eq 0 ]]; then
    if [[ "$LOGOUTALL" == "true" ]]; then
        log_info "Successfully logged out from all sessions"
    else
        log_info "Successfully logged out from current session"
    fi
    echo "Logout response: $LOGOUT_RESP"
else
    log_warn "Logout may have failed, but continuing..."
fi

log_info "Script completed successfully"