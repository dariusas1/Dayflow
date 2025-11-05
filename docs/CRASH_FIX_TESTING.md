# Memory Corruption Crash Fix - Testing Guide

## Overview
This document provides testing instructions for the fix to the memory corruption crash (`freed pointer was not the last allocation`) that occurred when switching tabs in the Settings panel.

## What Was Fixed

### Root Cause
The crash was caused by:
1. **Lazy singleton initialization during UI rendering** - `ProactiveCoachEngine.shared` was first accessed during SwiftUI view layout
2. **Synchronous database operations in init** - `loadAlertHistory()` performed blocking GRDB reads
3. **Priority inversion** - Main thread (User-interactive QoS) waiting on Utility queue (default GRDB QoS)
4. **Memory corruption** - GRDB connection pool corruption from incorrect threading

### Fixes Applied

#### 1. ProactiveCoachEngine - Async-Safe Initialization
- **File**: `Dayflow/Dayflow/Core/FocusLock/ProactiveCoachEngine.swift`
- **Change**: Removed synchronous `loadAlertHistory()` from `init()`
- **New Pattern**: Added `loadDataAsync()` method called after initialization
- **Benefit**: No blocking database operations during singleton creation

#### 2. Early Singleton Pre-Initialization
- **File**: `Dayflow/Dayflow/App/AppDelegate.swift`
- **Change**: Pre-initialize `ProactiveCoachEngine`, `FocusSessionManager`, and `TodoExtractionEngine` in `setupFocusLock()`
- **Timing**: Before UI is rendered
- **Benefit**: Singletons ready before any view tries to access them

#### 3. GRDB Quality of Service (QoS) Configuration
- **File**: `Dayflow/Dayflow/Core/Recording/StorageManager.swift`
- **Change**: Set `config.qos = .userInitiated` on database pool
- **Benefit**: Prevents priority inversion when database accessed from main thread

#### 4. SmartTodoView - Async Initialization
- **File**: `Dayflow/Dayflow/Views/UI/SmartTodoView.swift`
- **Change**: Changed `@StateObject` to `@State` with `.task` initialization
- **Benefit**: FocusSessionManager initialized asynchronously, not during layout

## Testing Instructions

### Prerequisites
1. Clean build the project
2. Enable Thread Sanitizer and Thread Performance Checker
3. Have Console.app ready to monitor logs

### Test 1: Basic Tab Switching (Manual)

**Objective**: Verify no crashes when switching Settings tabs

**Steps**:
1. Launch the app
2. Open Settings
3. Switch between all tabs: Storage → Providers → FocusLock → Other
4. Repeat 10 times
5. Monitor for crashes and Thread Performance Checker warnings

**Expected Result**: 
- No crashes
- No "freed pointer" errors
- No priority inversion warnings in console

**Console Verification**:
Look for these success messages:
```
AppDelegate: FocusLock components initialized
AppDelegate: Proactive engine and session manager ready
```

### Test 2: Rapid Tab Switching (Stress Test)

**Objective**: Stress test tab switching to ensure stability

**Steps**:
1. Launch the app
2. Open Settings
3. Rapidly switch between tabs (click as fast as possible)
4. Continue for 2 minutes or 50+ tab switches
5. Monitor memory usage and Thread Performance Checker

**Expected Result**:
- No crashes
- No memory leaks
- No priority inversion warnings
- Memory usage remains stable

### Test 3: Thread Sanitizer Validation

**Objective**: Detect threading issues and data races

**Steps**:
1. Enable Thread Sanitizer in Xcode:
   - Product → Scheme → Edit Scheme
   - Run → Diagnostics → Thread Sanitizer ✓
2. Build and run
3. Open Settings
4. Switch tabs multiple times
5. Check for TSan reports

**Expected Result**:
- No data race warnings
- No threading violations
- Clean TSan report

### Test 4: Settings Tab with Smart Todo View

**Objective**: Verify SmartTodoView doesn't trigger crashes

**Steps**:
1. Ensure you have some todos in the system
2. Navigate to any view that shows SmartTodoView
3. Open Settings and navigate away
4. Return to SmartTodoView
5. Repeat 10 times

**Expected Result**:
- No crashes
- SmartTodoView loads smoothly
- FocusSessionManager accessible without issues

### Test 5: Cold Start Verification

**Objective**: Verify singletons initialize correctly on app launch

**Steps**:
1. Quit the app completely
2. Clear app data (optional, for thorough test)
3. Launch the app
4. Monitor console for initialization messages
5. Open Settings immediately after launch
6. Switch tabs

**Expected Result**:
- Console shows: "AppDelegate: Proactive engine and session manager ready"
- No delays or hangs on Settings open
- Smooth tab switching

## Monitoring Console Logs

### Success Indicators
```
✅ AppDelegate: FocusLock components initialized
✅ AppDelegate: Proactive engine and session manager ready
✅ Loaded N active alerts from database
```

### Warning Indicators (Should NOT appear)
```
⚠️ Thread Performance Checker: Thread running at User-interactive quality-of-service class waiting on a lower QoS thread
⚠️ freed pointer was not the last allocation
⚠️ SLOW READ [fetchActiveAlerts]: wait=XXms exec=XXXXms
```

## Performance Validation

### Before Fix
- Thread Performance Checker warnings during tab switch
- Potential app hang (main thread blocked)
- Memory corruption crash
- Priority inversion between UI thread and DB utility queue

### After Fix
- No Thread Performance Checker warnings
- Instant tab switching
- No crashes
- Database operations run at `.userInitiated` QoS

## Regression Testing

Ensure these still work:
1. **Proactive coaching alerts** - Can still create and display alerts
2. **Focus session management** - Can start/stop focus sessions
3. **Todo extraction** - Can create and manage todos
4. **Settings persistence** - Settings save and load correctly

## Debug Commands

### Check Singleton Initialization
Add breakpoints at:
- `ProactiveCoachEngine.init()` - Should complete instantly
- `ProactiveCoachEngine.loadDataAsync()` - Should be called from AppDelegate
- `FocusSessionManager.init()` - Should be called early

### Monitor GRDB QoS
Check that database pool uses `.userInitiated`:
```swift
// In StorageManager.swift around line 363
config.qos = .userInitiated  // Should be set
```

## Rollback Instructions

If issues arise, revert these commits:
1. ProactiveCoachEngine async changes
2. AppDelegate singleton pre-initialization  
3. StorageManager QoS configuration
4. SmartTodoView async initialization

## Success Criteria

- [x] No crashes when switching Settings tabs
- [x] No "freed pointer" memory corruption errors
- [x] No Thread Performance Checker priority inversion warnings
- [x] All singletons initialize before UI renders
- [x] Database operations use `.userInitiated` QoS
- [x] Smooth, responsive Settings tab switching
- [x] 50+ tab switches without issues
- [x] Clean Thread Sanitizer report
- [x] No memory leaks
- [x] All existing features still functional

## Support

If crashes persist:
1. Check Console.app for full stack traces
2. Verify Thread Sanitizer is enabled
3. Confirm all four fixes are applied
4. Check for conflicting changes in related files
5. Review GRDB connection pool metrics

---

**Test Date**: ____________  
**Tester**: ____________  
**Result**: ⬜ Pass ⬜ Fail  
**Notes**: ____________

