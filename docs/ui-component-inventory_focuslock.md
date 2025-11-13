# UI Component Inventory - FocusLock

## Overview

FocusLock features a comprehensive design system with reusable UI components built on SwiftUI. The component library emphasizes consistency, accessibility, and a cohesive visual design with an orange-to-white gradient theme.

## Component Architecture

### Design System Foundation

#### DesignTokens.swift
**Purpose**: Central design system with unified tokens
**Categories**:
- **Colors**: Orange-themed palette with gradients
- **Typography**: Font families, sizes, and weights
- **Spacing**: Consistent spacing scale
- **Shadows**: Elevation and depth system
- **Animation**: Standardized timing and easing
- **Accessibility**: Touch targets and sizing standards

**Key Features**:
- Orange-to-white gradient theme
- Consistent spacing scale (4px to 48px)
- Typography hierarchy with custom fonts
- Shadow system for elevation
- Animation timing standards

## Core UI Components

### Button Components

#### 1. UnifiedButton
**Purpose**: Primary button component with multiple styles
**Variants**:
- Primary (orange gradient)
- Secondary (outlined)
- Tertiary (text-only)
- Custom styling support

**Features**:
- Consistent sizing and spacing
- Hover and press states
- Accessibility support
- Loading state integration

#### 2. DayflowButton
**Purpose**: Brand-specific button variant
**Characteristics**:
- Custom styling for Dayflow brand
- Gradient backgrounds
- Custom animations

#### 3. DayflowCircleButton
**Purpose**: Circular action buttons
**Use Cases**:
- Floating action buttons
- Icon-based actions
- Compact controls

#### 4. DayflowPillButton
**Purpose**: Pill-shaped buttons for tags and filters
**Features**:
- Rounded corners (999px radius)
- Compact sizing
- Category selection

#### 5. DayflowSurfaceButton
**Purpose**: Buttons with surface elevation
**Characteristics**:
- Shadow effects
- Elevated appearance
- Interactive feedback

### Container Components

#### 1. UnifiedCard
**Purpose**: Standardized card container
**Styles**:
- Standard (white background)
- Glass (translucent)
- Elevated (shadow)
- Custom styling

**Features**:
- Consistent padding and spacing
- Shadow system integration
- Corner radius standards
- Background variations

#### 2. GlassmorphismContainer
**Purpose**: Glass-morphism effect containers
**Characteristics**:
- Translucent backgrounds
- Blur effects
- Modern glass aesthetic
- Layer depth simulation

#### 3. MainContentContainer
**Purpose**: Main content area wrapper
**Features**:
- Responsive layout
- Consistent padding
- Maximum width constraints
- Centered content

### Input Components

#### 1. UnifiedTextField
**Purpose**: Standardized text input
**Features**:
- Consistent styling
- Validation states
- Placeholder text
- Accessibility support

### Layout Components

#### 1. UnifiedSectionHeader
**Purpose**: Section title and organization
**Features**:
- Typography hierarchy
- Consistent spacing
- Divider support
- Custom styling

#### 2. PageTransitionManager
**Purpose**: Page transition animations
**Features**:
- Smooth page transitions
- Loading state integration
- Animation coordination
- State management

### Visual Components

#### 1. FlowingGradientBackground
**Purpose**: Animated gradient backgrounds
**Characteristics**:
- Orange-to-white gradients
- Animation support
- Performance optimized
- Theme consistency

#### 2. TimelineCardColorPicker
**Purpose**: Color selection for timeline cards
**Features**:
- Color palette integration
- Visual feedback
- Selection state
- Accessibility support

#### 3. LogoBadgeView
**Purpose**: Brand logo display
**Features**:
- Multiple sizes
- Consistent branding
- Theme integration

### Utility Components

#### 1. LoadingState
**Purpose**: Loading indicator component
**Variants**:
- Dots animation
- Spinner
- Progress indicators
- Custom messages

