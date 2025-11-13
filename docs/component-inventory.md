# Component Inventory - FocusLock

## UI Component Library

### Layout Components

#### MainContentContainer
- **Purpose**: Root container for main application views
- **Location**: `Views/Components/MainContentContainer.swift`
- **Usage**: Provides consistent layout structure across the app
- **Features**: Safe area handling, responsive design
- **Dependencies**: SwiftUI native components

#### PageTransitionManager
- **Purpose**: Manages page transitions and animations
- **Location**: `Views/Components/PageTransitionManager.swift`
- **Usage**: Smooth transitions between different app sections
- **Features**: Custom animations, state management
- **Dependencies**: SwiftUI animation system

### Button Components

#### DayflowButton
- **Purpose**: Primary button component with consistent styling
- **Location**: `Views/Components/DayflowButton.swift`
- **Usage**: Main action buttons throughout the application
- **Features**: Custom styling, hover effects, accessibility support
- **Variants**: Primary, secondary, destructive styles

#### DayflowCircleButton
- **Purpose**: Circular button for special actions
- **Location**: `Views/Components/DayflowCircleButton.swift`
- **Usage**: Recording controls, quick actions
- **Features**: Circular design, icon support, press animations
- **Size**: Fixed circular dimensions

#### DayflowPillButton
- **Purpose**: Pill-shaped button for toggle/select actions
- **Location**: `Views/Components/DayflowPillButton.swift`
- **Usage**: Filter buttons, category selection
- **Features**: Pill shape, selected state, smooth transitions
- **Styling**: Modern pill design with rounded corners

#### DayflowSurfaceButton
- **Purpose**: Surface-level button with depth effects
- **Location**: `Views/Components/DayflowSurfaceButton.swift`
- **Usage**: Secondary actions, menu items
- **Features**: Surface design, subtle shadows, depth perception
- **Integration**: Matches app's surface design language

#### UnifiedButton
- **Purpose**: Unified button component consolidating all button types
- **Location**: `Views/Components/UnifiedButton.swift`
- **Usage**: Standardized button interface across the app
- **Features**: Multiple styles, consistent API, accessibility
- **Variants**: Primary, secondary, pill, circle, surface

### Card Components

#### UnifiedCard
- **Purpose**: Standardized card container for content
- **Location**: `Views/Components/UnifiedCard.swift`
- **Usage**: Timeline cards, settings cards, content containers
- **Features**: Consistent styling, shadows, corner radius
- **Customization**: Configurable padding, background, borders

#### LargeOrangeCard
- **Purpose**: Prominent card for important content
- **Location**: `Views/Components/LargeOrangeCard.imageset/`
- **Usage**: Feature highlights, important information
- **Features**: Large size, orange accent, high visibility
- **Assets**: Custom background image and styling

### Input Components

#### UnifiedTextField
- **Purpose**: Standardized text input field
- **Location**: `Views/Components/UnifiedTextField.swift`
- **Usage**: API key input, settings fields, user input
- **Features**: Consistent styling, validation, focus states
- **Validation**: Built-in validation support, error states

### Display Components

#### LoadingState
- **Purpose**: Loading indicator and state management
- **Location**: `Views/Components/LoadingState.swift`
- **Usage**: Async operations, data loading, processing states
- **Features**: Multiple loading styles, progress indication
- **States**: Loading, success, error, empty

#### LogoBadgeView
- **Purpose**: Application logo display component
- **Location**: `Views/Components/LogoBadgeView.swift`
- **Usage**: App branding, onboarding, about section
- **Features**: Scalable logo, badge integration
- **Assets**: Uses app logo assets

#### VideoThumbnailView
- **Purpose**: Video thumbnail display and management
- **Location**: `Views/UI/VideoThumbnailView.swift`
- **Usage**: Timeline thumbnails, video previews
- **Features**: Thumbnail generation, caching, playback
- **Integration**: Works with video recording system

#### WhiteBGVideoPlayer
- **Purpose**: Video player with white background
- **Location**: `Views/UI/WhiteBGVideoPlayer.swift`
- **Usage**: Video playback in timeline, modal views
- **Features**: Clean background, controls, accessibility
- **Performance**: Optimized for memory usage

