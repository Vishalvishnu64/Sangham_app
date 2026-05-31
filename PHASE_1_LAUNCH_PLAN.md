# Sangham App - Phase 1 Launch Implementation Plan

**Phase:** Phase 1 - Mobile App Launch (User Access)  
**Timeline:** 4-6 weeks  
**Target:** Users can download app & access personal dashboard  
**Version:** 1.0.0

---

## 📋 Phase 1 Overview

This phase focuses on delivering a **production-ready mobile app** that allows users to:
- ✅ Download from app stores (or direct installation)
- ✅ Register/Login with phone-based authentication
- ✅ View personal dashboard
- ✅ View attendance records
- ✅ Check account balance & transactions
- ✅ View loan details (if any)

**NOT included in Phase 1:**
- ❌ Admin features (moved to Phase 2)
- ❌ Advanced analytics
- ❌ Notification system
- ❌ Offline mode

---

## 🎯 Success Criteria

- ✅ App downloadable from **Google Play Store** or sideload
- ✅ User registration working
- ✅ Authentication with JWT tokens
- ✅ Dashboard loads data correctly
- ✅ 0 critical bugs
- ✅ 99% backend uptime
- ✅ Load time < 3 seconds

---

## 📅 Phase 1 Timeline (6 Weeks)

```
Week 1: Build & Optimization
├─ Native Android build
├─ Performance optimization
└─ Testing on real devices

Week 2: Backend Hardening
├─ Add validation & error handling
├─ Setup production database
└─ Configure security

Week 3: Testing & QA
├─ Manual testing on devices
├─ Bug fixes
└─ Load testing

Week 4: App Store Submission
├─ Google Play Store account setup
├─ App signing & publishing
└─ Pre-launch review

Week 5: Deployment
├─ Production backend deployment
├─ Firebase setup
├─ Monitoring & logging

Week 6: Launch & Monitoring
├─ Soft launch (50 users)
├─ Monitor crashes & feedback
└─ Full launch
```

---

## 🔧 Development Tasks

### Week 1: Build & Optimization

#### 1.1 Android Build
```bash
cd sangham_app

# Clean build
flutter clean

# Build release APK
flutter build apk --release

# Output: build/app/outputs/flutter-app-release.apk

# Build App Bundle (for Google Play Store)
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab
```

**File Locations:**
- APK: `build/app/outputs/apk/release/app-release.apk`
- App Bundle: `build/app/outputs/bundle/release/app-release.aab`

#### 1.2 Performance Optimization

**Update `pubspec.yaml` for production:**
```yaml
# Already added - verify versions
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.1
  http: ^1.2.0
  shared_preferences: ^2.2.2
  intl: ^0.19.0
  table_calendar: ^3.1.0
  google_fonts: ^6.1.0

dev_dependencies:
  flutter_lints: ^3.0.1
```

**Add Error Tracking:**
Add to `pubspec.yaml`:
```yaml
dependencies:
  sentry_flutter: ^7.10.0
```

Update `main.dart`:
```dart
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://your-sentry-dsn';
    },
    appRunner: () => runApp(const SanghamApp()),
  );
}
```

#### 1.3 Testing Checklist

- [ ] Test on Android 8.0+
- [ ] Test on low-end device (1GB RAM)
- [ ] Test on high-end device (8GB RAM)
- [ ] Test with 2G/3G network
- [ ] Test with WiFi
- [ ] Test app lifecycle (background/foreground)
- [ ] Test offline state handling

---

### Week 2: Backend Hardening

#### 2.1 Add Input Validation

**Update `/server/routes/auth.js`:**
```javascript
const validatePhone = (phone) => {
  return /^[0-9]{10}$/.test(phone);
};

const validatePassword = (password) => {
  return password.length >= 4;
};

router.post('/register', async (req, res) => {
  try {
    const { name, phone, password } = req.body;

    // Validation
    if (!name || name.trim().length < 2) {
      return res.status(400).json({ error: 'Name must be at least 2 characters' });
    }

    if (!validatePhone(phone)) {
      return res.status(400).json({ error: 'Phone must be 10 digits' });
    }

    if (!validatePassword(password)) {
      return res.status(400).json({ error: 'Password must be at least 4 characters' });
    }

    // ... rest of code
  } catch (error) {
    res.status(500).json({ error: 'Registration failed' });
  }
});
```

#### 2.2 Setup Production MongoDB

**Create separate database for production:**
1. Go to MongoDB Atlas
2. Create new cluster: `sangham-production`
3. Configure IP whitelist (add deployment server IP)
4. Create database user: `sangham_prod_user`
5. Generate new `.env` for production

**Production `.env`:**
```env
PORT=5000
MONGO_URI=mongodb+srv://sangham_prod_user:PROD_PASSWORD@sangham-production.xxxxx.mongodb.net/sangham_prod
JWT_SECRET=your_long_random_secret_key_min_32_chars
NODE_ENV=production
LOG_LEVEL=warn
```

#### 2.3 Add Monitoring & Logging