#### 2. StateManager
**Purpose**: State management utilities
**Features**:
- Loading state coordination
- Page transition management
- Content readiness tracking

#### 3. CursorModifiers
**Purpose**: Cursor interaction feedback
**Features**:
- Hover states
- Click feedback
- Custom cursors
- Accessibility support

#### 4. SplashWindow
**Purpose**: Application splash screen
**Features**:
- Launch animation
- Brand presentation
- Loading coordination

## Component Categories

### Interactive Elements
- **Buttons**: 5 variants (Unified, Dayflow, Circle, Pill, Surface)
- **Inputs**: Text fields with validation
- **Controls**: Toggle switches, sliders

### Container Elements
- **Cards**: Standard, glass, elevated variants
- **Containers**: Content wrappers, sections
- **Surfaces**: Glass-morphism effects

### Navigation Elements
- **Headers**: Section organization
- **Transitions**: Page animations
- **State**: Loading and ready states

### Visual Elements
- **Backgrounds**: Gradients, animated effects
- **Branding**: Logo, badges
- **Feedback**: Loading, cursors, interactions

## Design System Integration

### Color System
- **Primary**: Orange gradient theme
- **Secondary**: White and light tones
- **Status**: Success, error, warning colors
- **Interactive**: Hover, selected, pressed states

### Typography System
- **Display**: Instrument Serif for headings
- **Body**: Nunito for content
- **System**: San Francisco fallback
- **Hierarchy**: 12-step size scale

### Spacing System
- **Scale**: 4px base unit
- **Range**: 4px (xs) to 48px (xxl)
- **Components**: Specific padding and margins
- **Layout**: Container and content spacing

### Animation System
- **Timing**: Quick (0.2s) to very slow (0.8s)
- **Easing**: Spring animations for natural feel
- **Types**: Press, hover, reveal, stagger
- **Performance**: Optimized for smooth 60fps

## Accessibility Features

### Touch Targets
- **Minimum**: 44px touch targets
- **Preferred**: 56px button height
- **Standard**: 48px standard buttons
- **Compact**: 40px compact buttons

### Visual Accessibility
- **Contrast**: Proper color contrast ratios
- **Typography**: Clear hierarchy and sizing
- **States**: Clear focus and selection indicators
- **Feedback**: Visual and interaction feedback

## Component Usage Patterns

### Consistent Styling
- All components use design tokens
- Consistent spacing and sizing
- Unified color application
- Standardized interactions

### Reusable Architecture
- Component composition patterns
- Style variant support
- Customization capabilities
- Theme integration

### Performance Optimization
- Efficient view updates
- Minimal redraw cycles
- Optimized animations
- Memory-conscious design

## Development Guidelines

### Component Creation
1. Use design tokens for all styling
2. Follow naming conventions (Unified*, Dayflow*)
3. Implement accessibility features
4. Add preview support
5. Document usage patterns

### Style Variants
- Primary, secondary, tertiary hierarchy
- Consistent state management
- Unified interaction patterns
- Theme integration support

### Testing Support
- Preview integration
- State management testing
- Accessibility validation
- Performance monitoring

## Asset Integration

### Image Assets
- **Icons**: Dashboard, Journal, Timeline
- **Illustrations**: Onboarding graphics
- **UI Elements**: Buttons, cards, backgrounds
- **Brand**: Logo variations

### Animation Assets
- **DayflowAnimation**: App introduction
- **Loading**: Custom loading animations
- **Transitions**: Page transition effects

## Summary

FocusLock's UI component library provides:

- **Comprehensive Coverage**: All common UI patterns
- **Design System**: Unified tokens and guidelines
- **Accessibility**: WCAG-compliant components
- **Performance**: Optimized for smooth interactions
- **Maintainability**: Clear architecture and patterns
- **Brand Consistency**: Cohesive visual identity

The component system enables rapid development while maintaining design consistency and accessibility standards across the application.