### Container Components

#### GlassmorphismContainer
- **Purpose**: Glass effect container for modern UI
- **Location**: `Views/Components/GlassmorphismContainer.swift`
- **Usage**: Modal backgrounds, overlay containers
- **Features**: Blur effects, transparency, modern design
- **Performance**: Hardware-accelerated blur effects

#### FlowingGradientBackground
- **Purpose**: Animated gradient background
- **Location**: `Views/Components/FlowingGradientBackground.swift`
- **Usage**: Onboarding backgrounds, visual effects
- **Features**: Animated gradients, smooth transitions
- **Performance**: Optimized animation performance

### Utility Components

#### CursorModifiers
- **Purpose**: Cursor appearance and behavior modifiers
- **Location**: `Views/Components/CursorModifiers.swift`
- **Usage**: Custom cursor styles, hover states
- **Features**: Cursor customization, system integration
- **Accessibility**: Respect system cursor preferences

#### DesignTokens
- **Purpose**: Design system tokens and constants
- **Location**: `Views/Components/DesignTokens.swift`
- **Usage**: Consistent styling across components
- **Features**: Colors, spacing, typography, shadows
- **Maintenance**: Centralized design system management

#### StateManager
- **Purpose**: Global state management coordinator
- **Location**: `Views/Components/StateManager.swift`
- **Usage**: Application-wide state coordination
- **Features**: State persistence, reactive updates
- **Integration**: Works with SwiftUI state system

#### SunriseGlassPillToggleStyle
- **Purpose**: Custom toggle style for pill-shaped toggles
- **Location**: `Views/UI/SunriseGlassPillToggleStyle.swift`
- **Usage**: Settings toggles, preference switches
- **Features**: Glass effect, pill shape, smooth animations
- **Design**: Matches app's visual design language

#### WindowSizeReader
- **Purpose**: Window size detection and adaptation
- **Location**: `Views/UI/WindowSizeReader.swift`
- **Usage**: Responsive design, layout adaptation
- **Features**: Size detection, breakpoint management
- **Integration**: SwiftUI size reader integration

## Onboarding Components

### Onboarding Flow

#### OnboardingFlow
- **Purpose**: Main onboarding flow coordinator
- **Location**: `Views/Onboarding/OnboardingFlow.swift`
- **Usage**: First-run user experience
- **Features**: Step management, progress tracking
- **Integration**: Coordinates all onboarding components

#### FocusLockOnboardingFlow
- **Purpose**: FocusLock-specific onboarding experience
- **Location**: `Views/Onboarding/FocusLockOnboardingFlow.swift`
- **Usage**: Brand-specific onboarding flow
- **Features**: Custom branding, feature introduction
- **Content**: FocusLock feature explanations

### Setup Components

#### SetupContinueButton
- **Purpose**: Continue button for onboarding steps
- **Location**: `Views/Onboarding/SetupContinueButton.swift`
- **Usage**: Navigation between onboarding steps
- **Features**: Consistent styling, validation checking
- **State**: Enabled/disabled based on step completion

#### SetupSidebarView
- **Purpose**: Sidebar for onboarding navigation
- **Location**: `Views/Onboarding/SetupSidebarView.swift`
- **Usage**: Onboarding step navigation and progress
- **Features**: Step indicators, progress tracking
- **Design**: Clean sidebar layout with progress

### Permission Components

#### ScreenRecordingPermissionView
- **Purpose**: Screen recording permission request
- **Location**: `Views/Onboarding/ScreenRecordingPermissionView.swift`
- **Usage**: macOS screen recording permission setup
- **Features**: Permission explanation, system settings link
- **Integration**: macOS permission system

#### PermissionExplanationDialog
- **Purpose**: General permission explanation dialog
- **Location**: `Views/Onboarding/PermissionExplanationDialog.swift`
- **Usage**: Explain why permissions are needed
- **Features**: Clear explanations, privacy reassurance
- **Trust**: Build user trust through transparency

