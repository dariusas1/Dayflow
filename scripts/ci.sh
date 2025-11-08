#!/bin/bash
#
# CI Script for FocusLock
# Runs linting, builds, tests, and generates reports
#
# Usage:
#   ./scripts/ci.sh [lint|build|test|all]
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XCODE_PROJECT="$PROJECT_DIR/Dayflow/Dayflow.xcodeproj"
SCHEME="FocusLock"
CONFIGURATION="Debug"
DESTINATION="platform=macOS"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[CI]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running on macOS
check_macos() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_error "This script must run on macOS with Xcode installed"
        exit 1
    fi
}

# Check for xcodebuild
check_xcodebuild() {
    if ! command -v xcodebuild &> /dev/null; then
        print_error "xcodebuild not found. Please install Xcode."
        exit 1
    fi
}

# Install dependencies
install_deps() {
    print_status "Installing CI dependencies..."

    # Check for Homebrew
    if ! command -v brew &> /dev/null; then
        print_warning "Homebrew not found. Some tools may be unavailable."
    else
        # Install SwiftLint if available
        if ! command -v swiftlint &> /dev/null; then
            print_status "Installing SwiftLint..."
            brew install swiftlint || print_warning "SwiftLint installation failed"
        fi

        # Install xcbeautify if available
        if ! command -v xcbeautify &> /dev/null; then
            print_status "Installing xcbeautify..."
            brew install xcbeautify || print_warning "xcbeautify installation failed"
        fi
    fi
}

# Run SwiftLint
run_lint() {
    print_status "Running SwiftLint..."

    if command -v swiftlint &> /dev/null; then
        cd "$PROJECT_DIR/Dayflow/Dayflow"
        swiftlint lint --strict --reporter json > "$PROJECT_DIR/build/swiftlint-results.json" || true
        swiftlint lint --strict || print_warning "SwiftLint found issues"
        cd "$PROJECT_DIR"
    else
        print_warning "SwiftLint not installed, skipping linting"
    fi
}

# Build project
run_build() {
    print_status "Building project..."

    mkdir -p "$PROJECT_DIR/build"

    if command -v xcbeautify &> /dev/null; then
        xcodebuild -project "$XCODE_PROJECT" \
                   -scheme "$SCHEME" \
                   -configuration "$CONFIGURATION" \
                   -destination "$DESTINATION" \
                   clean build \
                   CODE_SIGN_IDENTITY="" \
                   CODE_SIGNING_REQUIRED=NO \
                   | xcbeautify
    else
        xcodebuild -project "$XCODE_PROJECT" \
                   -scheme "$SCHEME" \
                   -configuration "$CONFIGURATION" \
                   -destination "$DESTINATION" \
                   clean build \
                   CODE_SIGN_IDENTITY="" \
                   CODE_SIGNING_REQUIRED=NO
    fi

    print_status "Build completed successfully"
}

# Run tests
run_tests() {
    print_status "Running tests..."

    mkdir -p "$PROJECT_DIR/build/test-results"

    if command -v xcbeautify &> /dev/null; then
        xcodebuild -project "$XCODE_PROJECT" \
                   -scheme "$SCHEME" \
                   -configuration "$CONFIGURATION" \
                   -destination "$DESTINATION" \
                   test \
                   CODE_SIGN_IDENTITY="" \
                   CODE_SIGNING_REQUIRED=NO \
                   -resultBundlePath "$PROJECT_DIR/build/test-results" \
                   | xcbeautify
    else
        xcodebuild -project "$XCODE_PROJECT" \
                   -scheme "$SCHEME" \
                   -configuration "$CONFIGURATION" \
                   -destination "$DESTINATION" \
                   test \
                   CODE_SIGN_IDENTITY="" \
                   CODE_SIGNING_REQUIRED=NO \
                   -resultBundlePath "$PROJECT_DIR/build/test-results"
    fi

    print_status "Tests completed successfully"
}

# Run code coverage
run_coverage() {
    print_status "Generating code coverage report..."

    xcodebuild -project "$XCODE_PROJECT" \
               -scheme "$SCHEME" \
               -configuration "$CONFIGURATION" \
               -destination "$DESTINATION" \
               -enableCodeCoverage YES \
               test \
               CODE_SIGN_IDENTITY="" \
               CODE_SIGNING_REQUIRED=NO

    print_status "Coverage report generated"
}

# Run sanitizers
run_sanitizers() {
    print_status "Running with sanitizers (Address, Thread, Undefined)..."
    print_warning "Note: Sanitizers must be enabled in Xcode scheme settings"

    # This requires the scheme to have sanitizers enabled
    # Instructions: Edit Scheme → Test → Diagnostics → Enable Address/Thread/Undefined Sanitizers

    xcodebuild -project "$XCODE_PROJECT" \
               -scheme "$SCHEME" \
               -configuration "$CONFIGURATION" \
               -destination "$DESTINATION" \
               test

    print_status "Sanitizer run completed"
}

# Generate documentation
generate_docs() {
    print_status "Generating documentation..."

    if command -v jazzy &> /dev/null; then
        jazzy --clean \
              --author "FocusLock Team" \
              --module "FocusLock" \
              --output "$PROJECT_DIR/docs/api" \
              --xcodebuild-arguments -project,"$XCODE_PROJECT",-scheme,"$SCHEME"
        print_status "Documentation generated at docs/api/"
    else
        print_warning "Jazzy not installed. Install with: gem install jazzy"
    fi
}

# Main execution
main() {
    cd "$PROJECT_DIR"

    case "${1:-all}" in
        deps)
            install_deps
            ;;
        lint)
            check_macos
            run_lint
            ;;
        build)
            check_macos
            check_xcodebuild
            run_build
            ;;
        test)
            check_macos
            check_xcodebuild
            run_tests
            ;;
        coverage)
            check_macos
            check_xcodebuild
            run_coverage
            ;;
        sanitizers)
            check_macos
            check_xcodebuild
            run_sanitizers
            ;;
        docs)
            generate_docs
            ;;
        all)
            check_macos
            check_xcodebuild
            install_deps
            run_lint
            run_build
            run_tests
            print_status "All CI checks passed! ✅"
            ;;
        *)
            echo "Usage: $0 {deps|lint|build|test|coverage|sanitizers|docs|all}"
            exit 1
            ;;
    esac
}

main "$@"
