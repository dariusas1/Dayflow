# State Management Analysis

## State Management Architecture

FocusLock uses a **hybrid state management approach** combining SwiftUI's native `@Published` properties with custom state management classes for complex scenarios.

### Core State Management Patterns

#### 1. SwiftUI Native State Management
**Primary mechanism** for most UI state:

```swift
@Published var isRecording: Bool
@StateObject private var categoryStore = CategoryStore()
@EnvironmentObject private var appState: AppState
```

**Usage:**
- Simple view-local state: `@State`
- Shared view state: `@StateObject` and `@EnvironmentObject`
- App-wide state: `AppState.shared` singleton

#### 2. Custom State Management Classes

**AppStateManager** - Loading and Navigation State
```swift
class AppStateManager: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var loadingMessage: String?
    @Published var activePage: String = "main"
    @Published var isContentReady: [String: Bool] = [:]
}
```

**Purpose:**
- Centralized loading state management
- Page transition coordination
- Content readiness tracking
- Auto-timeout handling for loading states

**AppState** - Application-Wide Recording State
```swift
@MainActor
final class AppState: ObservableObject, AppStateManaging {
    @Published var isRecording: Bool {
        didSet {
            if shouldPersist {
                UserDefaults.standard.set(isRecording, forKey: recordingKey)
            }
        }
    }
}
```

**Purpose:**
- Global recording state across the app
- Persistent preference storage
- Protocol-based architecture for testability

#### 3. State Management Utilities

**StateManagedView** Wrapper
```swift
struct StateManagedView<Content: View>: View {
    // Automatic loading state management for pages
    // Page readiness tracking
    // Transition coordination
}
```

**LoadingWrapper** Component
```swift
struct LoadingWrapper<Content: View>: View {
    // Reusable loading state handling
    // Animation coordination
    // Content reveal transitions
}
```

### State Flow Architecture

#### Recording State Flow
```
AppDelegate → AppState.shared → UI Components
     ↓              ↓                    ↓
Screen Capture → UserDefaults → @Published updates
```

#### Page Navigation Flow
```
User Action → AppStateManager → View Updates
     ↓              ↓                    ↓
Page Switch → Loading State → Content Ready
```

#### Data Persistence Flow
```
User Action → Local State → UserDefaults/Keychain
     ↓           ↓              ↓
Immediate UI → Persisted Value → App Restart Recovery
```

### State Synchronization Patterns

#### 1. MainActor Isolation
All state management classes are marked with `@MainActor`:
- Ensures UI updates on main thread
- Prevents race conditions
- SwiftUI compliance

#### 2. Protocol-Based Design
```swift
protocol AppStateManaging: ObservableObject {
    var isRecording: Bool { get }
    var objectWillChange: ObservableObjectPublisher { get }
}
```

**Benefits:**
- Testable architecture
- Dependency injection capability
- Clear contract definition

#### 3. Automatic Persistence
```swift
@Published var isRecording: Bool {
    didSet {
        if shouldPersist {
            UserDefaults.standard.set(isRecording, forKey: recordingKey)
        }
    }
}
```

**Features:**
- Immediate persistence on state change
- Conditional persistence (after onboarding)
- Automatic recovery on app launch

### Advanced State Management Features

#### 1. Page-Level State Coordination
```swift
func switchToPage(_ page: String) {
    activePage = page
    if !isContentReady[page, default: false] {
        setLoading(true, for: page, message: "Loading \(page)...")
    }
}
```

#### 2. Timeout-Based Loading States
```swift
// Auto-hide loading after reasonable time
if loading {
    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
        if self.isLoading {
            self.setLoading(false)
        }
    }
}
```

#### 3. Content Readiness Tracking
```swift
@Published var isContentReady: [String: Bool] = [:]

func setPageReady(_ page: String) {
    isContentReady[page] = true
    if activePage == page {
        isLoading = false
        loadingMessage = nil
    }
}
```

### State Management Best Practices Used

#### 1. Single Source of Truth
- `AppState.shared` for global recording state
- Individual `@StateObject` instances for page-specific state
- Clear separation of concerns

#### 2. Reactive Updates
- SwiftUI's automatic view updates on `@Published` changes
- Combine publishers for complex state relationships
- Environment object propagation

#### 3. Performance Optimization
- Minimal state updates (only when necessary)
- Conditional persistence to avoid unnecessary I/O
- Efficient state propagation through environment objects

#### 4. Error Handling
- Graceful loading state recovery
- Timeout handling for stuck states
- User feedback during state transitions

### Integration with SwiftUI Ecosystem

#### View Modifiers
```swift
.withLoadingState(isLoading, message: "Loading...")
.withPageState("dashboard")
```

#### Environment Objects
```swift
.environmentObject(AppState.shared)
.environmentObject(categoryStore)
.environmentObject(stateManager)
```

### State Persistence Strategy

#### UserDefaults (App Preferences)
- Recording state
- Onboarding completion
- Selected LLM provider
- User preferences

#### Keychain (Secure Data)
- API keys (Gemini, Dayflow backend)
- Authentication tokens
- Sensitive credentials

#### GRDB Database (Structured Data)
- Timeline cards and activities
- Recording batches
- Categories and user data
- Application state that needs querying

### State Management Testing Approach

#### Protocol Mocking
```swift
class MockAppState: AppStateManaging {
    @Published var isRecording: Bool = false
    // Test implementation
}
```

#### State Injection
- Environment object injection for testing
- Dependency injection for services
- Preview support with mock states

### Performance Considerations

#### Memory Management
- `@StateObject` for view lifecycle management
- Automatic cleanup on view dismissal
- Efficient state propagation

#### CPU Optimization
- Minimal state change notifications
- Conditional UI updates
- Debounced state changes where appropriate

### Scalability Patterns

#### Modular State Design
- Separate managers for different concerns
- Clear boundaries between state types
- Composable state management

#### Future Extensibility
- Protocol-based architecture allows new state managers
- Plugin-style state management possible
- Testable and maintainable structure