**Install PM2 for process management:**
```bash
npm install -g pm2
```

**Create `ecosystem.config.js`:**
```javascript
module.exports = {
  apps: [{
    name: 'sangham-server',
    script: './server.js',
    instances: 'max',
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production'
    },
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time_format: 'YYYY-MM-DD HH:mm:ss Z'
  }]
};
```

**Start with PM2:**
```bash
pm2 start ecosystem.config.js
pm2 save
pm2 startup
```

---

### Week 3: Testing & QA

#### 3.1 Manual Testing on Devices

**Test Scenarios:**

| Scenario | Steps | Expected |
|----------|-------|----------|
| New User Registration | Fill form → Submit | Account created, auto-login |
| Invalid Phone | Enter 5 digits | Error message shown |
| Weak Password | Enter "123" | Error message shown |
| Duplicate Phone | Register same number | Error: Phone already exists |
| Login Success | Correct credentials | Redirected to dashboard |
| Login Failure | Wrong password | Error message shown |
| Dashboard Load | Login → Check dashboard | Data loads in < 2 sec |
| Network Timeout | Disable WiFi, try login | Graceful error message |
| Session Expiry | Old token, make request | Auto-logout |
| Attendance View | Click attendance tab | Calendar displays |
| Passbook View | Click passbook tab | Transaction history shown |

#### 3.2 Bug Tracking

Use GitHub Issues for bug tracking:
```
Title: [BUG] Login fails on low network
Severity: High
Device: Android 8.0, Redmi Note 5
Steps: 1. Turn on WiFi but disable connection
       2. Try to login
       3. See error
Expected: Show timeout error with retry button
```

#### 3.3 Load Testing

**Test with simulated users:**
```bash
npm install -g artillery

# Create load-test.yml
targets:
  - name: "Production API"
    url: "https://your-api-domain.com"

phases:
  - duration: 60
    arrivalRate: 10  # 10 users per second

scenarios:
  - name: "User Login Flow"
    flow:
      - post:
          url: "/api/auth/login"
          json:
            phone: "9876500000"
            password: "0000"
      - think: 5
      - get:
          url: "/api/members"
      - think: 3

# Run test
artillery run load-test.yml
```

---

### Week 4: App Store Submission

#### 4.1 Google Play Store Setup

**Prerequisites:**
1. Google Play Developer account ($25 one-time)
2. Phone with Google Play installed
3. Signing key

**Step 1: Generate Signing Key**

```bash
keytool -genkey -v -keystore ~/sangham_app.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias sangham_key
```

**Step 2: Sign Release Build**

Create `android/key.properties`:
```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=sangham_key
storeFile=/path/to/sangham_app.jks
```

```bash
flutter build appbundle --release
```

**Step 3: Create App on Google Play Console**

