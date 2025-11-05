#!/bin/bash

# FocusLock DerivedData Cleanup Script
# Safely removes corrupted DerivedData to fix build database I/O errors

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Configuration
XCODEPROJECT="$PROJECT_ROOT/Dayflow/Dayflow.xcodeproj"
SCHEME="FocusLock"
DERIVED_DATA_BASE="$HOME/Library/Developer/Xcode/DerivedData"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Find DerivedData directory for the project
find_derived_data() {
    local project_name=$(basename "$XCODEPROJECT" .xcodeproj)
    
    # Try to find DerivedData by matching project name
    if [ -d "$DERIVED_DATA_BASE" ]; then
        find "$DERIVED_DATA_BASE" -maxdepth 1 -type d -name "${project_name}-*" 2>/dev/null | head -1
    fi
}

# Check for running Xcode processes
check_xcode_processes() {
    local xcode_processes=$(ps aux | grep -i xcode | grep -v grep | grep -v "$0" || true)
    
    if [ -n "$xcode_processes" ]; then
        log_warning "Xcode processes are running. They may hold file locks."
        log_info "Consider closing Xcode before cleanup for best results."
        
        read -p "Do you want to terminate Xcode processes? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Terminating Xcode processes..."
            killall Xcode 2>/dev/null || true
            killall xcodebuild 2>/dev/null || true
            sleep 2
            log_success "Xcode processes terminated"
        else
            log_warning "Proceeding with Xcode running - some files may be locked"
        fi
    else
        log_info "No Xcode processes detected"
    fi
}

# Clean DerivedData for the project
clean_derived_data() {
    local derived_data_path="$1"
    
    if [ -z "$derived_data_path" ]; then
        log_warning "No DerivedData directory found for this project"
        return 0
    fi
    
    if [ ! -d "$derived_data_path" ]; then
        log_warning "DerivedData directory does not exist: $derived_data_path"
        return 0
    fi
    
    log_info "Found DerivedData directory: $derived_data_path"
    log_info "Removing DerivedData directory..."
    
    if rm -rf "$derived_data_path" 2>/dev/null; then
        log_success "DerivedData directory removed successfully"
        return 0
    else
        log_error "Failed to remove DerivedData directory (may be locked by Xcode)"
        return 1
    fi
}

# Clean project build artifacts
clean_project_artifacts() {
    log_info "Cleaning project build artifacts..."
    
    # Remove build logs
    find "$PROJECT_ROOT/Dayflow" -name "*.log" -type f -delete 2>/dev/null || true
    find "$PROJECT_ROOT/Dayflow" -name "build_output*" -type f -delete 2>/dev/null || true
    
    # Run xcodebuild clean
    log_info "Running xcodebuild clean..."
    if xcodebuild -project "$XCODEPROJECT" \
                   -scheme "$SCHEME" \
                   -configuration Debug \
                   clean > /dev/null 2>&1; then
        log_success "Project cleaned successfully"
        return 0
    else
        log_warning "xcodebuild clean had issues (may be normal if project is corrupted)"
        return 0
    fi
}

# Main cleanup function
main() {
    local force_clean="${1:-}"
    
    log_info "FocusLock DerivedData Cleanup"
    log_info "=============================="
    echo
    
    # Check Xcode processes
    if [ "$force_clean" != "--force" ]; then
        check_xcode_processes
    else
        log_info "Force mode: Terminating Xcode processes..."
        killall Xcode 2>/dev/null || true
        killall xcodebuild 2>/dev/null || true
        sleep 2
    fi
    
    # Find and clean DerivedData
    local derived_data=$(find_derived_data)
    
    if [ -n "$derived_data" ]; then
        clean_derived_data "$derived_data"
    else
        log_info "No DerivedData found - may already be cleaned"
    fi
    
    # Clean project artifacts
    clean_project_artifacts
    
    echo
    log_success "Cleanup completed!"
    log_info "You can now rebuild the project - DerivedData will be regenerated automatically"
}

# Run main function
main "$@"

