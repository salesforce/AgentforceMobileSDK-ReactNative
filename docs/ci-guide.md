# CI Guide for AgentforceMobileSDK-ReactNative

This guide explains the continuous integration system for the Agentforce Mobile SDK React Native sample application.

## Table of Contents

- [Overview](#overview)
- [PR Validation Pipeline](#pr-validation-pipeline)
- [Internal SDK Testing](#internal-sdk-testing)
- [Local Development](#local-development)
- [Troubleshooting](#troubleshooting)

---

## Overview

### Public Repository (This Repo)

- **PR Validation**: Validates code quality, tests, and builds on every pull request to `dev`
- **No Secrets Required**: Builds use mock/anonymous configuration
- **Fast Feedback**: ~20-25 minutes per PR

### Internal SDK Repositories

- **Nightly Integration Testing**: Internal iOS and Android AgentforceSDK repos pull this React Native repo during their nightly SFCI runs
- **Real SDK Testing**: Tests against internal SDK versions before public release
- **Issue Creation**: Automatically creates GitHub issues in this repo if builds fail

---

## PR Validation Pipeline

**File:** `.github/workflows/pr-checks.yml`

**Trigger:** Every pull request to `dev` branch

**Pipeline Structure:**

```
┌─────────────────────────────────────┐
│  Job 1: Lint & Type Check (2 min)  │
│  - ESLint                           │
│  - Prettier format check            │
│  - TypeScript type check            │
└──────────────┬──────────────────────┘
               │ ✓ Pass → Continue
               ▼
┌─────────────────────────────────────┐
│  Job 2: Unit Tests (3 min)         │
│  - Run Jest with coverage           │
└──────────────┬──────────────────────┘
               │ ✓ Pass → Continue
               ▼
┌─────────────────────────────────────┐
│  Job 3: Build Matrix (parallel)    │
│  - iOS Service Agent                │
│  - iOS Employee Agent               │
│  - Android Service Agent            │
│  - Android Employee Agent           │
└──────────────┬──────────────────────┘
               │ ✓ All pass
               ▼
┌─────────────────────────────────────┐
│  All Checks Passed ✓                │
└─────────────────────────────────────┘
```

**Build Variants:**

1. **Service Agent iOS** - Customer-facing app, anonymous auth
2. **Service Agent Android** - Customer-facing app, anonymous auth
3. **Employee Agent iOS** - Workforce app, OAuth auth via Mobile SDK
4. **Employee Agent Android** - Workforce app, OAuth auth via Mobile SDK

**Features:**

- Fail-fast strategy: lint/tests run before builds
- Parallel builds for all 4 variants
- Dependency caching (npm, Gradle, CocoaPods)
- Build logs uploaded on failure
- Total runtime: ~20-25 minutes

---

## Internal SDK Testing

The internal Agentforce SDK repositories perform integration testing of this React Native sample app as part of their nightly SFCI pipelines.

### How It Works

**iOS SDK:** [git.soma.salesforce.com/iOS/AgentforceSDK](https://git.soma.salesforce.com/iOS/AgentforceSDK)
**Android SDK:** [git.soma.salesforce.com/Android/AgentforceSDK](https://git.soma.salesforce.com/Android/AgentforceSDK)

Each nightly build:

1. Clones this React Native repo (dev branch)
2. Installs dependencies: `npm ci --legacy-peer-deps`
3. Builds both platform variants (Service Agent + Employee Agent)
4. On failure: Creates GitHub issue in this repo with logs, SDK version, and labels
5. On success after previous failure: Auto-closes the related issue

**Issue Labels:**

- `CI` - Created by automated CI
- `sdk-integration` - SDK integration testing failure
- `ios` or `android` - Platform-specific
- `bridge` - Likely requires bridge updates

### Integration Commands

**For Internal SDK Team:**

**iOS:**

```bash
node installios.js all
npm run build:ios:service
npm run build:ios:employee
```

**Android:**

```bash
node installandroid.js all
npm run build:android:service
npm run build:android:employee
```

**For React Native Maintainers:**

When an SDK integration issue is created:

1. Check build logs and SDK version in the issue
2. Try to reproduce locally with that SDK version
3. Fix the React Native bridge or sample app code
4. Next nightly build validates the fix and auto-closes the issue

---

## Local Development

### Prerequisites

- Node.js 18+
- Dependencies installed: `npm ci --legacy-peer-deps`

### Commands

#### Linting

```bash
npm run lint          # Check for linting errors
npm run lint:fix      # Auto-fix linting errors
```

#### Formatting

```bash
npm run format        # Check code formatting
npm run format:fix    # Auto-fix formatting
```

#### Type Checking

```bash
npm run typecheck     # TypeScript compilation check
```

#### Tests

```bash
npm test              # Run all tests
npm test -- --coverage       # With coverage
npm test -- --watch          # Watch mode
```

#### Build Validation

```bash
# iOS
node installios.js service     # or employee
npm run build:ios:service      # or build:ios:employee

# Android
node installandroid.js service # or employee
npm run build:android:service  # or build:android:employee
```

### Pre-PR Checklist

```bash
npm run lint
npm run format
npm run typecheck
npm test
```

---

## Troubleshooting

### Common CI Failures

#### Linting Errors

```bash
npm run lint:fix
git add .
git commit -m "Fix linting errors"
git push
```

#### Formatting Issues

```bash
npm run format:fix
git add .
git commit -m "Fix code formatting"
git push
```

#### TypeScript Errors

```bash
npm run typecheck  # Identify errors
# Fix type errors in code
git commit -m "Fix TypeScript errors"
git push
```

#### Test Failures

```bash
npm test -- --verbose  # Debug failing tests
# Fix test or code
git commit -m "Fix failing tests"
git push
```

#### Build Failures

**Android:**

```bash
node installandroid.js service  # or employee
npm run build:android:service   # or employee
# If issues persist:
cd android && ./gradlew clean && ./gradlew :app:assembleServiceAgentRelease --stacktrace
```

**iOS:**

```bash
node installios.js service      # or employee
rm -rf ios/build                # Clean build folder
npm run build:ios:service       # or employee
```

#### Cache Issues

Clear GitHub Actions cache:

1. Go to repository → Actions → Caches
2. Delete relevant caches
3. Re-run workflow

Or bump cache version in workflow:

```yaml
key: ${{ runner.os }}-gradle-v2-${{ hashFiles('**/*.gradle*') }}
```

#### Timeout Errors

Re-run the workflow or increase timeout in `.github/workflows/pr-checks.yml`:

```yaml
timeout-minutes: 45 # Increase from 30
```

#### Out of Memory Errors (Android)

Update `android/gradle.properties`:

```properties
org.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=1g
```

### SDK Integration Issues

**Symptom:** GitHub issue created by internal SDK nightly build

**Indicates:**

- Breaking changes in internal SDK affecting React Native bridge
- API changes requiring bridge updates
- Build configuration issues

**Resolution:**

1. Review issue for platform, SDK version, error logs
2. Check `AgentforceSDK-ReactNative-Bridge/` for needed updates
3. Reproduce locally if possible
4. Coordinate with SDK team if needed
5. Fix and merge to dev
6. Next nightly build validates and auto-closes issue

### Viewing Build Logs

**In Pull Request:**

1. Scroll to "Checks" section
2. Click failing check → "Details"

**In Actions Tab:**

1. Go to Actions → Click workflow run
2. Click failing job → Expand steps

**Download Artifacts:**

1. Go to workflow run → "Artifacts" section
2. Download `build-logs-<platform>-<variant>.zip`

---

## Configuration

### GitHub Actions Runners

**Linux (Android):** Ubuntu Latest, 2 cores, 7GB RAM
**macOS (iOS):** macOS 26, 3 cores, 14GB RAM

### Caching

- **npm:** `package-lock.json` hash (~2-3 min savings)
- **Gradle:** `**/*.gradle*` hash (~3-5 min savings)
- **CocoaPods:** `ios/Podfile.*.lock` hash (~2-4 min savings)

### Timeouts

- Lint & Type Check: 10 minutes
- Unit Tests: 10 minutes
- Build Validation: 30 minutes per variant

---

## Key Files

- `.github/workflows/pr-checks.yml` - PR validation workflow
- `.eslintrc.js` - ESLint configuration
- `.prettierrc.js` - Prettier configuration
- `package.json` - npm scripts
- `tsconfig.json` - TypeScript configuration

---

**Last Updated:** March 13, 2026
