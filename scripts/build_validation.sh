#!/bin/bash

# FocusLock Build Validation Framework
# Tracks build progress and prevents regressions

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build"
LOGS_DIR="$BUILD_DIR/logs"

# Create directories
mkdir -p "$LOGS_DIR"
mkdir -p "$BUILD_DIR/reports"

# Configuration
XCODEPROJECT="$PROJECT_ROOT/Dayflow/Dayflow.xcodeproj"
SCHEME="FocusLock"
CONFIGURATION="Debug"

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

# Build validation functions
run_build() {
    local build_type="$1"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local log_file="$LOGS_DIR/build_${build_type}_${timestamp}.log"

    log_info "Running ${build_type} build..."
    log_info "Log file: $log_file"

    # Run xcodebuild
    if xcodebuild -project "$XCODEPROJECT" \
                  -scheme "$SCHEME" \
                  -configuration "$CONFIGURATION" \
                  clean build 2>&1 | tee "$log_file"; then
        log_success "Build completed successfully"
        return 0
    else
        log_error "Build failed"
        return 1
    fi
}

extract_build_metrics() {
    local log_file="$1"
    local report_file="$2"

    log_info "Extracting build metrics from $log_file"

    # Count errors, warnings, and total lines
    local errors=$(grep -c "error:" "$log_file" || echo "0")
    local warnings=$(grep -c "warning:" "$log_file" || echo "0")
    local total_lines=$(wc -l < "$log_file")
    local build_time=$(grep "Build succeeded\|Build failed" "$log_file" | tail -1)

    # Extract key error patterns
    local redeclaration_errors=$(grep -c "invalid redeclaration" "$log_file" || echo "0")
    local sendable_errors=$(grep -c "conforms to 'Sendable'" "$log_file" || echo "0")
    local deprecation_warnings=$(grep -c "was deprecated" "$log_file" || echo "0")

    # Create report
    cat > "$report_file" << EOF
FocusLock Build Report
====================

Build Date: $(date)
Configuration: $CONFIGURATION
Scheme: $SCHEME

BUILD METRICS
-------------
Total Lines: $total_lines
Errors: $errors
Warnings: $warnings
Build Time: $build_time

ERROR BREAKDOWN
--------------
Redeclaration Errors: $redeclaration_errors
Sendable Conformance Errors: $sendable_errors

WARNING BREAKDOWN
-----------------
Deprecation Warnings: $deprecation_warnings

TOP ERRORS
----------
$(grep "error:" "$log_file" | head -10)

TOP WARNINGS
------------
$(grep "warning:" "$log_file" | head -10)

EOF

    echo "Report saved to: $report_file"
}

compare_builds() {
    local current_log="$1"
    local baseline_log="$2"
    local report_file="$3"

    log_info "Comparing build with baseline..."

    # Extract metrics from both builds
    local current_errors=$(grep -c "error:" "$current_log" || echo "0")
    local baseline_errors=$(grep -c "error:" "$baseline_log" || echo "0")
    local current_warnings=$(grep -c "warning:" "$current_log" || echo "0")
    local baseline_warnings=$(grep -c "warning:" "$baseline_log" || echo "0")

    # Calculate differences
    local error_diff=$((current_errors - baseline_errors))
    local warning_diff=$((current_warnings - baseline_warnings))

    # Generate comparison report
    cat > "$report_file" << EOF
Build Comparison Report
======================

Comparison Date: $(date)

BASELINE METRICS
----------------
Baseline Errors: $baseline_errors
Baseline Warnings: $baseline_warnings

CURRENT METRICS
---------------
Current Errors: $current_errors
Current Warnings: $current_warnings

DELTA
-----
Error Change: $error_diff
Warning Change: $warning_diff

EOF

    if [ $error_diff -gt 0 ]; then
        echo -e "${RED}REGRESSION DETECTED: +$error_diff errors${NC}" >> "$report_file"
        return 1
    elif [ $error_diff -lt 0 ]; then
        echo -e "${GREEN}IMPROVEMENT: $error_diff fewer errors${NC}" >> "$report_file"
    fi

    if [ $warning_diff -gt 10 ]; then
        echo -e "${YELLOW}WARNING INCREASE: +$warning_diff warnings${NC}" >> "$report_file"
    fi

    echo "Comparison report saved to: $report_file"
    return 0
}

validate_dependencies() {
    log_info "Validating external dependencies..."

    # Check if critical packages are resolving
    if xcodebuild -project "$XCODEPROJECT" -resolvePackageDependencies > /dev/null 2>&1; then
        log_success "Package dependencies resolved successfully"
        return 0
    else
        log_error "Package dependency resolution failed"
        return 1
    fi
}

run_tests() {
    log_info "Running test suite..."

    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local test_log="$LOGS_DIR/test_${timestamp}.log"

    if xcodebuild test -project "$XCODEPROJECT" \
                     -scheme "$SCHEME" \
                     -destination 'platform=macOS' 2>&1 | tee "$test_log"; then
        log_success "All tests passed"
        return 0
    else
        log_error "Test failures detected"
        return 1
    fi
}

# Main execution
main() {
    local command="$1"

    case "$command" in
        "baseline")
            log_info "Establishing build baseline..."
            run_build "baseline"
            extract_build_metrics "$LOGS_DIR/build_baseline_$(date +"%Y%m%d_%H%M%S").log" \
                              "$BUILD_DIR/reports/baseline_report.txt"
            ;;
        "validate")
            log_info "Running build validation..."
            validate_dependencies || exit 1

            local latest_build=$(ls -t "$LOGS_DIR"/build_*.log | head -1)
            local baseline_build="$LOGS_DIR/build_output_baseline.log"

            if [ -f "$baseline_build" ]; then
                compare_builds "$latest_build" "$baseline_build" \
                               "$BUILD_DIR/reports/comparison_report.txt"
            fi
            ;;
        "test")
            run_tests
            ;;
        "full")
            log_info "Running full validation suite..."
            validate_dependencies || exit 1
            run_build "validation"
            run_tests
            ;;
        *)
            echo "Usage: $0 {baseline|validate|test|full}"
            echo ""
            echo "Commands:"
            echo "  baseline  - Establish baseline build metrics"
            echo "  validate  - Compare current build with baseline"
            echo "  test      - Run test suite"
            echo "  full      - Run complete validation suite"
            exit 1
            ;;
    esac
}

main "$@"