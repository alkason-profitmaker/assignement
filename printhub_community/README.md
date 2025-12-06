# PrintHub Community

A hyperlocal, self-service printing solution designed for residential apartment societies in India. Enables residents to print documents 24/7 from their smartphones.

![Flutter](https://img.shields.io/badge/Flutter-3.2+-blue)
![Dart](https://img.shields.io/badge/Dart-3.0+-blue)
![Supabase](https://img.shields.io/badge/Supabase-Backend-green)
![Razorpay](https://img.shields.io/badge/Razorpay-Payments-blue)

## Features

- **Phone OTP Authentication** - Secure login with phone number verification
- **Document Upload** - Support for PDF, JPG, PNG files up to 10MB
- **Smart Document Analysis** - Auto page count and color detection
- **UPI Payments** - Seamless payment via Razorpay (Google Pay, PhonePe, Paytm)
- **Real-time Status** - Live tracking of print job status
- **Push Notifications** - Get notified when your print is ready
- **Print History** - View all your past print jobs
- **Cover Page System** - Easy document identification with pickup codes

## Tech Stack

### Mobile App (Flutter)
- **State Management**: flutter_bloc
- **Navigation**: go_router
- **Backend**: Supabase (Auth, Database, Storage, Edge Functions)
- **Payments**: Razorpay Flutter SDK
- **Notifications**: Firebase Cloud Messaging
- **File Handling**: file_picker, image, pdf

### Backend (Supabase)
- **Database**: PostgreSQL with Row Level Security
- **Authentication**: Phone OTP via Supabase Auth
- **Storage**: Document storage with auto-cleanup
- **Edge Functions**: Deno runtime for serverless logic

### External Services
- **Razorpay**: UPI payment processing
- **Epson Connect**: Cloud printing API
- **Firebase**: Push notifications

## Project Structure

```
printhub_community/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── app_router.dart           # Navigation configuration
│   ├── core/
│   │   ├── constants/            # App-wide constants
│   │   ├── theme/                # Theming (colors, typography)
│   │   ├── errors/               # Error handling
│   │   ├── network/              # Network utilities
│   │   └── utils/                # Helper functions
│   ├── features/
│   │   ├── auth/                 # Authentication module
│   │   ├── home/                 # Home screen
│   │   ├── upload/               # Document upload
│   │   ├── payment/              # Payment processing
│   │   ├── print_job/            # Print job management
│   │   ├── history/              # Print history
│   │   └── profile/              # User profile
│   └── shared/
│       └── widgets/              # Reusable widgets
├── supabase/
│   ├── migrations/               # Database migrations
│   └── functions/                # Edge Functions
├── assets/
│   ├── images/
│   └── fonts/
└── test/
```

## Getting Started

### Prerequisites

- Flutter SDK 3.2+
- Dart 3.0+
- Supabase account
- Razorpay account
- Firebase project

### Installation

1. **Clone the repository**
```bash
git clone <repository-url>
cd printhub_community
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **Configure environment variables**

Update `lib/core/constants/app_constants.dart` with your credentials:

```dart
// Supabase
static const String supabaseUrl = 'your-supabase-url';
static const String supabaseAnonKey = 'your-anon-key';

// Razorpay
static const String razorpayKeyId = 'your-razorpay-key';

// Epson Connect (optional)
static const String epsonClientId = 'your-epson-client-id';
```

4. **Set up Supabase**

Run the SQL migrations in your Supabase dashboard:
```sql
-- Execute supabase/migrations/001_initial_schema.sql
```

5. **Deploy Edge Functions**
```bash
supabase functions deploy create-payment-order
supabase functions deploy handle-payment-webhook
supabase functions deploy process-print-job
supabase functions deploy send-notification
supabase functions deploy generate-cover-page
```

6. **Configure Firebase**

- Add `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
- Enable Cloud Messaging

7. **Run the app**
```bash
flutter run
```

## Database Schema

### Tables

| Table | Description |
|-------|-------------|
| `users` | User profiles and preferences |
| `print_jobs` | Print job records and status |
| `payments` | Payment transactions |
| `societies` | Registered societies |
| `printer_status` | Real-time printer status |
| `notifications` | Notification history |
| `daily_stats` | Analytics data |

### Print Job Status Flow

```
pending → processing → printing → ready → collected
                                      ↓
                                   expired
```

## API Endpoints (Edge Functions)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/create-payment-order` | POST | Create Razorpay order |
| `/handle-payment-webhook` | POST | Process payment callback |
| `/process-print-job` | POST | Trigger print job |
| `/send-notification` | POST | Send push notification |
| `/generate-cover-page` | POST | Generate pickup cover page |

## Pricing

| Type | Price |
|------|-------|
| Black & White | ₹2/page |
| Color | ₹10/page |
| Minimum Order | ₹2 (1 page) |

## Configuration Options

### File Limits
- Max file size: 10 MB
- Max pages per job: 50
- Supported formats: PDF, JPG, JPEG, PNG

### Timing
- OTP expiry: 5 minutes
- Document retention: 30 minutes
- Print job expiry: 24 hours

## Testing

```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test/
```

## Deployment

### Android
```bash
flutter build apk --release
# or
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

## Environment Variables (Edge Functions)

```env
SUPABASE_URL=your-supabase-url
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
RAZORPAY_KEY_ID=your-razorpay-key
RAZORPAY_KEY_SECRET=your-razorpay-secret
FCM_SERVER_KEY=your-fcm-server-key
EPSON_CLIENT_ID=your-epson-client-id
EPSON_CLIENT_SECRET=your-epson-client-secret
EPSON_PRINTER_EMAIL=printer@print.epsonconnect.com
```

## Security

- Row Level Security (RLS) enabled on all tables
- Users can only access their own data
- Payment verification via Razorpay signature
- Documents auto-deleted after 24 hours
- Phone OTP for authentication

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is proprietary and confidential.

## Support

- Email: support@printhub.community
- Phone: +91 98765 43210
- WhatsApp: +91 98765 43210

---

Built with ❤️ for Indian residential communities