### Provider Setup

#### LLMProviderSetupView
- **Purpose**: AI provider configuration interface
- **Location**: `Views/Onboarding/LLMProviderSetupView.swift`
- **Usage**: Setup Gemini, Ollama, or LM Studio
- **Features**: Provider selection, configuration forms
- **Validation**: Connection testing and validation

#### OnboardingLLMSelectionView
- **Purpose**: LLM provider selection during onboarding
- **Location**: `Views/Onboarding/OnboardingLLMSelectionView.swift`
- **Usage**: Choose AI provider for processing
- **Features**: Provider comparison, selection guidance
- **Information**: Provider capabilities and requirements

#### APIKeyInputView
- **Purpose**: API key input for cloud providers
- **Location**: `Views/Onboarding/APIKeyInputView.swift`
- **Usage**: Gemini API key configuration
- **Features**: Secure input, validation, testing
- **Security**: Secure key handling and storage

#### TestConnectionView
- **Purpose**: Test AI provider connection
- **Location**: `Views/Onboarding/TestConnectionView.swift`
- **Usage**: Validate AI provider configuration
- **Features**: Connection testing, error reporting
- **Feedback**: Clear success/failure indication

### Content Components

#### HowItWorksView
- **Purpose**: How-it-works explanation
- **Location**: `Views/Onboarding/HowItWorksView.swift`
- **Usage**: Explain app functionality to users
- **Features**: Step-by-step explanation, visuals
- **Simplicity**: Clear, non-technical language

#### HowItWorksCard
- **Purpose**: Individual explanation card
- **Location**: `Views/Onboarding/HowItWorksCard.swift`
- **Usage**: Feature explanation cards
- **Features**: Consistent card design, icon support
- **Content**: Feature-specific explanations

#### FeatureOnboardingView
- **Purpose**: Feature-specific onboarding
- **Location**: `Views/Onboarding/FeatureOnboardingView.swift`
- **Usage**: Introduce specific features
- **Features**: Interactive demonstrations, highlights
- **Engagement**: Interactive feature exploration

#### PrivacyConsentView
- **Purpose**: Privacy policy consent
- **Location**: `Views/Onboarding/PrivacyConsentView.swift`
- **Usage**: Privacy policy agreement
- **Features**: Policy display, consent tracking
- **Compliance**: Privacy regulation compliance

#### VideoLaunchView
- **Purpose**: Launch video display
- **Location**: `Views/Onboarding/VideoLaunchView.swift`
- **Usage**: Show launch video during onboarding
- **Features**: Video playback, auto-advance
- **Assets**: Launch video integration

#### TerminalCommandView
- **Purpose**: Terminal command display
- **Location**: `Views/Onboarding/TerminalCommandView.swift`
- **Usage**: Show terminal commands for setup
- **Features**: Command display, copy functionality
- **Developer**: Developer-focused setup instructions

## Main Application Views

### Timeline Views

#### TimelineView
- **Purpose**: Main timeline display
- **Location**: `Views/UI/TimelineView.swift`
- **Usage**: Display daily activity timeline
- **Features**: Timeline cards, scrubbing, navigation
- **Integration**: Core timeline functionality

#### ScrubberView
- **Purpose**: Timeline scrubbing interface
- **Location**: `Views/UI/ScrubberView.swift`
- **Usage**: Navigate through timeline
- **Features**: Time scrubbing, preview, jump navigation
- **Performance**: Smooth scrubbing with large datasets

#### TimelineDataModels
- **Purpose**: Timeline data structures
- **Location**: `Views/UI/TimelineDataModels.swift`
- **Usage**: Data models for timeline display
- **Features**: Card models, filtering, sorting
- **Integration**: Database integration

### Dashboard Views

#### DashboardView
- **Purpose**: Main dashboard interface
- **Location**: `Views/UI/DashboardView.swift`
- **Usage**: Analytics and insights dashboard
- **Features**: Charts, metrics, customizable widgets
- **Customization**: User-configurable dashboard

