# Makefile for FocusLock
# Provides convenient commands for development, testing, and release

.PHONY: help deps lint build test coverage clean docs beta-check all

# Default target
help:
	@echo "FocusLock Development Commands:"
	@echo ""
	@echo "  make deps        - Install CI dependencies (SwiftLint, xcbeautify, etc.)"
	@echo "  make lint        - Run SwiftLint"
	@echo "  make build       - Build the project"
	@echo "  make test        - Run all tests"
	@echo "  make coverage    - Generate code coverage report"
	@echo "  make sanitizers  - Run tests with sanitizers enabled"
	@echo "  make docs        - Generate API documentation"
	@echo "  make clean       - Clean build artifacts"
	@echo "  make beta-check  - Run full beta readiness validation"
	@echo "  make all         - Run lint + build + test"
	@echo ""

# Install dependencies
deps:
	@./scripts/ci.sh deps

# Run linting
lint:
	@./scripts/ci.sh lint

# Build project
build:
	@./scripts/ci.sh build

# Run tests
test:
	@./scripts/ci.sh test

# Generate coverage
coverage:
	@./scripts/ci.sh coverage

# Run sanitizers
sanitizers:
	@./scripts/ci.sh sanitizers

# Generate docs
docs:
	@./scripts/ci.sh docs

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf build/
	@rm -rf DerivedData/
	@echo "Clean complete"

# Beta readiness check
beta-check: lint build test
	@echo "✅ Beta readiness check passed!"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Review BETA_READINESS.md"
	@echo "  2. Test manually on macOS 13+"
	@echo "  3. Enable sanitizers and run again"
	@echo "  4. Package for distribution"

# Run all checks
all:
	@./scripts/ci.sh all
