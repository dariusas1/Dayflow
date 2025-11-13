# Deployment Configuration - FocusLock

## Infrastructure Requirements

### Development Environment
- **macOS 13.0+** development machine
- **Xcode 15+** with Apple Developer account
- **Git** version control
- **GitHub CLI** for release automation

### Distribution Infrastructure
- **Apple Developer Program** membership ($99/year)
- **GitHub repository** for releases and source code
- **Static hosting** for appcast.xml (currently dayflow.so)
- **Code signing certificates** in macOS Keychain
- **Notarization service** via Apple's notary service

## Deployment Process

### Automated Deployment Pipeline
The project uses a comprehensive automated deployment system via `scripts/release.sh`:

#### 1. Version Management
- **Automatic version bumping** (major/minor/patch)
- **Xcode project synchronization** (MARKETING_VERSION, CURRENT_PROJECT_VERSION)
- **Info.plist consistency** maintenance
- **Git tagging** and version commits

#### 2. Build and Sign
- **Release build compilation** with optimization
- **Developer ID code signing** for distribution
- **DMG creation** with professional styling
- **Sparkle update signing** for automatic updates

#### 3. Notarization
- **Apple notary service submission**
- **Stapling of notarization ticket** to DMG
- **Validation of notarization status**
- **Error handling and retry logic**

#### 4. Distribution
- **GitHub release creation** with changelog
- **DMG asset upload** to release
- **Appcast.xml update** for Sparkle
- **Git push** with tags and updates

### Manual Deployment Steps
If automation fails, manual deployment follows these steps:

#### Step 1: Version Preparation
```bash
# Update version in Xcode project
xcrun agvtool new-marketing-version "1.2.0"
xcrun agvtool new-version -all "42"

# Update Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 1.2.0" Dayflow/Dayflow/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion 42" Dayflow/Dayflow/Info.plist
```

#### Step 2: Build and Archive
```bash
# Create release archive
xcodebuild -project Dayflow.xcodeproj \
  -scheme Dayflow \
  -configuration Release \
  -archivePath ./build/Dayflow.xcarchive \
  archive

# Export for distribution
xcodebuild -exportArchive \
  -archivePath ./build/Dayflow.xcarchive \
  -exportPath ./build/ \
  -exportOptionsPlist ExportOptions.plist
```

#### Step 3: DMG Creation
```bash
# Create professional DMG
./scripts/release_dmg.sh

# Manual DMG creation (if script fails)
hdiutil create -volname "Dayflow" \
  -srcfolder ./build/Dayflow.app \
  -ov -format UDZO ./build/Dayflow.dmg
```

#### Step 4: Code Signing
```bash
# Sign the application
codesign --force --verify --verbose \
  --sign "Developer ID Application: Your Name" \
  --entitlements Dayflow/Dayflow/Dayflow.entitlements \
  ./build/Dayflow.app

# Sign the DMG
codesign --force --verify --verbose \
  --sign "Developer ID Application: Your Name" \
  ./build/Dayflow.dmg
```

#### Step 5: Notarization
```bash
# Upload for notarization
xcrun notarytool submit ./build/Dayflow.dmg \
  --apple-id "your@email.com" \
  --password "app-specific-password" \
  --team-id "YOUR_TEAM_ID"

# Wait for notarization (usually 5-10 minutes)
xcrun notarytool history

# Staple notarization ticket
xcrun stapler staple ./build/Dayflow.dmg
```

#### Step 6: Sparkle Signing
```bash
# Sign update for Sparkle
sign_update ./build/Dayflow.dmg

# Save the signature for appcast.xml
# Output: sparkle:edSignature="..." length="..."
```

## Configuration Files

### Release Configuration
**File:** `scripts/release.env.example` (template)
```bash
# Apple Developer Information
APPLE_ID="your@email.com"
APPLE_PASSWORD="app-specific-password"
TEAM_ID="YOUR_TEAM_ID"

# Sparkle Configuration
SPARKLE_PRIVATE_KEY="base64_encoded_private_key"

# GitHub Configuration
GITHUB_TOKEN="ghp_your_github_token"

# Build Configuration
CONFIGURATION="Release"
SCHEME="Dayflow"
APP_NAME="Dayflow"
```

### Export Options
**File:** `ExportOptions.plist`
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>destination</key>
    <string>export</string>
    <key>provisioningProfiles</key>
    <dict/>
</dict>
</plist>
```

### Appcast Configuration
**File:** `docs/appcast.xml`
```xml
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Dayflow Appcast</title>
    <description>Most recent version of Dayflow</description>
    <language>en</language>
    <item>
      <title>Dayflow 1.2.0</title>
      <description>Release notes here...</description>
      <pubDate>Mon, 13 Nov 2025 00:00:00 +0000</pubDate>
      <enclosure
        sparkle:version="42"
        sparkle:shortVersionString="1.2.0"
        sparkle:edSignature="signature_here"
        sparkle:minimumSystemVersion="13.0"
        url="https://github.com/JerryZLiu/Dayflow/releases/download/v1.2.0/Dayflow.dmg"
        length="25000000"
        type="application/octet-stream"/>
    </item>
  </channel>
