# Sangham App - Development Progress & Documentation

**Last Updated:** May 31, 2026  
**Version:** 1.0.0  
**Status:** In Development 🚀

---

## 📋 Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [Current Features](#current-features)
- [Development Status](#development-status)
- [Firebase Setup](#firebase-setup)
- [Building & Deployment](#building--deployment)
- [Development Roadmap](#development-roadmap)
- [Installation & Setup](#installation--setup)
- [API Documentation](#api-documentation)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Project Overview

**Sangham App** - "The Digital Ledger" is a comprehensive digital management system for community groups (Sanghams). It provides members with tools to manage attendance, loans, contributions, and financial transactions in a centralized, secure platform.

### Key Objectives
- ✅ Digitize traditional sangham record-keeping
- ✅ Provide real-time financial tracking
- ✅ Enable efficient member management
- ✅ Ensure transparency in fund management
- ✅ Offer role-based access (Admin/User)

### Tech Stack

| Component | Technology | Version |
|-----------|-----------|---------|
| **Frontend** | Flutter | 3.0+ |
| **Backend** | Node.js + Express | 18+ |
| **Database** | MongoDB | 6.0+ |
| **Authentication** | JWT + bcryptjs | |
| **Hosting** | Firebase (Frontend) / Cloud Run (Backend) | |
| **UI Framework** | Material Design 3 | |
| **State Management** | Provider | 6.1.1+ |

---

## 🏗️ Architecture

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     SANGHAM APP SYSTEM                      │
└─────────────────────────────────────────────────────────────┘

┌──────────────────┐           ┌──────────────────┐
│   Flutter App    │◄─────────►│  Node.js Server  │
│  (iOS/Android/   │   REST    │   (Express.js)   │
│     Web)         │   APIs    │                  │
└──────────────────┘           └──────────────────┘
         │                             │
         │                             │
         ▼                             ▼
    Firebase                      MongoDB Atlas
    Hosting                        Database
```

### Project Structure

```
Sangham_app/
├── sangham_app/                 # Flutter Frontend
│   ├── lib/
│   │   ├── main.dart           # App entry point
│   │   ├── models/             # Data models
│   │   │   ├── user_model.dart
│   │   │   ├── attendance_model.dart
│   │   │   ├── loan_model.dart
│   │   │   └── transaction_model.dart
│   │   ├── providers/          # State management
│   │   │   └── auth_provider.dart
│   │   ├── screens/            # UI Screens
│   │   │   ├── splash_screen.dart
│   │   │   ├── auth/
│   │   │   │   ├── login_screen.dart
│   │   │   │   └── signup_screen.dart
│   │   │   ├── admin/
│   │   │   │   ├── admin_dashboard.dart
│   │   │   │   ├── admin_shell.dart
│   │   │   │   ├── members_screen.dart
│   │   │   │   ├── attendance_manager.dart
│   │   │   │   ├── loan_management_screen.dart
│   │   │   │   ├── add_contribution_screen.dart
│   │   │   │   └── history_screen.dart
│   │   │   └── user/
│   │   │       ├── user_shell.dart
│   │   │       ├── user_dashboard.dart
│   │   │       ├── attendance_calendar.dart
│   │   │       ├── loan_screen.dart
│   │   │       └── passbook_screen.dart
│   │   ├── services/           # API integration
│   │   │   └── api_service.dart
│   │   └── utils/
│   │       └── constants.dart
│   ├── pubspec.yaml            # Dependencies
│   ├── analysis_options.yaml
│   └── web/                    # Web assets
│
├── server/                     # Node.js Backend
│   ├── server.js              # Main entry point
│   ├── package.json           # Dependencies
│   ├── .env                   # Environment variables
│   ├── models/                # MongoDB schemas
│   │   ├── User.js
│   │   ├── Attendance.js
│   │   ├── Loan.js
│   │   ├── Transaction.js
│   │   └── AuditLog.js
│   ├── routes/                # API endpoints
│   │   ├── auth.js
│   │   ├── members.js
│   │   ├── attendance.js
│   │   ├── loans.js
│   │   ├── transactions.js
│   │   └── dashboard.js
│   ├── middleware/            # Express middleware
│   │   └── auth.js
│   └── seed.js               # Database seeding
│
└── README.md
```

---

## ✨ Current Features

### ✅ Implemented Features

#### Authentication & Authorization
- [x] User Registration with phone-based signup
- [x] Secure Login (JWT tokens)
- [x] Role-based access (Admin/User)
- [x] Password hashing with bcryptjs
- [x] Token-based authentication

#### Admin Features
- [x] Dashboard with key metrics
- [x] Member management
- [x] Attendance tracking and management
- [x] Loan management system
- [x] Contribution/Transaction recording
- [x] Transaction history
- [x] Member list with filters

#### User Features
- [x] Personal dashboard
- [x] View attendance records (Calendar view)
- [x] Loan application tracking
- [x] Digital passbook (transaction history)
- [x] Account balance display
- [x] Profile management

#### Backend APIs
- [x] Authentication endpoints
- [x] Member management APIs
- [x] Attendance CRUD operations
- [x] Loan management APIs
- [x] Transaction recording
- [x] Dashboard statistics
- [x] Health check endpoint

### 🔄 In Progress Features

- [ ] Advanced analytics and reporting
- [ ] Notification system (Push/SMS)
- [ ] Audit logging
- [ ] Export functionality (PDF/Excel)
- [ ] Mobile app optimization
- [ ] Dark mode
- [ ] Multi-language support

### 📋 Planned Features

- [ ] Dividend management
- [ ] Investment tracking
- [ ] Member communication system
- [ ] Document storage & sharing
- [ ] Advanced search and filters
- [ ] Mobile app for iOS/Android
- [ ] Two-factor authentication
- [ ] Biometric authentication
- [ ] Offline mode support

---

## 📊 Development Status

### Frontend (Flutter)

| Feature | Status | Progress | Notes |
|---------|--------|----------|-------|
| Splash Screen | ✅ Complete | 100% | App initialization |
| Login Screen | ✅ Complete | 100% | Phone + Password auth |
| Sign Up Screen | ✅ Complete | 100% | New member registration |
| Admin Dashboard | ✅ Complete | 100% | Key metrics display |
| Admin Shell | ✅ Complete | 100% | Navigation structure |
| Members Screen | ✅ Complete | 100% | List & search members |
| Attendance Manager | ✅ Complete | 100% | Mark & view attendance |
| Loan Management | ✅ Complete | 100% | Loan CRUD operations |
| Contribution Form | ✅ Complete | 100% | Record transactions |
| History Screen | ✅ Complete | 100% | Transaction history |
| User Dashboard | ✅ Complete | 100% | Personal overview |
| User Shell | ✅ Complete | 100% | User navigation |
| Attendance Calendar | ✅ Complete | 100% | Visual attendance view |
| Loan Screen | ✅ Complete | 100% | User loan details |
| Passbook | ✅ Complete | 100% | Transaction history |
| UI/UX Polish | 🔄 In Progress | 70% | Material Design 3 |
| Error Handling | 🔄 In Progress | 60% | Better error messages |

### Backend (Node.js)

| Feature | Status | Progress | Notes |
|---------|--------|----------|-------|
| Express Setup | ✅ Complete | 100% | Server framework |
| MongoDB Connection | ✅ Complete | 100% | Database integration |
| Authentication | ✅ Complete | 100% | JWT middleware |
| User Model | ✅ Complete | 100% | Schema defined |
| Auth Routes | ✅ Complete | 100% | Login/Register/Me |
| Members Routes | ✅ Complete | 100% | List/Create/Update |
| Attendance Routes | ✅ Complete | 100% | Mark/Get attendance |
| Loans Routes | ✅ Complete | 100% | Loan management |
| Transactions Routes | ✅ Complete | 100% | Record transactions |
| Dashboard Routes | ✅ Complete | 100% | Statistics |
| Validation | 🔄 In Progress | 70% | Input validation |
| Error Handling | 🔄 In Progress | 70% | Consistent errors |
| Audit Logging | ⏳ Planned | 0% | Track all actions |
| Rate Limiting | ⏳ Planned | 0% | API protection |

### Deployment

| Component | Status | Notes |
|-----------|--------|-------|
| Firebase Setup | ⏳ Pending | Needs configuration |
| Flutter Web Build | ⏳ Pending | Release build |
| Backend Deployment | ⏳ Pending | Cloud Run setup |
| Database Migration | ⏳ Pending | Production DB |
| Environment Config | ⏳ Pending | Production env vars |

---

## 🔥 Firebase Setup

### Prerequisites
- Firebase project created
- Firebase CLI installed
- Flutter project configured for web

### Firebase Configuration Steps

#### 1. Initialize Firebase Project

```bash
# Install Firebase CLI (if not already installed)
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase in project root
firebase init hosting
```

#### 2. Configure Flutter Web for Firebase

Add to `sangham_app/web/index.html`:

```html
<!-- The core Firebase JS SDK is always required and must be listed first -->
<script src="https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.7.0/firebase-hosting-compat.js"></script>

<script>
  // TODO: Add your Firebase config
  const firebaseConfig = {
    apiKey: "YOUR_API_KEY",
    authDomain: "YOUR_PROJECT.firebaseapp.com",
    projectId: "YOUR_PROJECT_ID",
    storageBucket: "YOUR_PROJECT.appspot.com",
    messagingSenderId: "YOUR_SENDER_ID",
    appId: "YOUR_APP_ID"
  };
  
  firebase.initializeApp(firebaseConfig);
</script>
```

#### 3. Update firebase.json

```json
{
  "hosting": {
    "public": "sangham_app/build/web",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  }
}
```

#### 4. Build Flutter Web

```bash
cd sangham_app
flutter build web --release
cd ..
```

#### 5. Deploy to Firebase

```bash
firebase deploy --only hosting
```

### Firebase Realtime Database (Optional)

For real-time notifications and updates:

```dart
// Add to pubspec.yaml
firebase_core: ^2.24.0
firebase_database: ^10.2.0
firebase_messaging: ^14.6.0
```

### Firebase Storage (Optional)

For file uploads:

```dart
firebase_storage: ^11.2.0
```

---

## 🚀 Building & Deployment

### Local Development Setup

#### Frontend

```bash
# Navigate to Flutter app
cd sangham_app

# Get dependencies
flutter pub get

# Run on emulator/device
flutter run

# Run on web (local)
flutter run -d chrome

# Run on web (release)
flutter run -d web --release
```

#### Backend

```bash
# Navigate to server
cd server

# Install dependencies
npm install

# Create .env file
cp .env.example .env
# Edit .env with your MongoDB URI and other configs

# Run in development mode
npm run dev

# Run in production
npm start

# Seed sample data
npm run seed
```

### Build for Production

#### Flutter Web Build

```bash
cd sangham_app

# Clean previous builds
flutter clean

# Build web release
flutter build web --release

# Output: sangham_app/build/web/
```

#### Backend Docker (Optional)

Create `server/Dockerfile`:

```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE 5000

CMD ["node", "server.js"]
```

Build and run:

```bash
docker build -t sangham-server .
docker run -p 5000:5000 \
  -e MONGO_URI=<your_mongodb_uri> \
  -e JWT_SECRET=<your_secret> \
  sangham-server
```

### Deployment to Google Cloud Run

```bash
# Build Docker image
gcloud builds submit --tag gcr.io/PROJECT_ID/sangham-server

# Deploy to Cloud Run
gcloud run deploy sangham-server \
  --image gcr.io/PROJECT_ID/sangham-server \
  --platform managed \
  --region asia-south1 \
  --set-env-vars MONGO_URI=<your_mongodb_uri>
```

---

## 🗺️ Development Roadmap

### Phase 1: Core Features (Current - Week 1-2)
- [x] User authentication
- [x] Member management
- [x] Attendance system
- [x] Basic loan management
- [x] Transaction recording
- [x] Dashboard

### Phase 2: Enhancement & Polish (Week 3-4)
- [ ] Advanced error handling
- [ ] Input validation
- [ ] Audit logging
- [ ] Export functionality
- [ ] Better UI/UX
- [ ] Performance optimization

### Phase 3: Advanced Features (Week 5-6)
- [ ] Real-time notifications
- [ ] Analytics dashboard
- [ ] Advanced search
- [ ] Document management
- [ ] Communication system
- [ ] Two-factor authentication

### Phase 4: Mobile & Optimization (Week 7-8)
- [ ] Native iOS app
- [ ] Native Android app
- [ ] Offline mode
- [ ] Performance optimization
- [ ] Security hardening

### Phase 5: Deployment & Launch (Week 9-10)
- [ ] Production environment setup
- [ ] Firebase hosting
- [ ] Cloud database setup
- [ ] Monitoring & logging
- [ ] Public release

---

## 📦 Installation & Setup

### Prerequisites

```bash
# Check Node.js version (18+)
node --version

# Check Flutter version (3.0+)
flutter --version

# Check MongoDB (running locally or Atlas)
```

### Quick Start

```bash
# 1. Clone repository
git clone <repository-url>
cd Sangham_app

# 2. Setup Backend
cd server
npm install
cp .env.example .env
# Edit .env with your credentials
npm run seed
npm start

# 3. Setup Frontend (in new terminal)
cd ../sangham_app
flutter pub get
flutter run -d chrome  # or flutter run for mobile

# 4. Access Application
# Web: http://localhost
# Mobile: Check console output
```

### Environment Variables

#### server/.env

```env
PORT=5000
MONGO_URI=mongodb+srv://<username>:<password>@cluster.mongodb.net/<dbname>
JWT_SECRET=your_jwt_secret_key_here
NODE_ENV=development

# Firebase (Optional)
FIREBASE_API_KEY=your_firebase_api_key
FIREBASE_PROJECT_ID=your_project_id
```

#### sangham_app/lib/utils/constants.dart

```dart
class AppConstants {
  static const String baseUrl = 'http://localhost:5000/api';
  // For production:
  // static const String baseUrl = 'https://your-api-domain.com/api';
  
  static const String appName = 'The Digital Ledger';
  static const String appVersion = '1.0.0';
}
```

---

## 📡 API Documentation

### Base URL
- **Development:** `http://localhost:5000/api`
- **Production:** `https://your-api-domain.com/api`

### Authentication Endpoints

#### POST /api/auth/register
Register new user
```json
Request:
{
  "name": "John Doe",
  "phone": "+919876543210",
  "password": "password123"
}

Response:
{
  "success": true,
  "token": "jwt_token_here",
  "user": {
    "_id": "user_id",
    "name": "John Doe",
    "phone": "+919876543210",
    "role": "user"
  }
}
```

#### POST /api/auth/login
Login user
```json
Request:
{
  "phone": "+919876543210",
  "password": "password123"
}

Response:
{
  "success": true,
  "token": "jwt_token_here",
  "user": { ... }
}
```

#### GET /api/auth/me
Get current user (requires authentication)
```json
Response:
{
  "success": true,
  "user": { ... }
}
```

### Members Endpoints

#### GET /api/members
Get all members
```
Headers: Authorization: Bearer <token>
Response: List of members with balances
```

#### GET /api/members/:id
Get specific member details

#### POST /api/members
Create new member (Admin only)

#### PUT /api/members/:id
Update member (Admin only)

### Attendance Endpoints

#### GET /api/attendance/:memberId/:month/:year
Get attendance for member

#### POST /api/attendance/mark
Mark attendance
```json
{
  "memberId": "id",
  "date": "2026-05-31",
  "status": "present"
}
```

### Loan Endpoints

#### GET /api/loans
Get all loans

#### POST /api/loans
Create new loan application

#### PUT /api/loans/:id/status
Update loan status

### Transaction Endpoints

#### GET /api/transactions
Get all transactions

#### POST /api/transactions
Record new transaction
```json
{
  "memberId": "id",
  "type": "contribution",
  "amount": 1000,
  "description": "Monthly contribution"
}
```

### Dashboard Endpoints

#### GET /api/dashboard
Get dashboard statistics
```json
Response:
{
  "totalMembers": 150,
  "totalBalance": 500000,
  "monthlyContribution": 50000,
  "activeLoanCount": 45
}
```

---

## 🛠️ Troubleshooting

### Common Issues

#### 1. MongoDB Connection Error
```
Error: MongoDB connection error
```
**Solution:**
- Check MONGO_URI in .env
- Ensure MongoDB Atlas cluster is active
- Verify IP whitelist includes your machine

#### 2. CORS Error
```
Error: Access to XMLHttpRequest blocked by CORS policy
```
**Solution:**
- Ensure backend has proper CORS configuration
- Check frontend API URL in constants
- Verify backend is running

---

## 🏦 Loan Interest System (v1.0) ⭐ NEW

### Overview
Comprehensive monthly interest tracking system for loans with automatic accrual and dynamic recalculation after repayments.

### Key Features
- **Monthly Interest Rate:** 1% of remaining principal
- **Dynamic Calculation:** Interest recalculates based on remaining balance after each payment
- **Automated Accrual:** Cron job runs 1st of every month (00:00 UTC)
- **Payment Priority:** Interest paid first, then principal reduced
- **Full Audit Trail:** Payment history with principal/interest breakdown
- **Manual Triggers:** Admin can manually calculate interest if needed

### How It Works

#### Interest Calculation Formula
```
Monthly Interest = Remaining Principal × 0.01 (1%)

Example:
- Loan Amount: 10,000 Rs
- Month 1 Interest: 10,000 × 0.01 = 100 Rs
- Total Due: 10,100 Rs

- After 500 Rs payment (100 Rs interest + 400 Rs principal):
- New Principal: 9,600 Rs
- Month 2 Interest: 9,600 × 0.01 = 96 Rs
```

### Database Schema

**Loan Model Extensions:**
```javascript
{
  principalAmount: Number,           // Original loan amount
  remainingPrincipal: Number,        // After repayments
  interestRate: Number,              // 0.01 = 1% per month
  currentMonthInterest: Number,      // This month's calculated interest
  totalInterestPaid: Number,         // Cumulative paid
  outstandingBalance: Number,        // Principal + current month interest
  interestCalculatedDate: Date,      // Last calculation timestamp
  repayments: [{
    date: Date,
    principalPaid: Number,
    interestPaid: Number,
    totalPaid: Number,
    remainingBalance: Number
  }]
}
```

### API Endpoints

#### Get Loan Details with Interest
```
GET /api/loans/:id/details

Response:
{
  _id: "...",
  principalAmount: 10000,
  remainingPrincipal: 9500,
  currentMonthInterest: 95,
  totalInterestPaid: 500,
  outstandingBalance: 9595,
  status: "active",
  repayments: [
    {
      date: "2025-01-15",
      principalPaid: 500,
      interestPaid: 100,
      totalPaid: 600,
      remainingBalance: 9500
    }
  ]
}
```

#### Make Repayment (with Interest Processing)
```
POST /api/loans/:id/repay
Body: { amount: 500 }

Response:
{
  success: true,
  message: "Payment recorded",
  repaymentSummary: {
    amountPaid: 500,
    interestPaid: 95,
    principalPaid: 405,
    newRemainingPrincipal: 9095,
    newInterestDue: 90.95
  }
}
```

#### Manual Interest Calculation
```
POST /api/loans/:id/calculate-interest

Response:
{
  success: true,
  interest: 95,
  calculatedAt: "2025-01-01T00:00:00Z"
}
```

#### Batch Interest Calculation (Admin)
```
POST /api/admin/loans/calculate-all-interests

Response:
{
  success: true,
  loansProcessed: 45,
  totalInterestAdded: 4500
}
```

### Backend Implementation

**Files:**
- `server/utils/loanInterest.js` - Calculation functions
- `server/utils/loanScheduler.js` - Cron job scheduler
- `server/routes/loans.js` - API endpoints
- `server/models/Loan.js` - Database schema

**Cron Schedule:**
```
Pattern: "0 0 1 * *"
Meaning: 1st day of every month at 00:00 UTC
Auto-runs on server startup
```

### Frontend Implementation

**New Screen:** `LoanDetailsScreen`
- Display total due (principal + interest) in prominent card
- Show breakdown: principal remaining vs. current month interest
- Payment history table with principal/interest columns
- Repayment dialog with validation
- Amount must be ≤ total due
- Shows breakdown of where money goes (interest first, then principal)

**Updated Screen:** `LoanScreen`
- Loan cards now tappable
- Navigation to LoanDetailsScreen
- Shows outstanding balance

### Testing Checklist

- [x] Interest calculation logic tested
- [x] Database schema migrations applied
- [x] API endpoints return correct values
- [x] Payment repayment priority working (interest first)
- [x] Dynamic recalculation after repayments functional
- [x] Scheduler initializes on server startup
- [x] Frontend screens display interest correctly
- [x] APK builds successfully
- [ ] Device testing (connect device to test UI)
- [ ] Scheduler execution on 1st of month (will verify when date arrives)

### Example Flow

1. **Admin issues loan:** 10,000 Rs at 1% monthly interest
2. **System calculates:** 100 Rs interest for Month 1
3. **User sees:** Total due 10,100 Rs
4. **User makes payment:** 600 Rs
   - 100 Rs goes to interest
   - 500 Rs goes to principal
   - New principal: 9,500 Rs
5. **Next month:** 
   - Cron job runs on 1st day
   - Calculates: 9,500 Rs × 0.01 = 95 Rs
   - New interest applied

### Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | Jan 2025 | Initial implementation with 1% monthly rate, automated accrual, dynamic recalculation |

---

## 🚀 Recent Updates (January 2025)

### Completed
- ✅ Implemented monthly loan interest system (1%)
- ✅ Created automated cron scheduler for interest accrual
- ✅ Updated Loan model with interest tracking fields
- ✅ Added new API endpoints for interest operations
- ✅ Created LoanDetailsScreen with interest breakdown UI
- ✅ Implemented payment priority (interest first)
- ✅ Fixed Flutter build issues
- ✅ Successfully built debug APK

### Current Status
- Backend: 🟢 **LIVE** on Render.com
- Database: 🟢 **ACTIVE** on MongoDB Atlas
- Frontend: ✅ **APK builds successfully**
- Deployment: Ready for device installation

### Known Issues
- Dashboard has minor UI overflow (acceptable for MVP)
- Device needs to be reconnected for testing

---

**Last Updated:** January 2025  
**Status:** ✅ Production Ready (MVP)  
**Build:** Flutter 3.44.0 | Node.js 18+
```
**Solution:**
```javascript
// Already configured in server.js
app.use(cors());
```

#### 3. Flutter Build Fails
```
error: Unable to connect to localhost:5000
```
**Solution:**
- Update API URL in `constants.dart`
- For Android/iOS: Use machine IP instead of localhost
- Check if backend server is running

#### 4. JWT Token Invalid
```
Error: jwt malformed
```
**Solution:**
- Clear stored token: `await prefs.remove('token')`
- Login again
- Ensure JWT_SECRET matches on backend

#### 5. Firebase Deployment Issues
```
Error: Firebase hosting not initialized
```
**Solution:**
```bash
firebase logout
firebase login
firebase init hosting
firebase deploy
```

### Debug Commands

```bash
# Backend debug
NODE_DEBUG=* npm start

# Flutter debug
flutter run -v

# Check MongoDB connection
mongosh <connection_string>

# Check Firebase status
firebase status
```

### Performance Optimization

- **Frontend:** Enable code shrinking for release build
- **Backend:** Implement caching strategies
- **Database:** Create indexes on frequently queried fields
- **API:** Implement pagination (limit: 20 items per page)

---

## 📱 Testing

### Manual Testing Checklist

#### Authentication
- [ ] User can register with phone number
- [ ] User receives success message on registration
- [ ] User can login with correct credentials
- [ ] User gets error with incorrect password
- [ ] Token persists on app restart
- [ ] Logout clears stored credentials

#### Admin Features
- [ ] Admin can view dashboard
- [ ] Admin can manage members
- [ ] Admin can mark attendance
- [ ] Admin can create loan applications
- [ ] Admin can record transactions
- [ ] Admin can view transaction history

#### User Features
- [ ] User can view personal dashboard
- [ ] User can view attendance calendar
- [ ] User can view loan details
- [ ] User can view digital passbook
- [ ] User can update profile

### Automated Testing (Future)

```dart
// Example Flutter test
void main() {
  testWidgets('Login screen test', (WidgetTester tester) async {
    await tester.pumpWidget(const SanghamApp());
    
    // Enter credentials
    await tester.enterText(find.byType(TextField).first, '9876543210');
    await tester.pumpAndSettle();
    
    // Verify login
    expect(find.byType(Dashboard), findsOneWidget);
  });
}
```

---

## 📚 Additional Resources

### Documentation
- [Flutter Docs](https://flutter.dev/docs)
- [Express.js Guide](https://expressjs.com/)
- [MongoDB Documentation](https://docs.mongodb.com/)
- [Firebase Docs](https://firebase.google.com/docs)
- [Material Design 3](https://m3.material.io/)

### Useful Tools
- [Postman](https://www.postman.com/) - API testing
- [MongoDB Compass](https://www.mongodb.com/products/compass) - DB management
- [Firebase Console](https://console.firebase.google.com/) - Project management
- [VS Code Extensions](https://marketplace.visualstudio.com/)
  - Dart & Flutter
  - REST Client
  - MongoDB for VS Code

---

## 🤝 Contributing Guidelines

1. Create feature branch: `git checkout -b feature/feature-name`
2. Make changes and test
3. Commit with clear messages: `git commit -m "Add: feature description"`
4. Push to branch: `git push origin feature/feature-name`
5. Create Pull Request with detailed description

### Code Style

- **Dart:** Follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
- **JavaScript:** Use ESLint with Airbnb config
- **Comments:** Add JSDoc for functions
- **Naming:** Use camelCase for variables, PascalCase for classes

---

## 📞 Support & Contact

For issues, suggestions, or contributions:
- Create GitHub Issue
- Contact development team
- Check existing documentation

---

## 📄 License

This project is proprietary software. All rights reserved.

---

## 🎯 Next Steps

1. **Setup Firebase:**
   - Follow Firebase Setup section above
   - Deploy web app to Firebase Hosting

2. **Setup Backend Deployment:**
   - Configure MongoDB Atlas
   - Deploy backend to Google Cloud Run
   - Setup environment variables

3. **Testing:**
   - Perform manual testing on all features
   - Test on multiple devices/browsers
   - Load testing for API endpoints

4. **Documentation:**
   - Update API documentation
   - Create user guide
   - Create admin guide

5. **Launch:**
   - Final security review
   - Performance testing
   - Public release

---

**Document Version:** 1.0.0  
**Last Updated:** May 31, 2026  
**Next Review:** After Phase 2 Completion

