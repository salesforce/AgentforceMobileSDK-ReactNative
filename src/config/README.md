# App Configuration

This directory contains configuration that controls which agent UI elements are shown in the app.

## Files

### AppConfig.ts

Main configuration file that reads `APP_MODE` from `AppConfig.generated.ts` and exports UI feature flags.

### AppConfig.generated.ts

Auto-generated file created by `scripts/generate-app-config.js`. Contains the `APP_MODE` value for the current build target.

### README.md

This file.

## APP_MODE

Controls which agent UI elements are shown:

| Mode         | Service Agent UI | Employee Agent UI  |
| ------------ | ---------------- | ------------------ |
| `'service'`  | ✅ Shown         | ❌ Hidden          |
| `'employee'` | ❌ Hidden        | ✅ Shown           |
| `'all'`      | ✅ Shown         | ✅ Shown (default) |

**Note**: Feature Flags UI tab is always shown in all modes.

## Usage

The npm run scripts automatically generate the correct APP_MODE:

```bash
# Service Agent only
npm run android:service
npm run ios:service

# Employee Agent only
npm run android:employee
npm run ios:employee
```

Each script runs `node scripts/generate-app-config.js [service|employee]` before building.

## Manual Configuration

To manually change the mode without using npm scripts:

```bash
node scripts/generate-app-config.js service   # Service Agent only
node scripts/generate-app-config.js employee  # Employee Agent only
node scripts/generate-app-config.js all       # Both agents
```