</rss>
```

## CI/CD Pipeline

### GitHub Actions (Future Enhancement)
While currently using manual release automation, the project is structured for CI/CD:

#### Workflow Triggers
- **Release creation** (manual trigger)
- **Tag push** (automatic for version tags)
- **Schedule** (nightly builds for testing)

#### Pipeline Stages
1. **Environment Setup**
   - macOS runner configuration
   - Xcode installation and setup
   - Certificate and provisioning profile loading

2. **Build and Test**
   - Debug build compilation
   - Unit test execution
   - UI test validation
   - Performance benchmarking

3. **Release Preparation**
   - Version bump validation
   - Release build compilation
   - Code signing verification

4. **Distribution**
   - DMG creation and signing
   - Notarization submission
   - GitHub release creation
   - Appcast update

### Current Automation Scripts

#### `scripts/release.sh` - Main Release Script
- **Purpose**: One-button release automation
- **Features**: Version bumping, build, sign, notarize, distribute
- **Dependencies**: Xcode, GitHub CLI, Sparkle CLI

#### `scripts/release_dmg.sh` - DMG Creation
- **Purpose**: Create professional DMG installer
- **Features**: Custom styling, background image, proper layout
- **Output**: Ready-to-distribute Dayflow.dmg

#### `scripts/make_appcast.sh` - Appcast Generation
- **Purpose**: Generate Sparkle appcast.xml
- **Features**: Version tracking, signature integration
- **Output**: Update feed for automatic updates

#### `scripts/update_appcast.sh` - Appcast Updates
- **Purpose**: Update existing appcast with new release
- **Features**: XML manipulation, signature insertion
- **Output**: Updated appcast.xml

## Environment Configuration

### Development Environment
```bash
# Required environment variables for development
export GEMINI_API_KEY="your_gemini_api_key"
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
export CODE_SIGN_IDENTITY="Developer ID Application: Your Name"
```

### Release Environment
```bash
# Required for release automation
export APPLE_ID="your@email.com"
export APPLE_PASSWORD="app-specific-password"
export TEAM_ID="YOUR_TEAM_ID"
export SPARKLE_PRIVATE_KEY="base64_encoded_key"
export GITHUB_TOKEN="ghp_your_token"
```

### Security Considerations

#### Certificate Management
- **Developer ID certificates** stored in macOS Keychain
- **Private keys** protected by Keychain security
- **Sparkle signing key** optionally base64 encoded for CI
- **No certificates** committed to repository

#### Secret Management
- **API keys** injected via environment variables
- **No secrets** in source code or configuration files
- **App-specific passwords** used for Apple services
- **GitHub tokens** with minimal required permissions

## Monitoring and Maintenance

### Release Monitoring
- **GitHub release analytics** for download tracking
- **Sparkle update metrics** for adoption rates
- **Crash reports** via Sentry integration
- **Performance metrics** through PostHog analytics

### Infrastructure Health
- **Appcast availability** monitoring
- **CDN performance** for DMG downloads
- **Certificate expiration** tracking
- **Notarization service** availability

### Maintenance Tasks
- **Certificate renewal** before expiration (annual)
- **Sparkle key rotation** (security best practice)
- **Dependency updates** for security patches
- **Xcode compatibility** testing with new releases

## Rollback Procedures

### Emergency Rollback
If a critical issue is discovered post-release:

1. **Immediate Actions**
   - Hide or delete the GitHub release
   - Update appcast.xml to point to previous version
   - Communicate with users about the issue

2. **Fix and Re-release**
   - Create hotfix branch from previous stable tag
   - Implement fix with comprehensive testing
   - Use patch version bump (e.g., 1.2.1)
   - Follow standard release process

3. **Post-mortem**
   - Document root cause and impact
   - Update testing procedures
   - Implement additional safeguards
   - Review release checklist

### Version Strategy
- **Semantic versioning** (MAJOR.MINOR.PATCH)
- **Backward compatibility** maintained within major versions
- **Database migrations** handled gracefully
- **Configuration migration** for settings changes

## Compliance and Legal

### Apple Developer Agreement
- **Developer ID** compliance for distribution
- **Code signing** requirements met
- **Notarization** process followed
- **Privacy policy** compliance

### Open Source Licensing
- **MIT License** for all source code
- **Third-party licenses** documented and complied with
- **Attribution** provided for all dependencies
- **License compatibility** verified

### Privacy Compliance
- **Data collection** transparent and documented
- **User consent** obtained for all data processing
- **Local processing** options available
- **Data retention** policies implemented