# Contribution Guide - FocusLock

## Code Style and Conventions

### Swift Style Guide
- **4-space indentation** (no tabs)
- **camelCase** for methods and properties
- **PascalCase** for types and SwiftUI views
- **Trailing commas** for multiline literals
- **final** keyword where inheritance is not required
- **@MainActor** for UI-related code

### SwiftUI Best Practices
- **Prefer value types** for models and data structures
- **Colocate previews** with view definitions using `#Preview`
- **Break large components** into smaller, reusable views
- **Use @StateObject** for view models and @EnvironmentObject** for shared state
- **Prefer @Environment** for shared dependencies and configuration
- **Follow MVVM pattern** with clear separation between View and ViewModel

### File Organization
```
Dayflow/Dayflow/
├── App/                    # Application lifecycle and entry points
├── Core/                   # Business logic and services
│   ├── AI/                # AI/LLM integration services
│   ├── Recording/          # Screen recording and capture
│   └── Thumbnails/        # Image caching and processing
├── Views/                 # SwiftUI user interface
│   ├── Components/        # Reusable UI components
│   ├── Onboarding/        # First-run user experience
│   └── UI/               # Main application views
├── Assets.xcassets/      # Application assets and icons
└── Utilities/            # Helper utilities and extensions
```

### Naming Conventions
- **Views**: PascalCase with descriptive names (e.g., `TimelineView`, `SettingsView`)
- **ViewModels**: PascalCase ending with `ViewModel` (e.g., `TimelineViewModel`)
- **Services**: PascalCase ending with `Service` or `Provider` (e.g., `LLMService`, `GeminiProvider`)
- **Models**: PascalCase representing entities (e.g., `TimelineCard`, `RecordingSession`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_RECORDING_DURATION`)
- **Extensions**: Name for what they extend (e.g., `String+Validation.swift`)

## PR Process

### Before Submitting
1. **Fork the repository** and create a feature branch
2. **Ensure your branch is up to date** with main branch
3. **Make small, focused changes** with clear commit messages
4. **Test thoroughly** on multiple macOS versions if possible
5. **Run the full test suite** and ensure all tests pass

### Branch Naming
- **Features**: `feature/description-of-feature`
- **Bug fixes**: `fix/description-of-bug-fix`
- **Documentation**: `docs/update-documentation`
- **Refactoring**: `refactor/improve-code-structure`

### Commit Message Format
Follow the conventional commit format:
```
<scope>: <description>

[optional body]

[optional footer]
```

Examples:
```
ui: add timeline card component with animations

feat: implement local AI provider support

fix: resolve screen recording permission handling

docs: update API documentation for new endpoints
```

### Pull Request Template
When creating a PR, include:

#### Description
- **Clear explanation** of what the change does
- **Why the change is needed**
- **How it was implemented**

#### Testing
- **How you tested** the change
- **Test coverage** added (if applicable)
- **Manual testing** performed

#### Screenshots
- **Before/after screenshots** for UI changes
- **Screen recordings** for animations or complex interactions

#### Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] Analytics events added (if user-facing feature)
- [ ] Performance impact considered
- [ ] Privacy implications reviewed

## Testing Requirements

### Unit Tests
- **All new business logic** must have unit tests
- **Test coverage** should not decrease
- **Mock external dependencies** (AI providers, file system)
- **Test edge cases** and error conditions

### Integration Tests
- **AI provider integration** must be tested
- **Screen recording pipeline** integration validation
- **Database operations** testing with GRDB
- **End-to-end workflows** for critical features

### UI Tests
- **Critical user flows** must have UI tests
- **Accessibility** testing for new components
- **Multi-display support** testing for recording features
- **Error state handling** in UI

### Performance Tests
- **Memory usage** validation for new features
- **CPU performance** testing for recording and AI processing
- **Database query** performance testing
- **Startup time** impact assessment

## Code Review Guidelines

### Reviewer Checklist
When reviewing a PR, check for:

#### Code Quality
- [ ] Code follows Swift style conventions
- [ ] Proper error handling implemented
- [ ] No hardcoded values or magic numbers
- [ ] Appropriate use of Swift language features
- [ ] Memory management considerations addressed

#### Architecture
- [ ] Follows MVVM pattern consistently
- [ ] Proper separation of concerns
- [ ] Dependencies injected appropriately
- [ ] No tight coupling between components
- [ ] Scalable and maintainable design

#### Security and Privacy
- [ ] No sensitive data logged or exposed
- [ ] Proper permission handling
- [ ] Secure API key management
- [ ] User privacy considerations addressed
- [ ] Data validation and sanitization

#### Performance
- [ ] No performance regressions
- [ ] Efficient algorithms and data structures
- [ ] Proper memory management
- [ ] Minimal CPU usage for background tasks
- [ ] Efficient database queries

#### Testing
- [ ] Adequate test coverage
- [ ] Tests for edge cases
- [ ] Integration testing where appropriate
- [ ] UI tests for user-facing changes
- [ ] Performance tests for critical paths

## Development Workflow

### Setting Up Development Environment
1. **Clone repository**: `git clone https://github.com/JerryZLiu/Dayflow.git`
2. **Open in Xcode**: `open Dayflow.xcodeproj`
3. **Configure signing**: Set your Apple Developer team
4. **Set up environment**: Add `GEMINI_API_KEY` if testing AI features
5. **Run tests**: Verify all tests pass before making changes

### Making Changes
1. **Create feature branch**: `git checkout -b feature/your-feature`
2. **Make changes** following style guidelines
3. **Add tests** for new functionality
4. **Run test suite**: `xcodebuild test -project Dayflow.xcodeproj -scheme Dayflow -destination 'platform=macOS'`
5. **Commit changes** with clear messages
6. **Push branch**: `git push origin feature/your-feature`
7. **Create PR** with detailed description

### Debugging Guidelines
- **Use structured logging** via `LLMLogger`
- **Enable debug mode** with environment variables
- **Test with different AI providers**
- **Verify screen recording permissions**
- **Check multi-display scenarios**

## Documentation Standards

### Code Documentation
- **Public APIs** must have documentation comments
- **Complex algorithms** should have explanatory comments
- **Configuration options** must be documented
- **Error conditions** should be clearly explained

### README Updates
- **New features** should be reflected in README
- **Configuration changes** must be documented
- **Dependencies** should be kept up to date
- **Installation instructions** must remain accurate

### Analytics Documentation
- **New user actions** must be added to `AnalyticsEventDictionary.md`
- **Event naming** should follow existing conventions
- **Event properties** should be well-documented
- **Privacy implications** should be considered

## Release Process

### Before Release
- **All tests must pass** on all supported macOS versions
- **Performance benchmarks** must meet requirements
- **Security review** completed for sensitive changes
- **Documentation updated** with new features
- **Changelog prepared** with user-facing changes

### Release Testing
- **Clean install** on fresh machine
- **Update installation** from previous version
- **Auto-update functionality** validation
- **Multi-version compatibility** testing

## Community Guidelines

### Communication
- **Be respectful** and constructive in all interactions
- **Provide clear feedback** with specific examples
- **Ask questions** when clarification is needed
- **Help others** when you have expertise

### Issue Reporting
- **Search existing issues** before creating new ones
- **Provide detailed reproduction steps**
- **Include system information** (macOS version, hardware)
- **Add relevant logs** and screenshots
- **Use appropriate labels** and templates

### Feature Requests
- **Check roadmap** for planned features
- **Provide use cases** and rationale
- **Consider implementation complexity**
- **Offer to contribute** if possible

## Security Considerations

### Data Privacy
- **Never commit API keys** or sensitive data
- **Use secure storage** for user credentials
- **Minimize data collection** to what's necessary
- **Provide transparency** about data usage

### Code Security
- **Validate all inputs** from external sources
- **Use secure coding practices**
- **Regular dependency updates** for security patches
- **Security review** for sensitive features

## Performance Guidelines

### Memory Management
- **Avoid memory leaks** with proper cleanup
- **Use weak references** where appropriate
- **Monitor memory usage** during development
- **Profile memory-intensive operations**

### CPU Usage
- **Maintain 1 FPS** for screen recording
- **Optimize AI processing** for efficiency
- **Use background queues** for heavy operations
- **Minimize main thread blocking**

### Storage Efficiency
- **Implement cleanup** for old recordings
- **Use efficient file formats**
- **Compress data where appropriate**
- **Monitor storage usage**

## Getting Help

### Resources
- **Xcode documentation** for Swift and SwiftUI
- **Apple Developer Forums** for platform-specific questions
- **GitHub Issues** for project-specific problems
- **Discord/Slack** (if available) for community support

### Mentoring
- **Experienced contributors** should help newcomers
- **Code reviews** should be educational
- **Best practices** should be shared
- **Constructive feedback** should be provided

## Recognition

### Contributions
- **All contributors** recognized in README
- **Significant contributions** highlighted in releases
- **Community impact** celebrated in project communications
- **Learning opportunities** shared with broader community

Thank you for contributing to FocusLock! Your contributions help make the project better for everyone.