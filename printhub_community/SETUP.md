# PrintHub Community - Setup Guide

## Prerequisites

- Flutter SDK 3.24.0 or higher
- Dart SDK 3.0.0 or higher
- Android Studio / Xcode
- Supabase account
- Paytm Business account (for production)
- Epson Connect account (for production)

## Quick Start

### 1. Clone and Setup

```bash
# Clone the repository
git clone <repository-url>
cd printhub_community

# Get dependencies
flutter pub get

# Generate model serializers
flutter pub run build_runner build --delete-conflicting-outputs
```

### 2. Configure Supabase

1. Create a new Supabase project at [supabase.com](https://supabase.com)
2. Run the database migrations:
   ```bash
   cd supabase
   supabase db push
   ```
3. Update `lib/core/config/environment.dart` with your Supabase credentials

### 3. Configure Environment

Edit the environment files based on your setup:
- `lib/core/config/environment.dart` - Update Supabase URLs and keys

### 4. Run the App

```bash
# Development
flutter run --flavor development -t lib/main_development.dart

# Staging
flutter run --flavor staging -t lib/main_staging.dart

# Production
flutter run --flavor production -t lib/main_production.dart
```

## Project Structure

```
printhub_community/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── main_development.dart        # Development flavor entry
│   ├── main_staging.dart            # Staging flavor entry
│   ├── main_production.dart         # Production flavor entry
│   ├── core/
│   │   ├── config/                  # Environment configuration
│   │   ├── constants/               # App constants
│   │   ├── logging/                 # Logging infrastructure
│   │   ├── models/                  # Data models
│   │   ├── network/                 # API client & exceptions
│   │   ├── providers/               # Riverpod providers
│   │   ├── services/                # Business logic services
│   │   ├── storage/                 # Local storage
│   │   └── utils/                   # Utilities
│   └── features/
│       ├── auth/                    # Authentication screens
│       ├── home/                    # Home screen
│       ├── orders/                  # Order history
│       ├── print/                   # Print flow
│       └── profile/                 # User profile
├── android/                         # Android platform files
├── ios/                             # iOS platform files
├── supabase/
│   ├── migrations/                  # Database schema
│   └── functions/                   # Edge Functions
├── test/
│   ├── unit/                        # Unit tests
│   ├── widget/                      # Widget tests
│   └── integration/                 # Integration tests
└── .github/workflows/               # CI/CD pipelines
```

## Building for Production

### Android

```bash
# Build APK
flutter build apk --flavor production -t lib/main_production.dart --release

# Build App Bundle (for Play Store)
flutter build appbundle --flavor production -t lib/main_production.dart --release
```

### iOS

```bash
# Build IPA
flutter build ipa --flavor production -t lib/main_production.dart --release
```

## Running Tests

```bash
# All tests
flutter test

# With coverage
flutter test --coverage

# Specific test file
flutter test test/unit/models/order_test.dart
```

## CI/CD

The project includes GitHub Actions workflows:

- **CI** (`ci.yml`): Runs on PRs - analyze, test, build
- **Release** (`release.yml`): Runs on tags - build and create release

### Required Secrets

For release builds, configure these GitHub secrets:
- `ANDROID_KEYSTORE_BASE64` - Base64 encoded keystore
- `ANDROID_KEYSTORE_PASSWORD` - Keystore password
- `ANDROID_KEY_ALIAS` - Key alias
- `ANDROID_KEY_PASSWORD` - Key password
- `APPLE_CERTIFICATE_BASE64` - iOS signing certificate
- `APPLE_CERTIFICATE_PASSWORD` - Certificate password
- `APPLE_PROVISION_PROFILE_BASE64` - Provisioning profile

## Supabase Edge Functions

Deploy edge functions:

```bash
cd supabase
supabase functions deploy paytm-webhook
supabase functions deploy epson-status
```

Set function secrets:
```bash
supabase secrets set PAYTM_MERCHANT_ID=your_id
supabase secrets set PAYTM_MERCHANT_KEY=your_key
supabase secrets set EPSON_ACCESS_TOKEN=your_token
```

## Support

For issues or questions, contact the development team.
