#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -euo pipefail

# ANSI color codes for CLI styling
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print functions
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Get script source directory
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
SRC_WALLPAPERS="$SCRIPT_DIR/wallpapers"
DEST_PICTURES="$HOME/Pictures"
DEST_WALLPAPER="$DEST_PICTURES/wallpapers"

echo -e "${PURPLE}=============================================${NC}"
echo -e "${PURPLE}     Wallpaper Installation Script           ${NC}"
echo -e "${PURPLE}=============================================${NC}"

# Setup temporary directory cleanup
TEMP_DIR=""
cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

# Check if source directory exists locally, if not, fetch it from GitHub
if [ ! -d "$SRC_WALLPAPERS" ]; then
    info "Local wallpaper source not found. Downloading wallpaper collection from GitHub..."
    
    TEMP_DIR=$(mktemp -d)
    REPO_ZIP_URL="https://github.com/sadid56/wallpapers/archive/refs/heads/main.zip"
    
    # Attempt git clone with larger buffer and relaxed timeouts
    CLONE_SUCCESS=false
    if command -v git &>/dev/null; then
        info "Cloning wallpaper repository (shallow clone)..."
        if GIT_TERMINAL_PROMPT=0 git -c http.postBuffer=524288000 clone --depth 1 --config http.lowSpeedLimit=1000 --config http.lowSpeedTime=30 https://github.com/sadid56/wallpapers.git "$TEMP_DIR/wallpapers_repo"; then
            if [ -d "$TEMP_DIR/wallpapers_repo/wallpapers" ]; then
                SRC_WALLPAPERS="$TEMP_DIR/wallpapers_repo/wallpapers"
            else
                SRC_WALLPAPERS="$TEMP_DIR/wallpapers_repo"
            fi
            CLONE_SUCCESS=true
        else
            warn "Git clone failed or timed out. Falling back to archive download..."
        fi
    fi
    
    # Fallback to wget/curl with retry & resume capabilities
    if [ "$CLONE_SUCCESS" = false ]; then
        info "Downloading repository archive (supports retry & resume)..."
        
        if command -v curl &>/dev/null; then
            # curl: -C - (resume), --retry 3 (retry up to 3 times), show progress meter
            curl -L -C - --retry 3 --retry-delay 2 --connect-timeout 30 "$REPO_ZIP_URL" -o "$TEMP_DIR/archive.zip"
        elif command -v wget &>/dev/null; then
            # wget: -c (resume), -t 3 (tries), --timeout=30
            wget -c -t 3 --timeout=30 --show-progress "$REPO_ZIP_URL" -O "$TEMP_DIR/archive.zip"
        else
            error "Neither curl, wget, nor git is installed. Cannot download wallpapers."
            exit 1
        fi
        
        if command -v unzip &>/dev/null; then
            info "Extracting archive..."
            unzip -q "$TEMP_DIR/archive.zip" -d "$TEMP_DIR"
            if [ -d "$TEMP_DIR/wallpapers-main/wallpapers" ]; then
                SRC_WALLPAPERS="$TEMP_DIR/wallpapers-main/wallpapers"
            else
                SRC_WALLPAPERS="$TEMP_DIR/wallpapers-main"
            fi
        else
            error "unzip command not found. Cannot extract downloaded zip archive."
            exit 1
        fi
    fi
fi

if [ ! -d "$SRC_WALLPAPERS" ]; then
    error "Failed to retrieve wallpaper source directory."
    exit 1
fi

# Ensure target Pictures directory exists
if [ ! -d "$DEST_PICTURES" ]; then
    info "Creating target Pictures directory at '$DEST_PICTURES'..."
    mkdir -p "$DEST_PICTURES"
    success "Pictures directory created."
fi

# Backup existing wallpapers directory if present
if [ -e "$DEST_WALLPAPER" ] || [ -L "$DEST_WALLPAPER" ]; then
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_DIR="$DEST_PICTURES/wallpaper_backup_$TIMESTAMP"
    warn "Existing wallpaper directory found at '$DEST_WALLPAPER'."
    info "Moving existing directory to backup: '$BACKUP_DIR'..."
    
    if mv "$DEST_WALLPAPER" "$BACKUP_DIR"; then
        success "Backup created successfully."
    else
        error "Failed to create backup of existing directory!"
        exit 1
    fi
fi

mkdir -p "$DEST_WALLPAPER"

# Copy wallpapers using rsync if available (faster & safer for large files), otherwise cp
info "Installing wallpapers to '$DEST_WALLPAPER'..."

if command -v rsync &>/dev/null; then
    rsync -ah --progress "$SRC_WALLPAPERS/" "$DEST_WALLPAPER/"
    success "Wallpapers installed successfully via rsync!"
else
    TOTAL_FILES=$(find "$SRC_WALLPAPERS" -maxdepth 1 -type f | wc -l)
    CURRENT=0
    
    if [ "$TOTAL_FILES" -eq 0 ]; then
        warn "No files found in source wallpapers directory!"
    else
        while IFS= read -r -d '' file; do
            filename=$(basename "$file")
            cp "$file" "$DEST_WALLPAPER/"
            CURRENT=$((CURRENT + 1))
            echo -e "   [${CURRENT}/${TOTAL_FILES}] Installed: ${CYAN}${filename}${NC}"
        done < <(find "$SRC_WALLPAPERS" -maxdepth 1 -type f -print0)
        
        success "All $TOTAL_FILES wallpapers installed successfully to '$DEST_WALLPAPER'!"
    fi
fi

echo -e "${PURPLE}=============================================${NC}"
