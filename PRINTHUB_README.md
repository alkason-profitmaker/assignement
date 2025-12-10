# PrintHub Community MVP

A hyperlocal, proximity-based self-service printing solution for residential apartment societies.

## Project Overview

PrintHub enables residents to print documents 24/7 within their society premises using a mobile app for file upload, payment, and QR-based print release.

### Key Features

- **Mobile App** (React Native/Expo)
  - Phone-based OTP authentication
  - PDF and image file upload
  - Photo collage creation (2x1, 2x2, 3x2, 4x2 layouts)
  - Real-time pricing preview
  - UPI payment via Razorpay
  - QR code scanning for print release
  - Print progress tracking
  - Order history and rating

- **Backend API** (FastAPI/Python)
  - RESTful API for all operations
  - JWT-based authentication
  - File processing (PDF analysis, image handling)
  - Razorpay payment integration
  - Print job management
  - Auto-refund on failure

### Pricing

| Type | Price per Page |
|------|---------------|
| B/W | ₹3 |
| Color | ₹10 |

## Project Structure

```
assignement/
├── printhub-backend/          # FastAPI Backend
│   ├── app/
│   │   ├── api/               # API routes
│   │   │   └── routes/
│   │   │       ├── auth.py    # Authentication endpoints
│   │   │       ├── orders.py  # Order management
│   │   │       ├── payments.py # Payment processing
│   │   │       └── printer.py # Printer control
│   │   ├── core/              # Core configuration
│   │   │   ├── config.py      # Settings
│   │   │   ├── database.py    # DB connection
│   │   │   └── security.py    # JWT utilities
│   │   ├── models/            # SQLAlchemy models
│   │   │   ├── user.py
│   │   │   ├── order.py
│   │   │   ├── payment.py
│   │   │   └── printer.py
│   │   ├── schemas/           # Pydantic schemas
│   │   ├── services/          # Business logic
│   │   │   ├── user_service.py
│   │   │   ├── order_service.py
│   │   │   ├── payment_service.py
│   │   │   ├── printer_service.py
│   │   │   └── file_service.py
│   │   └── main.py            # FastAPI app entry
│   ├── tests/                 # Test suite
│   ├── requirements.txt
│   └── .env.example
│
└── printhub-mobile/           # React Native App
    ├── App.tsx                # Entry point
    ├── src/
    │   ├── navigation/        # Navigation setup
    │   │   └── RootNavigator.tsx
    │   ├── screens/           # App screens
    │   │   ├── LoginScreen.tsx
    │   │   ├── OTPScreen.tsx
    │   │   ├── HomeScreen.tsx
    │   │   ├── FileUploadScreen.tsx
    │   │   ├── CollageScreen.tsx
    │   │   ├── PreviewScreen.tsx
    │   │   ├── PaymentScreen.tsx
    │   │   ├── QRScannerScreen.tsx
    │   │   ├── PrintStatusScreen.tsx
    │   │   ├── OrderHistoryScreen.tsx
    │   │   └── ProfileScreen.tsx
    │   └── services/          # API & Auth
    │       ├── api.ts
    │       └── AuthContext.tsx
    ├── package.json
    └── app.json
```

## Setup Instructions

### Backend Setup

1. **Create virtual environment**
```bash
cd printhub-backend
python -m venv venv
source venv/bin/activate  # Linux/Mac
# or: venv\Scripts\activate  # Windows
```

2. **Install dependencies**
```bash
pip install -r requirements.txt
```

3. **Configure environment**
```bash
cp .env.example .env
# Edit .env with your settings:
# - RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET
# - SECRET_KEY (generate secure random key)
# - DATABASE_URL (optional, defaults to SQLite)
```

4. **Run the server**
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

5. **API Documentation**
   - Swagger UI: http://localhost:8000/docs
   - ReDoc: http://localhost:8000/redoc

### Mobile App Setup

1. **Install dependencies**
```bash
cd printhub-mobile
npm install
```

2. **Configure API URL**
Edit `src/services/api.ts` and update `API_BASE_URL` for your environment.

3. **Run the app**
```bash
npx expo start
```

4. **Test on device**
   - Scan QR code with Expo Go app (iOS/Android)
   - Or press `a` for Android emulator, `i` for iOS simulator

### Running Tests

```bash
cd printhub-backend
pytest tests/ -v
```

## API Endpoints

### Authentication
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/auth/register` | Register new user |
| POST | `/api/v1/auth/login` | Request OTP |
| POST | `/api/v1/auth/verify-otp` | Verify OTP, get token |
| GET | `/api/v1/auth/me` | Get current user |
| PUT | `/api/v1/auth/me` | Update profile |

### Orders
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/orders/upload` | Upload files for preview |
| POST | `/api/v1/orders/create` | Create order |
| GET | `/api/v1/orders/` | List user orders |
| GET | `/api/v1/orders/{order_number}` | Get order details |
| POST | `/api/v1/orders/{order_number}/rate` | Rate completed order |

### Payments
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/payments/initiate` | Create Razorpay order |
| POST | `/api/v1/payments/verify` | Verify payment |
| GET | `/api/v1/payments/status/{order}` | Get payment status |
| POST | `/api/v1/payments/refund/{order}` | Request refund |

### Printer
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/printer/station` | Get station info |
| POST | `/api/v1/printer/trigger` | Trigger print job |
| GET | `/api/v1/printer/status/{order}` | Get print status |

## User Flow

```
1. Login with phone → OTP verification
           ↓
2. Tap "Print Now" → Select files (PDF/images)
           ↓
3. (Optional) Create photo collage
           ↓
4. Preview & see pricing → Tap "Pay"
           ↓
5. Complete UPI payment via Razorpay
           ↓
6. Walk to printer station → Scan QR code
           ↓
7. Print releases → Collect documents
           ↓
8. Rate experience
```

## Key Technical Decisions

1. **SQLite for MVP** - Simple, no setup required. Switch to PostgreSQL for production.

2. **FastAPI** - Modern async Python framework with automatic OpenAPI docs.

3. **Expo/React Native** - Cross-platform mobile development with easy testing.

4. **Razorpay UPI** - Popular Indian payment gateway with excellent UPI support.

5. **JWT Authentication** - Stateless auth, good for mobile apps.

6. **QR-based Print Release** - Ensures user presence at station (privacy + security).

## Configuration Options

| Variable | Default | Description |
|----------|---------|-------------|
| `PRICE_BW_PAGE` | 3.0 | B/W price per page (INR) |
| `PRICE_COLOR_PAGE` | 10.0 | Color price per page (INR) |
| `ORDER_VALIDITY_HOURS` | 2 | Hours until order expires |
| `MAX_FILE_SIZE_MB` | 50 | Maximum file size |
| `MAX_PAGES_PER_ORDER` | 100 | Maximum pages per order |

## Future Enhancements

- Multi-society support
- DOCX/XLSX direct support (conversion)
- Subscription plans for frequent users
- Admin dashboard
- Printer maintenance alerts
- Cash/card payment options
- Double-sided printing
- A3 paper support

## Troubleshooting

**Backend won't start:**
- Check Python version (3.9+)
- Ensure all dependencies installed
- Verify .env file exists

**Mobile app can't connect:**
- Check API_BASE_URL in api.ts
- Ensure backend is running
- Check network connectivity

**Payment issues:**
- Verify Razorpay credentials
- Check if in test/live mode

## License

Proprietary - PrintHub Community

## Support

For issues and support, contact the development team.