#### DashboardCustomizationView
- **Purpose**: Dashboard customization interface
- **Location**: `Views/UI/DashboardCustomizationView.swift`
- **Usage**: Configure dashboard layout
- **Features**: Widget arrangement, metric selection
- **Personalization**: User preference storage

#### ProductivityCharts
- **Purpose**: Productivity visualization
- **Location**: `Views/UI/ProductivityCharts.swift`
- **Usage**: Display productivity metrics
- **Features**: Charts, trends, comparisons
- **Data**: Timeline data visualization

#### InsightsView
- **Purpose**: Insights and analysis display
- **Location**: `Views/UI/InsightsView.swift`
- **Usage**: Show AI-generated insights
- **Features**: Pattern recognition, recommendations
- **AI Integration**: Processed timeline insights

### Journal Views

#### JournalView
- **Purpose**: Main journal interface
- **Location**: `Views/UI/JournalView.swift`
- **Usage**: Daily journal and reflection
- **Features**: Journal entries, timeline integration
- **Reflection**: Guided reflection prompts

#### EnhancedJournalView
- **Purpose**: Enhanced journal with features
- **Location**: `Views/UI/EnhancedJournalView.swift`
- **Usage**: Advanced journal functionality
- **Features**: Rich content, media support, templates
- **Integration**: Timeline and AI integration

#### JournalTemplateView
- **Purpose**: Journal template selection
- **Location**: `Views/UI/JournalTemplateView.swift`
- **Usage**: Choose journal templates
- **Features**: Template library, custom templates
- **Personalization**: User-specific templates

#### JournalSectionEditor
- **Purpose**: Edit journal sections
- **Location**: `Views/UI/JournalSectionEditor.swift`
- **Usage**: Edit specific journal sections
- **Features**: Rich text editing, media insertion
- **Formatting**: Text formatting and styling

#### JournalSupportingViews
- **Purpose**: Supporting journal components
- **Location**: `Views/UI/JournalSupportingViews.swift`
- **Usage**: Helper views for journal functionality
- **Features**: Utility components, helpers
- **Modularity**: Reusable journal components

#### JournalExportView
- **Purpose**: Export journal functionality
- **Location**: `Views/UI/JournalExportView.swift`
- **Usage**: Export journal data
- **Features**: Multiple formats, date ranges, filtering
- **Formats**: PDF, Markdown, JSON export

#### JournalPreferencesView
- **Purpose**: Journal preference settings
- **Location**: `Views/UI/JournalPreferencesView.swift`
- **Usage**: Configure journal behavior
- **Features**: Settings, preferences, defaults
- **Storage**: Preference persistence

### Focus and Productivity Views

#### FocusLockView
- **Purpose**: Main focus session interface
- **Location**: `Views/UI/FocusLockView.swift`
- **Usage**: Focus session management
- **Features**: Session control, break reminders
- **Productivity**: Focus time tracking

#### EnhancedFocusLockView
- **Purpose**: Enhanced focus session interface
- **Location**: `Views/UI/EnhancedFocusLockView.swift`
- **Usage**: Advanced focus session features
- **Features**: Custom sessions, analytics, integration
- **Enhancement**: Extended focus functionality

#### FocusSessionWidget
- **Purpose**: Focus session widget
- **Location**: `Views/UI/FocusSessionWidget.swift`
- **Usage**: Quick focus session access
- **Features**: Widget interface, quick controls
- **Integration**: System integration

#### EmergencyBreakView
- **Purpose**: Emergency break interface
- **Location**: `Views/UI/EmergencyBreakView.swift`
- **Usage**: Emergency break functionality
- **Features**: Immediate break, override options
- **Wellness**: Digital wellness features

#### NuclearModeSetupView
- **Purpose**: Nuclear mode configuration
- **Location**: `Views/UI/NuclearModeSetupView.swift`
- **Usage**: Configure nuclear focus mode
- **Features**: Extreme focus mode, restrictions
- **Control**: App and website blocking

### Planning and Todo Views

#### PlannerView
- **Purpose**: Planning interface
- **Location**: `Views/UI/PlannerView.swift`
- **Usage**: Daily and weekly planning
- **Features**: Task planning, timeline integration
- **Organization**: Planning tools and organization

