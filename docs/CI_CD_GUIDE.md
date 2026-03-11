# CI/CD Guide for AgentforceMobileSDK-ReactNative

This guide explains the continuous integration and continuous deployment (CI/CD) system for the Agentforce Mobile SDK React Native sample application.

## Table of Contents

- [Overview](#overview)
- [Workflows](#workflows)
  - [PR Validation Pipeline](#pr-validation-pipeline)
  - [Artifact Generation](#artifact-generation-coming-soon)
  - [Nightly SDK Checks](#nightly-sdk-checks-coming-soon)
- [Local Development](#local-development)
- [GitHub Actions Configuration](#github-actions-configuration)
- [Troubleshooting](#troubleshooting)

---

## Overview

The CI/CD system validates all pull requests, generates build artifacts, and detects breaking changes in internal Agentforce SDKs. It's designed to be:

- **Fast**: Fail-fast strategy with parallel execution
- **Reliable**: Comprehensive validation of all 4 build variants
- **Maintainable**: Clear workflows with inline documentation
- **Secure**: Proper secret management for OAuth credentials

### Build Variants

This project has **4 build variants** (2 apps × 2 platforms):

1. **Service Agent iOS** - Customer-facing app, anonymous auth
2. **Service Agent Android** - Customer-facing app, anonymous auth
3. **Employee Agent iOS** - Workforce app, OAuth auth via Mobile SDK
4. **Employee Agent Android** - Workforce app, OAuth auth via Mobile SDK

All 4 variants are validated on every PR.

---

## Workflows

### PR Validation Pipeline

**File:** `.github/workflows/pr-checks.yml`

**Trigger:** Every pull request to `main` branch

**Pipeline Structure:**

```
┌─────────────────────────────────────┐
│  Job 1: Lint & Type Check (2 min)  │
│  - ESLint                           │
│  - Prettier format check            │
│  - TypeScript type check            │
│  - Fail fast on errors              │
└──────────────┬──────────────────────┘
               │ ✓ Pass → Continue
               │ ✗ Fail → Stop
               ▼
┌─────────────────────────────────────┐
│  Job 2: Unit Tests (3 min)         │
│  - Run Jest                         │
│  - Upload coverage report           │
└──────────────┬──────────────────────┘
               │ ✓ Pass → Continue
               │ ✗ Fail → Stop
               ▼
┌─────────────────────────────────────┐
│  Job 3: Build Matrix (parallel)    │
│  4 builds running simultaneously:   │
│  - iOS Service Agent (macOS)        │
│  - iOS Employee Agent (macOS)       │
│  - Android Service Agent (Linux)    │
│  - Android Employee Agent (Linux)   │
└──────────────┬──────────────────────┘
               │ ✓ All pass
               ▼
┌─────────────────────────────────────┐
│  Status: All Checks Passed ✓        │
└─────────────────────────────────────┘
```

**Features:**

- **Fail Fast**: Cheap checks (lint, tests) run first before expensive builds
- **Parallel Execution**: All 4 builds run simultaneously
- **Caching**: npm, Gradle, and CocoaPods dependencies cached
- **Timeout Protection**: 10 min for lint/tests, 30 min for builds
- **Build Logs**: Uploaded on failure for debugging

**Expected Runtime:**

- Lint & Type Check: ~2 minutes
- Unit Tests: ~3 minutes
- Builds (parallel): ~15-20 minutes
- **Total: ~20-25 minutes**

**Status Checks:**

All jobs must pass before PR can be merged:

- ✅ Lint & Type Check
- ✅ Unit Tests
- ✅ Build Android - Service Agent
- ✅ Build Android - Employee Agent
- ✅ Build iOS - Service Agent
- ✅ Build iOS - Employee Agent
- ✅ All Checks Passed

---

### Artifact Generation (Coming Soon)

**File:** `.github/workflows/build-artifacts.yml` (Phase 2)

**Purpose:** Generate installable .apk and .ipa files for QA testing

**Trigger:** Manual workflow dispatch (initially)

**Artifacts Generated:**

- `AgentforceSDK-Android-ServiceAgent-{build}-{sha}.apk`
- `AgentforceSDK-Android-EmployeeAgent-{build}-{sha}.apk`
- `AgentforceSDK-iOS-ServiceAgent-{build}-{sha}.ipa`
- `AgentforceSDK-iOS-EmployeeAgent-{build}-{sha}.ipa`

**Secret Injection:**

OAuth credentials are injected from GitHub Secrets:

- `IOS_OAUTH_CONSUMER_KEY`
- `IOS_OAUTH_REDIRECT_URI`
- `ANDROID_OAUTH_CONSUMER_KEY`
- `ANDROID_OAUTH_REDIRECT_URI`

**Artifact Retention:** 30 days

---

### Nightly SDK Checks (Coming Soon)

**File:** `.github/workflows/nightly-sdk-check.yml` (Phase 3)

**Purpose:** Detect breaking changes in internal Agentforce SDKs early

**Trigger:** Manual workflow dispatch with SDK version parameter

**Process:**

1. Clone/checkout specified internal SDK version (iOS and Android)
2. Update dependencies to point to internal SDK
3. Build all 4 variants
4. On failure: Create GitHub Issue with error logs
5. On success: Close any open failure issues

**Future:** Automate with nightly schedule when SDK access is configured

---

## Local Development

### Prerequisites

Before running CI commands locally, ensure you have:

- Node.js 18+ installed
- npm dependencies installed: `npm ci --legacy-peer-deps`

### Available Commands

#### Linting

```bash
# Check for linting errors
npm run lint

# Fix linting errors automatically
npm run lint:fix
```

**What it checks:**

- ESLint rules (React Native community standards)
- TypeScript-specific rules
- Code quality issues

#### Formatting

```bash
# Check code formatting
npm run format

# Fix formatting issues automatically
npm run format:fix
```

**What it checks:**

- Prettier formatting rules
- Consistent code style across the project

#### Type Checking

```bash
# Run TypeScript type check
npm run typecheck
```

**What it checks:**

- TypeScript compilation errors
- Type safety issues
- Strict mode violations

#### Unit Tests

```bash
# Run all tests
npm test

# Run tests with coverage
npm test -- --coverage

# Run tests in watch mode
npm test -- --watch
```

#### Build Validation

Test builds locally before pushing:

```bash
# iOS Service Agent
node installios.js service
npm run build:ios:service

# iOS Employee Agent
node installios.js employee
npm run build:ios:employee

# Android Service Agent
node installandroid.js service
npm run build:android:service

# Android Employee Agent
node installandroid.js employee
npm run build:android:employee
```

### Pre-PR Checklist

Before opening a pull request, run:

```bash
# 1. Lint check
npm run lint

# 2. Format check
npm run format

# 3. Type check
npm run typecheck

# 4. Run tests
npm test

# 5. (Optional) Build validation
# Choose one variant to test locally
npm run build:android:service
```

---

## GitHub Actions Configuration

### Runner Specifications

**Linux Runners** (Android builds):

- OS: Ubuntu Latest
- CPU: 2 cores
- RAM: 7 GB
- Disk: 14 GB SSD

**macOS Runners** (iOS builds):

- OS: macOS 14 (Sonoma)
- CPU: 3 cores (Apple Silicon M1)
- RAM: 14 GB
- Disk: 14 GB SSD

### Caching Strategy

**npm modules:**

- Cache key: `npm-${{ runner.os }}-${{ hashFiles('package-lock.json') }}`
- Estimated savings: 2-3 minutes per build

**Gradle (Android):**

- Paths: `~/.gradle/caches`, `~/.gradle/wrapper`, `android/.gradle`
- Cache key: `gradle-${{ hashFiles('**/*.gradle*', '**/gradle-wrapper.properties') }}`
- Estimated savings: 3-5 minutes per build

**CocoaPods (iOS):**

- Path: `ios/Pods`
- Cache key: `pods-${{ hashFiles('ios/Podfile.*.lock') }}`
- Estimated savings: 2-4 minutes per build

### Timeout Configuration

Jobs are configured with appropriate timeouts:

- Lint & Type Check: 10 minutes
- Unit Tests: 10 minutes
- Build Validation: 30 minutes per variant

Prevents hung jobs from consuming CI resources.

---

## Troubleshooting

### Common CI Failures

#### 1. Linting Errors

**Symptom:** PR check fails on "Lint & Type Check"

**Fix:**

```bash
# Run locally to see errors
npm run lint

# Auto-fix most issues
npm run lint:fix

# Commit the fixes
git add .
git commit -m "Fix linting errors"
git push
```

#### 2. Formatting Issues

**Symptom:** PR check fails on "Check formatting"

**Fix:**

```bash
# Check what's wrong
npm run format

# Auto-fix formatting
npm run format:fix

# Commit the fixes
git add .
git commit -m "Fix code formatting"
git push
```

#### 3. TypeScript Errors

**Symptom:** PR check fails on "Run TypeScript type check"

**Fix:**

```bash
# Run type check locally
npm run typecheck

# Fix type errors in your code
# Then commit
git add .
git commit -m "Fix TypeScript errors"
git push
```

#### 4. Test Failures

**Symptom:** PR check fails on "Unit Tests"

**Fix:**

```bash
# Run tests locally to reproduce
npm test

# Debug the failing test
npm test -- --verbose

# Fix the test or code
git add .
git commit -m "Fix failing tests"
git push
```

#### 5. Build Failures

**Symptom:** PR check fails on one of the build jobs

**Android Build Failures:**

```bash
# Run setup locally
node installandroid.js service  # or employee

# Try building locally
npm run build:android:service  # or employee

# Check for Gradle errors
cd android
./gradlew clean
./gradlew :app:assembleServiceAgentRelease --stacktrace
```

**iOS Build Failures:**

```bash
# Run setup locally
node installios.js service  # or employee

# Clean build folder
rm -rf ios/build

# Try building locally
npm run build:ios:service  # or employee

# Check for Xcode errors
xcodebuild -workspace ios/ReactAgentforce.xcworkspace \
  -scheme ServiceAgent \
  -configuration Release \
  clean build
```

#### 6. Cache Issues

**Symptom:** Builds fail with dependency version mismatches

**Fix:** Clear GitHub Actions cache

1. Go to repository → Actions → Caches
2. Delete relevant caches (npm, gradle, or pods)
3. Re-run the workflow

Alternatively, update the cache key in workflow file by bumping version:

```yaml
# Before
key: ${{ runner.os }}-gradle-${{ hashFiles('**/*.gradle*') }}

# After
key: ${{ runner.os }}-gradle-v2-${{ hashFiles('**/*.gradle*') }}
```

#### 7. Timeout Errors

**Symptom:** Job fails with "The job was canceled because it exceeded the maximum execution time."

**Causes:**

- Network issues downloading dependencies
- Slow runner instance
- Inefficient build configuration

**Fix:**

- Re-run the workflow (might get faster runner)
- Increase timeout in workflow file if consistently slow:

```yaml
timeout-minutes: 45 # Increase from 30
```

#### 8. Out of Memory (OOM) Errors

**Symptom:** Build fails with Java heap space errors (Android)

**Fix:** Update `android/gradle.properties`:

```properties
org.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=1g
```

Commit and push the change.

---

### Viewing Build Logs

#### In Pull Request

1. Go to your PR page
2. Scroll to "Checks" section at bottom
3. Click on the failing check
4. Click "Details" to view logs

#### In Actions Tab

1. Go to repository → Actions
2. Click on the workflow run
3. Click on the failing job
4. Expand steps to view logs

#### Download Build Logs (on failure)

When builds fail, logs are automatically uploaded as artifacts:

1. Go to workflow run
2. Scroll to "Artifacts" section
3. Download `build-logs-<platform>-<variant>.zip`
4. Extract and review logs locally

---

### Getting Help

If you're stuck:

1. **Check this guide first** - Most common issues are documented here
2. **Search closed PRs** - Someone might have encountered similar issue
3. **Review recent commits** - Breaking changes are usually documented
4. **Ask in Slack** - Ping the Agentforce Mobile team
5. **Open an issue** - If it's a CI infrastructure problem

---

## Maintenance

### Weekly

- Review failed builds, investigate root causes
- Check for flaky tests

### Monthly

- Review metrics (build times, success rates)
- Optimize slow steps
- Update action versions if available

### Quarterly

- Update GitHub Action versions
- Review and rotate secrets
- Plan improvements based on usage patterns

---

## Cost and Usage

**GitHub Actions for public repositories:**

- ✅ **Unlimited minutes** - No cost for public repos
- ✅ **No usage limits** - Run as many builds as needed
- ✅ **Free artifact storage** - Within reasonable limits (30-day retention)

**Estimated Resource Usage:**

- PR validation: ~20-25 minutes per PR
- Storage: ~200-300 MB artifacts (when Phase 2 implemented)
- Cost: $0 (unlimited for public repos)

---

## Future Enhancements (Not Yet Implemented)

These features are planned but not yet implemented:

### Phase 2: Artifact Generation

- Manual workflow to generate installable .apk and .ipa files
- Inject real OAuth credentials from GitHub Secrets
- Upload artifacts for QA testing

**Status:** Planned for Week 2

### Phase 3: Nightly SDK Checks

- Detect breaking changes in internal Agentforce SDKs
- Automatically create GitHub Issues on failures
- Manual trigger initially, automate later

**Status:** Planned for Week 3

### Phase 4: Documentation Generation

- Auto-generate TypeScript API docs using TypeDoc
- Deploy to GitHub Pages
- Trigger on push to `main`

**Status:** Nice-to-have, planned for Week 4

### What We're NOT Doing (Intentionally)

- ❌ Complex notification systems (Slack, Email)
- ❌ Dependabot integration
- ❌ Code coverage tracking UI
- ❌ E2E testing (Detox/Maestro)
- ❌ Automated app store releases
- ❌ Self-hosted runners
- ❌ Native documentation (Jazzy/KDoc)

**Reason:** Keep it simple initially, add incrementally when proven need arises.

---

## Contact

For questions or issues with CI/CD:

- **GitHub Issues**: [Report infrastructure problems](https://github.com/salesforce/AgentforceMobileSDK-ReactNative/issues)
- **Pull Requests**: Suggest improvements via PR

---

## Appendix

### Workflow Status Badges

Add these badges to README.md to show CI status:

```markdown
[![PR Validation](https://github.com/YOUR_ORG/AgentforceMobileSDK-ReactNative/actions/workflows/pr-checks.yml/badge.svg)](https://github.com/YOUR_ORG/AgentforceMobileSDK-ReactNative/actions/workflows/pr-checks.yml)
```

### Configuration Files

Key CI/CD configuration files:

- `.github/workflows/pr-checks.yml` - PR validation workflow
- `.eslintrc.js` - ESLint configuration
- `.prettierrc.js` - Prettier configuration
- `.prettierignore` - Prettier ignore patterns
- `package.json` - npm scripts for lint, format, typecheck
- `tsconfig.json` - TypeScript configuration

### Related Documentation

- [CONTRIBUTING.md](../CONTRIBUTING.md) - Contribution guidelines
- [README.md](../README.md) - Project setup and usage

---

**Last Updated:** March 10, 2026
**Version:** 1.0 (Phase 1 - PR Validation)
