# ShuleDrive Configuration Guide

This guide explains how to securely configure environment variables and API tokens in the ShuleDrive app.

## Table of Contents
- [Quick Start](#quick-start)
- [Configuration Methods](#configuration-methods)
- [Security Best Practices](#security-best-practices)
- [Troubleshooting](#troubleshooting)

---

## Quick Start

### Option 1: .env File (Recommended for Development)

1. Copy the example environment file:
   ```bash
   copy .env.example .env
   ```

2. Edit `.env` and add your Mapbox token:
   ```env
   MAPBOX_ACCESS_TOKEN=pk.your_actual_mapbox_token_here
   ```

3. Run the app normally:
   ```bash
   flutter run
   ```

### Option 2: dart-define (Recommended for Production)

Pass the token at build time:
```bash
flutter run --dart-define=MAPBOX_ACCESS_TOKEN=pk.your_token
```

Or for release builds:
```bash
flutter build apk --dart-define=MAPBOX_ACCESS_TOKEN=pk.your_token
flutter build ios --dart-define=MAPBOX_ACCESS_TOKEN=pk.your_token
```

---

## Configuration Methods

### Priority Order

The app looks for configuration values in this order (first match wins):

1. **dart-define** (compile-time, highest priority)
   - Use for: Production builds, CI/CD pipelines
   - Example: `--dart-define=MAPBOX_ACCESS_TOKEN=pk.token`

2. **.env file** (runtime, development)
   - Use for: Local development, quick testing
   - File: `.env` (not committed to git)

3. **Default values** (fallback)
   - Built into the app for non-sensitive defaults

---

## Configuration Reference

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `MAPBOX_ACCESS_TOKEN` | Mapbox public access token | `pk.eyJ1Ijoi...` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `API_BASE_URL` | Backend API URL | `https://staging-api.shuledrive.com` |
| `ENVIRONMENT` | App environment | `development` (debug), `production` (release) |

---

## Security Best Practices

### 1. Never Commit Tokens

The `.env` file is already added to `.gitignore`. Never commit it:
```bash
# Check what files are tracked
git status

# If you accidentally added .env, remove it
git rm --cached .env
git commit -m "Remove .env from tracking"
```

### 2. Use Different Tokens per Environment

Create separate environment files:
- `.env` - Development (default)
- `.env.staging` - Staging
- `.env.production` - Production (use dart-define instead)

### 3. Rotate Tokens Regularly

- Mapbox tokens can be rotated in your [Mapbox account](https://account.mapbox.com/access-tokens/)
- Update the `.env` file and restart the app

### 4. Use URL Restrictions

In Mapbox dashboard, configure URL restrictions on your tokens:
- For Android: `app://com.example.shuledrive`
- For iOS: `com.example.shuledrive`

### 5. Monitor Token Usage

Mapbox provides usage analytics. Monitor for unexpected usage patterns.

---

## Troubleshooting

### "Mapbox token not found" Error

**Problem**: App shows "Mapbox token not found" message

**Solutions**:
1. Check that `.env` file exists in project root
2. Verify token is set: `MAPBOX_ACCESS_TOKEN=pk.your_token` (not `ACCESS_TOKEN`)
3. Restart the app completely (hot reload may not pick up .env changes)
4. Check the token format (should start with `pk.`)

### Token Works in Debug but Not Release

**Problem**: App works in debug mode but maps don't load in release

**Solutions**:
1. For release builds, use dart-define instead of .env:
   ```bash
   flutter build apk --dart-define=MAPBOX_ACCESS_TOKEN=pk.your_token
   ```
2. Ensure `.env` is listed in `pubspec.yaml` assets:
   ```yaml
   assets:
     - .env
   ```

### How to Get a Mapbox Token

1. Go to [https://account.mapbox.com/](https://account.mapbox.com/)
2. Sign up or log in
3. Navigate to "Access Tokens"
4. Click "Create a token"
5. Give it a name (e.g., "ShuleDrive Development")
6. Copy the public token (starts with `pk.`)
7. Paste into your `.env` file

---

## Advanced Usage

### Programmatic Access

Access configuration anywhere in the app:

```dart
import 'services/app_config.dart';

// Get Mapbox token
final token = appConfig.mapboxAccessToken;

// Check environment
if (appConfig.isProduction) {
  // Production-specific logic
}

// Get API base URL
final apiUrl = appConfig.apiBaseUrl;
```

### Custom Configuration Values

Add custom values to `.env`:
```env
MY_CUSTOM_KEY=my_custom_value
```

Access in code:
```dart
final value = appConfig.get('MY_CUSTOM_KEY');
final withDefault = appConfig.getOrDefault('MY_CUSTOM_KEY', 'default');
```

---

## CI/CD Configuration

For automated builds, use dart-define:

### GitHub Actions Example

```yaml
- name: Build APK
  run: flutter build apk --release
    --dart-define=MAPBOX_ACCESS_TOKEN=${{ secrets.MAPBOX_TOKEN }}
    --dart-define=API_BASE_URL=${{ secrets.API_URL }}
```

### Codemagic Example

```yaml
workflows:
  android:
    environment:
      vars:
        MAPBOX_TOKEN: encrypted_value_here
    scripts:
      - name: Build
        script: flutter build apk --dart-define=MAPBOX_ACCESS_TOKEN=$MAPBOX_TOKEN
```

---

## Migration from Old System

If you were previously using only `ACCESS_TOKEN`:

1. The old `--dart-define=ACCESS_TOKEN=...` still works (backward compatible)
2. Consider migrating to `MAPBOX_ACCESS_TOKEN` for clarity
3. The `.env` file should use `MAPBOX_ACCESS_TOKEN`

---

## Support

For configuration issues:
1. Check the debug console for `[AppConfig]` log messages
2. Verify your token at [Mapbox Token Debugger](https://docs.mapbox.com/help/troubleshooting/token-debugger/)
3. Contact the development team with the output of:
   ```dart
   appConfig.printConfig(); // In debug mode only
   ```