#### SmartTodoView
- **Purpose**: Smart todo management
- **Location**: `Views/UI/SmartTodoView.swift`
- **Usage**: AI-powered todo suggestions
- **Features**: Smart suggestions, prioritization
- **AI Integration**: AI-generated todo items

#### SuggestedTodosView
- **Purpose**: Suggested todos display
- **Location**: `Views/UI/SuggestedTodosView.swift`
- **Usage**: Show AI-suggested todos
- **Features**: Timeline-based suggestions
- **Context**: Context-aware recommendations

### Settings and Configuration Views

#### SettingsView
- **Purpose**: Main settings interface
- **Location**: `Views/UI/SettingsView.swift`
- **Usage**: Application configuration
- **Features**: Comprehensive settings management
- **Organization**: Categorized settings sections

#### FeatureFlagsSettingsView
- **Purpose**: Feature flags configuration
- **Location**: `Views/UI/FeatureFlagsSettingsView.swift`
- **Usage**: Enable/disable experimental features
- **Features**: Feature toggles, A/B testing
- **Development**: Feature development support

#### BedtimeSettingsView
- **Purpose**: Bedtime and sleep settings
- **Location**: `Views/UI/BedtimeSettingsView.swift`
- **Usage**: Configure bedtime reminders
- **Features**: Sleep tracking, bedtime routines
- **Wellness**: Sleep hygiene features

#### CategoryEditorView
- **Purpose**: Category management
- **Location**: `Views/UI/CategoryEditorView.swift`
- **Usage**: Edit activity categories
- **Features**: Category creation, editing, deletion
- **Organization**: Activity categorization

### AI and Chat Views

#### JarvisChatView
- **Purpose**: AI chat interface
- **Location**: `Views/UI/JarvisChatView.swift`
- **Usage**: AI assistant chat
- **Features**: Conversational AI, context awareness
- **Integration**: Timeline-aware AI assistance

### Modal and Dialog Views

#### VideoPlayerModal
- **Purpose**: Video player modal
- **Location**: `Views/UI/VideoPlayerModal.swift`
- **Usage**: Modal video playback
- **Features**: Full-screen video, controls
- **Integration**: Timeline video playback

#### BugReportView
- **Purpose**: Bug reporting interface
- **Location**: `Views/UI/BugReportView.swift`
- **Usage**: Report bugs and issues
- **Features**: Bug form, attachments, logs
- **Support**: User support integration

#### WhatsNewView
- **Purpose**: What's new display
- **Location**: `Views/UI/WhatsNewView.swift`
- **Usage**: Show app updates and features
- **Features**: Update highlights, feature announcements
- **Engagement**: User engagement with new features

### Main View

#### MainView
- **Purpose**: Main application view
- **Location**: `Views/UI/MainView.swift`
- **Usage**: Root view container
- **Features**: Navigation, state management
- **Integration**: Coordinates all main views

## Component Design System

### Design Principles
1. **Consistency**: Unified visual language across all components
2. **Accessibility**: Full accessibility support and keyboard navigation
3. **Performance**: Optimized for memory and CPU usage
4. **Modularity**: Reusable, composable component design
5. **Responsiveness**: Adaptive to different screen sizes and resolutions

### Color Scheme
- **Primary**: Orange accent colors for important actions
- **Secondary**: Grays and whites for content
- **Surface**: Glass effects with transparency
- **Interactive**: Hover and active states with smooth transitions

### Typography
- **Primary**: Figtree font family for modern, clean appearance
- **Secondary**: Nunito for friendly, approachable text
- **Display**: Instrument Serif for headings and special text
- **Consistency**: Consistent sizing and spacing throughout

### Animation and Transitions
- **Micro-interactions**: Subtle hover effects and state changes
- **Page Transitions**: Smooth animations between views
- **Loading States**: Engaging loading animations
- **Performance**: Hardware-accelerated animations for smoothness

This component inventory provides a comprehensive overview of FocusLock's UI component library, showcasing the modular, reusable design approach that enables consistent user experience across the application.