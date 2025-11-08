# Technical Debt Tracker

This document tracks known technical debt items that should be addressed post-beta release.

## Priority 1: Critical Refactoring

### Duplicate Session Managers

**Issue**: Two session managers exist with overlapping functionality but different models:
- `SessionManager.swift` - Modern, full-featured (PRIMARY)
- `FocusSessionManager.swift` - Legacy, simplified (DEPRECATED)

**Impact**:
- Code confusion for new developers
- Maintenance burden (must update both)
- Inconsistent data models (FocusSession vs LegacyFocusSession)
- Duplicated session history storage

**Current State (Beta)**:
- Both managers are functional and documented
- SessionManager is used by 15+ components
- FocusSessionManager only used by FocusSessionWidget
- Clear deprecation notices added
- No runtime conflicts

**Post-Beta Migration Plan** (Estimated: 2-3 days):

1. **Analysis Phase** (2 hours):
   - Audit FocusSessionWidget dependencies on FocusSessionManager
   - Identify which LegacyFocusSession properties are essential
   - Map LegacyFocusSession → FocusSession conversion

2. **SessionManager Enhancement** (4 hours):
   - Add Anchor/Triage/Break mode support to SessionManager if needed
   - Ensure FocusSession model can represent all legacy session types
   - Add migration helper: `convertLegacySession()` method

3. **FocusSessionWidget Refactor** (6 hours):
   - Replace `FocusSessionManager.shared` with `SessionManager.shared`
   - Update UI to use FocusSession model instead of LegacyFocusSession
   - Test all session start/end/pause/resume flows
   - Ensure dashboard widget renders correctly

4. **Data Migration** (3 hours):
   - Migrate existing UserDefaults session history to database
   - Convert all LegacyFocusSession records to FocusSession format
   - Verify session statistics calculations still work

5. **Cleanup** (2 hours):
   - Remove FocusSessionManager.swift
   - Remove LegacyFocusSession from FocusLockModels.swift
   - Remove `startLegacyFocusSession()` and `endLegacyFocusSession()` from ProactiveCoachEngine
   - Update AppDelegate initialization
   - Run full regression tests

6. **Verification** (3 hours):
   - Test all 15+ components that use SessionManager
   - Verify FocusSessionWidget works correctly
   - Check session persistence and history
   - Validate analytics still capture session data

**Files to Modify**:
- `/Dayflow/Dayflow/Core/FocusLock/FocusSessionManager.swift` - DELETE
- `/Dayflow/Dayflow/Models/FocusLockModels.swift` - Remove LegacyFocusSession struct
- `/Dayflow/Dayflow/Views/UI/FocusSessionWidget.swift` - Refactor to use SessionManager
- `/Dayflow/Dayflow/Views/UI/SmartTodoView.swift` - Remove FocusSessionManager reference
- `/Dayflow/Dayflow/Core/FocusLock/ProactiveCoachEngine.swift` - Remove legacy methods
- `/Dayflow/Dayflow/App/AppDelegate.swift` - Remove FocusSessionManager init

**Success Criteria**:
- [ ] Only one SessionManager exists
- [ ] All session tracking uses FocusSession model
- [ ] FocusSessionWidget functional with SessionManager
- [ ] All session history preserved during migration
- [ ] No compilation errors
- [ ] All tests pass
- [ ] Dashboard renders correctly

**Risk Assessment**: Medium
- FocusSessionWidget is user-facing (must work perfectly)
- Session data migration could lose history if not careful
- Many components depend on SessionManager (careful testing needed)

---

## Priority 2: Other Items

### Session History Storage

**Issue**: Legacy session history uses UserDefaults (temporary solution)

**Solution**: Migrate to SQLite database with proper schema (part of SessionManager consolidation above)

### TODO Comments

**Location**: Various files have `// TODO:` comments that should be addressed

**Action**: Search codebase for `TODO:` and file individual issues

---

## Tracking

- **Created**: 2025-11-08
- **Last Updated**: 2025-11-08
- **Beta Release Target**: Before v1.0
- **Post-Beta Cleanup Target**: v1.1

## Notes

This document should be updated as technical debt is added or resolved.
Use GitHub Issues to track individual work items when ready to address.
