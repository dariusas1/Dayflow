# Deployment Configuration - FocusLock

## Overview

FocusLock uses a comprehensive deployment pipeline centered around automated macOS application distribution with Sparkle for updates and GitHub for releases. The deployment process is fully automated through shell scripts with proper code signing, notarization, and update distribution.

## Deployment Architecture

### Release Pipeline Components

#### 1. Primary Release Script (`scripts/release.sh`)
**Purpose**: One-button release automation
**Features**:
- Version bumping (major/minor/patch)
- Xcode project and Info.plist synchronization
- Automated build, sign, and notarize
- Sparkle update signing
- GitHub release creation and management
- Appcast.xml updates

**Release Process Flow**:
```
Version Bump → Build & Sign → Notarize → Sparkle Sign → GitHub Release → Appcast Update → Push
```

#### 2. DMG Creation (`scripts/release_dmg.sh`)
**Purpose**: Creates signed and notarized DMG installer
**Features**:
- Custom DMG styling with background
- Code signing with Developer ID
- Apple notarization integration
- Automated artifact creation

#### 3. Sparkle Integration (`scripts/update_appcast.sh`)
**Purpose**: Manages Sparkle update feed
**Features**:
- Appcast.xml generation
- Delta update support
- Signature integration
- Version management

### Build Configuration

#### Xcode Project Settings
- **Target**: Dayflow
- **Configuration**: Release
- **Version Management**: MARKETING_VERSION and CURRENT_PROJECT_VERSION
- **Code Signing**: Developer ID Application
- **Notarization**: Apple Notary Service

#### Build Requirements
- **Xcode**: Latest version with command line tools
- **macOS**: Development machine with signing certificates
- **Certificates**: Developer ID Application in login keychain
- **Tools**: Sparkle CLI, GitHub CLI

### Version Management

#### Version Bumping Strategy
```bash
# Major version bump
./scripts/release.sh --major

# Minor version bump (default)
./scripts/release.sh --minor

# Patch version bump
./scripts/release.sh --patch
```

#### Version Synchronization
- **Xcode Project**: MARKETING_VERSION and CURRENT_PROJECT_VERSION
- **Info.plist**: CFBundleShortVersionString and CFBundleVersion
- **Git Tags**: Automatic tag creation and pushing
- **Appcast**: Version monotonicity enforcement

### Code Signing & Security

#### Developer ID Signing
- **Certificate**: Developer ID Application
- **Keychain**: Login keychain storage
- **Automated**: Script-based signing process
- **Validation**: Signature verification

#### Apple Notarization
- **Service**: Apple Notary Service
- **Integration**: Automated notarization submission
- **Stapling**: Notarization staple attachment
- **Validation**: Notarization status checking

#### Sparkle Update Signing
- **Key Type**: Ed25519 private key
- **Storage**: Keychain or environment variable
- **Automation**: sign_update CLI integration
- **Security**: Cryptographic update verification

### Release Distribution

#### GitHub Releases
- **Automatic**: Draft release creation
- **Assets**: DMG upload and management
- **Metadata**: Version information and release notes
- **Publishing**: Automated draft publication

#### Sparkle Update Feed
- **Location**: `https://dayflow.so/appcast.xml`
- **Format**: Sparkle XML format
- **Features**: Delta updates, version checking
- **Security**: Signature verification

#### Website Integration
- **Domain**: dayflow.so
- **Static Hosting**: GitHub Pages
- **SSL**: HTTPS encryption
- **Accessibility**: Public update feed

### Deployment Scripts

#### Primary Release Script Features
```bash
#!/usr/bin/env bash
# Usage examples:
./scripts/release.sh                    # Minor bump
./scripts/release.sh --major            # Major bump
./scripts/release.sh --patch            # Patch bump
./scripts/release.sh --dry-run          # Preview changes
./scripts/release.sh --no-notarize      # Skip notarization
```

#### Script Capabilities
1. **Version Management**
   - Automatic version bumping
   - Xcode project synchronization
   - Info.plist updates
   - Git tagging

