#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -euo pipefail

# ANSI color codes for premium CLI styling
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

# Get script source directory to handle calls from anywhere
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SRC_WALLPAPERS="$SCRIPT_DIR/wallpapers"
DEST_PICTURES="$HOME/Pictures"
DEST_WALLPAPER="$DEST_PICTURES/wallpaper"

echo -e "${PURPLE}=============================================${NC}"
echo -e "${PURPLE}     Wallpaper Installation Script           ${NC}"
echo -e "${PURPLE}=============================================${NC}"

# Check if source directory exists
if [ ! -d "$SRC_WALLPAPERS" ]; then
    error "Source directory '$SRC_WALLPAPERS' not found! Make sure you are running the script from within the cloned repository."
    exit 1
fi

# Ensure ~/Pictures directory exists
if [ ! -d "$DEST_PICTURES" ]; then
    info "Creating target Pictures directory at '$DEST_PICTURES'..."
    mkdir -p "$DEST_PICTURES"
    success "Pictures directory created."
fi

# Check if ~/Pictures/wallpaper already exists
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

# Create new wallpaper directory
info "Creating new wallpaper directory at '$DEST_WALLPAPER'..."
mkdir -p "$DEST_WALLPAPER"

# Copy wallpapers
info "Copying wallpapers to '$DEST_WALLPAPER'..."
TOTAL_FILES=$(find "$SRC_WALLPAPERS" -maxdepth 1 -type f | wc -l)
CURRENT=0

if [ "$TOTAL_FILES" -eq 0 ]; then
    warn "No files found in source wallpapers directory!"
else
    while IFS= read -r file; do
        filename=$(basename "$file")
        cp "$file" "$DEST_WALLPAPER/"
        CURRENT=$((CURRENT + 1))
        echo -e "   [${CURRENT}/${TOTAL_FILES}] Installed: ${CYAN}${filename}${NC}"
    done < <(find "$SRC_WALLPAPERS" -maxdepth 1 -type f)
    
    success "All $TOTAL_FILES wallpapers installed successfully to '$DEST_WALLPAPER'!"
fi

echo -e "${PURPLE}=============================================${NC}"