1. Go to [Google Play Console](https://play.google.com/console)
2. Create new app
3. Fill details:
   - **App name:** The Digital Ledger
   - **Category:** Finance
   - **Content rating:** Unrated (you'll fill this out)

#### 4.2 Store Listing Details

**App Description:**
```
The Digital Ledger - Your Sangham Companion

Manage your community finances digitally. Track attendance, 
view your balance, check loan details, and access your 
transaction history - all in one secure app.

✅ Secure Authentication
✅ Real-time Balance Updates
✅ Attendance Tracking
✅ Transaction History
✅ Loan Management

Join thousands of users managing their sangham finances 
with confidence.

FEATURES:
• Login with phone number
• View personal dashboard
• Check attendance records
• Track account balance
• View all transactions
• Loan details & status

SECURITY:
• End-to-end encryption
• Secure authentication
• Your data is safe

For support, contact: support@sangham.app
```

**Screenshots (Need to create):**
1. Login screen
2. Dashboard screen
3. Attendance screen
4. Passbook screen

**Privacy Policy:**
Create `privacy_policy.html` and upload to Firebase Hosting

**Content Rating Questionnaire:**
- Violence: No
- Sexual Content: No
- Users: Adults (25+)
- Finance: Yes (app manages finances)

#### 4.3 Upload to Play Store

1. Upload App Bundle (`.aab` file)
2. Fill all required details
3. Set pricing: Free
4. Submit for review

**Review Timeline:** 2-4 hours

---

### Week 5: Deployment

#### 5.1 Backend Deployment (Google Cloud Run)

**Prerequisites:**
- Google Cloud account
- `gcloud` CLI installed
- Docker

**Step 1: Create Cloud Run Service**

```bash
gcloud run deploy sangham-server \
  --source . \
  --platform managed \
  --region asia-south1 \
  --allow-unauthenticated \
  --set-env-vars MONGO_URI=<YOUR_MONGO_URI> \
  --set-env-vars JWT_SECRET=<YOUR_SECRET>
```

**Step 2: Get Service URL**

```bash
gcloud run services list
# Copy the URL, e.g., https://sangham-server-xxxxx.run.app
```

**Step 3: Update Flutter App**

Update `lib/utils/constants.dart`:
```dart
class AppConstants {
  static const String baseUrl = 'https://sangham-server-xxxxx.run.app/api';
  // ... rest
}
```

#### 5.2 Setup Firebase Hosting (Optional)

For web version:
```bash
firebase init hosting

# Build Flutter web
flutter build web --release

# Deploy
firebase deploy --only hosting
```

#### 5.3 Database Backup

**Setup daily backups:**
```bash
# MongoDB Atlas automatic backups (enabled by default)
# Or setup via MongoDB Ops Manager
```

**Manual backup:**
```bash
mongodump --uri "mongodb+srv://user:pass@cluster.mongodb.net/sangham_prod" \
  --out ./backup_$(date +%Y%m%d)
```

---

### Week 6: Launch & Monitoring

#### 6.1 Soft Launch (Beta Testing)

**Invite 50 trusted users:**
- Send APK directly or private link
- Collect feedback for 1 week
- Fix critical bugs

**Feedback Collection:**
- Google Form for feedback
- Email: feedback@sangham.app
- GitHub Issues for bug reports

#### 6.2 Monitor Crashes

**Setup Sentry Dashboard:**
1. Go to [Sentry](https://sentry.io)
2. Create project
3. View crash reports
4. Set up alerts

#### 6.3 Full Launch

Once soft launch is successful:
1. Publish on Google Play Store
2. Send announcement to users
3. Monitor for issues
4. Respond to ratings/reviews

---

## 🛡️ Security Checklist

- [ ] JWT tokens have 24-hour expiration
- [ ] Passwords hashed with bcrypt (10 rounds)
- [ ] HTTPS enabled on all API endpoints
- [ ] CORS configured properly
- [ ] Input validation on all endpoints
- [ ] SQL injection prevention (using MongoDB)
- [ ] Rate limiting configured
- [ ] API keys not exposed
- [ ] Database credentials in environment variables
- [ ] Sensitive data not logged

**Add Rate Limiting:**
```bash
npm install express-rate-limit
```

```javascript
const rateLimit = require('express-rate-limit');

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});

app.use('/api/', limiter);
```

---

## 📱 Testing Devices (Recommended)

| Device | Android Version | RAM | Purpose |
|--------|-----------------|-----|---------|
| Redmi Note 5 | 9.0 | 4GB | Mid-range testing |
| Samsung A10 | 10.0 | 2GB | Low-end testing |
| OnePlus 8 | 11.0 | 8GB | High-end testing |
| Emulator | 11.0 | 2GB | Development testing |

---

## 🚀 Deployment Checklist

### Pre-Launch (Week 4-5)
- [ ] Code review completed
- [ ] All tests passing
- [ ] App signed with production key
- [ ] Backend deployed & tested
- [ ] Database migrated & backed up
- [ ] Monitoring setup (Sentry, etc.)
- [ ] Error tracking configured
- [ ] Performance metrics baseline recorded

### Launch Day (Week 6)
- [ ] Final backend health check
- [ ] Monitor error rates
- [ ] Monitor user registrations
- [ ] Check API response times
- [ ] Review user feedback
- [ ] Be ready for hotfix

### Post-Launch
- [ ] Daily error rate review
- [ ] Weekly performance metrics
- [ ] User feedback analysis
- [ ] Plan Phase 2 features

---

## 📊 Success Metrics

Track these KPIs:

| Metric | Target | Check Frequency |
|--------|--------|-----------------|
| App Crashes | < 0.1% | Daily |
| API Uptime | 99%+ | Hourly |
| API Response Time | < 2 sec | Hourly |
| User Registration Success | 95%+ | Daily |
| Active Users | > 50 | Daily |
| 1-Star Reviews | < 5% | Weekly |

---

## 🆘 Support Plan

**Support Channels:**
1. **Email:** support@sangham.app
2. **In-app Help:** FAQs section
3. **GitHub Issues:** Bug reports
4. **WhatsApp Group:** (Optional) Direct support

**Response SLAs:**
- Critical bugs: 2 hours
- Bug reports: 24 hours
- General support: 48 hours

---

## 📋 Phase 1 Deliverables

1. ✅ Production-ready Android APK
2. ✅ Backend API (deployed)
3. ✅ Production database
4. ✅ User documentation
5. ✅ Admin setup guide
6. ✅ Monitoring & logging
7. ✅ Error tracking
8. ✅ App Store listing
9. ✅ Privacy policy
10. ✅ Support email setup

---

## 🔄 Phase 2 Features (Future)

Once Phase 1 is stable:
- Admin dashboard
- Advanced analytics
- Notification system
- iOS app
- Web version
- Offline support
- Multi-language

---

## 💡 Quick Commands Reference

```bash
# Development
flutter run -d chrome
npm run dev

# Build Release
flutter build apk --release
flutter build appbundle --release

# Testing
npm run seed

# Deployment
gcloud run deploy sangham-server --source .

# Monitoring
pm2 start ecosystem.config.js
pm2 logs
```

---

**Document Version:** 1.0  
**Last Updated:** May 31, 2026  
**Next Review:** After Week 2