2. **Build Process**
   - Clean build environment
   - Release configuration
   - Code signing
   - DMG creation

3. **Security Integration**
   - Developer ID signing
   - Apple notarization
   - Sparkle signature generation
   - Certificate validation

4. **Distribution**
   - GitHub release creation
   - Asset upload
   - Appcast.xml updates
   - Git operations

### Environment Configuration

#### Required Environment Variables
```bash
# Optional: Notarization credentials
NOTARY_PROFILE="Developer ID Application: Team Name"
APPLE_ID="developer@example.com"
ASC_PROVIDER="TeamID"

# Optional: Sparkle private key for CI
SPARKLE_PRIVATE_KEY="base64-encoded-key"

# Optional: Custom Sparkle key account
SIGN_ACCOUNT="custom-account-name"
```

#### Required Tools
- **Xcode**: Command Line Tools
- **GitHub CLI**: gh (authenticated)
- **Sparkle CLI**: sign_update
- **PlistBuddy**: /usr/libexec/PlistBuddy
- **Git**: Version control

### Release Process Steps

#### 1. Preparation
```bash
# Ensure clean working directory
git status

# Verify tools are available
gh auth status
sign_update --version
```

#### 2. Version Bump
```bash
# Bump version and commit changes
./scripts/release.sh --minor
```

#### 3. Build & Sign
- Clean build in Release configuration
- Code signing with Developer ID
- DMG creation with custom styling
- Apple notarization submission

#### 4. Distribution
- Sparkle update signature generation
- GitHub release creation (draft)
- DMG asset upload
- Release publication

#### 5. Update Feed
- Appcast.xml generation
- Version information update
- Git commit and push
- Tag creation and push

### Continuous Integration

#### CI/CD Pipeline Support
- **GitHub Actions**: Automated testing
- **Release Automation**: Manual trigger for releases
- **Environment Management**: Secure credential handling
- **Artifact Management**: Build artifact storage

#### Deployment Safety
- **Dry Run Mode**: Preview changes without execution
- **Validation**: Pre-flight checks
- **Rollback**: Git-based rollback capability
- **Monitoring**: Release status tracking

### Monitoring & Maintenance

#### Release Monitoring
- **GitHub Releases**: Release tracking
- **Appcast Updates**: Update feed monitoring
- **Download Analytics**: Usage tracking
- **Error Reporting**: Crash analytics integration

#### Maintenance Tasks
- **Certificate Renewal**: Developer ID certificate updates
- **Key Rotation**: Sparkle key updates
- **Dependency Updates**: Tool and dependency maintenance
- **Script Updates**: Deployment script improvements

### Security Considerations

#### Certificate Management
- **Storage**: Secure keychain storage
- **Rotation**: Regular certificate renewal
- **Backup**: Secure certificate backup
- **Access**: Limited access to signing credentials

#### Update Security
- **Signing**: Cryptographic update verification
- **Transport**: HTTPS for all communications
- **Validation**: Client-side signature verification
- **Integrity**: Update integrity checking

### Troubleshooting

#### Common Issues
1. **Certificate Problems**: Expired Developer ID certificates
2. **Notarization Failures**: Network or Apple service issues
3. **Build Errors**: Xcode configuration problems
4. **Git Issues**: Remote synchronization problems

#### Debugging Tools
- **Dry Run Mode**: Preview release changes
- **Verbose Logging**: Detailed script output
- **Status Checks**: Pre-flight validation
- **Manual Overrides**: Step-by-step control

## Summary

FocusLock's deployment configuration provides:

- **Automation**: One-button release process
- **Security**: Proper code signing and notarization
- **Reliability**: Automated update distribution
- **Maintainability**: Script-based deployment
- **Monitoring**: Comprehensive release tracking
- **Safety**: Validation and rollback capabilities

The deployment pipeline ensures professional-grade macOS application distribution with automatic updates, proper security, and reliable delivery to end users.