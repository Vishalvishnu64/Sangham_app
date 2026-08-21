# Sangham App

## Abstract
Sangham App is a digital management platform for community savings groups ("Sanghams"). It combines a Flutter mobile application with a Node.js/Express backend and MongoDB to manage members, attendance, weekly contributions, transactions, dashboards, and loan lifecycles. The system supports role-based access (admin and member), helping groups replace manual bookkeeping with transparent and trackable financial records.

## Overview
This repository contains two main parts:
- **`sangham_app/`**: Flutter client application
- **`server/`**: Node.js + Express REST API

## Core Features
- Phone/password authentication with JWT
- Role-based access (`admin`, `user`)
- Member management (create, update, deactivate/delete)
- Attendance tracking and attendance history
- Contribution and transaction tracking
- User and admin dashboards
- Loan issuing, repayment, and interest calculation
- Weekly status summary endpoints

## Tech Stack
- **Frontend:** Flutter, Provider, HTTP, Shared Preferences, Table Calendar, FL Chart
- **Backend:** Node.js, Express, Mongoose, JWT, bcryptjs, node-cron
- **Database:** MongoDB

## Repository Structure
```text
Sangham_app/
├── README.md
├── PHASE_1_LAUNCH_PLAN.md
├── sangham_app/                 # Flutter app
│   ├── lib/
│   │   ├── models/
│   │   ├── providers/
│   │   ├── screens/
│   │   │   ├── admin/
│   │   │   ├── auth/
│   │   │   └── user/
│   │   ├── services/
│   │   └── utils/
│   └── pubspec.yaml
└── server/                      # Backend API
    ├── middleware/
    ├── models/
    ├── routes/
    ├── utils/
    ├── server.js
    └── package.json
```

## Backend Setup (`server/`)

### Prerequisites
- Node.js 18+ (recommended)
- MongoDB instance (local or Atlas)

### Install
```bash
cd /home/runner/work/Sangham_app/Sangham_app/server
npm install
```

### Environment Variables
Create a `.env` file in `/home/runner/work/Sangham_app/Sangham_app/server`:
```env
PORT=5000
MONGO_URI=your_mongodb_connection_string
JWT_SECRET=your_jwt_secret
```

### Run Backend
```bash
npm run dev
```
or
```bash
npm start
```

### Seed Sample Data (optional)
```bash
npm run seed
```

## Flutter App Setup (`sangham_app/`)

### Prerequisites
- Flutter SDK (3.x recommended)
- Android Studio / VS Code with Flutter plugins
- Connected emulator or physical device

### Install
```bash
cd /home/runner/work/Sangham_app/Sangham_app/sangham_app
flutter pub get
```

### API Base URL Configuration
The app uses `lib/utils/constants.dart`:
```dart
static const String baseUrl = 'https://sangham-app.onrender.com/api';
```
Update this value if running the backend locally.

### Run Flutter App
```bash
flutter run
```

## API Modules
Base URL: `/api`

- `POST /auth/register`
- `POST /auth/login`
- `GET /auth/me`
- `GET|POST|PUT|DELETE /members`
- `GET|POST|PUT|DELETE /transactions`
- `GET|POST /attendance`
- `GET /dashboard/admin`
- `GET /dashboard/user/:id`
- `POST /loans`
- `POST /loans/:id/repay`
- `POST /loans/:id/calculate-interest`

Health endpoint:
- `GET /api/health`

## App Flows
- **Admin flow:** manage members, contributions, attendance, loans, and history
- **User flow:** view dashboard, passbook, attendance calendar, and loan details

## Security Notes
- Passwords are hashed with bcrypt before storage
- JWT token-based API authorization
- Protected routes use authentication middleware
- Admin-only operations are protected by role middleware

## Deployment Notes
- Backend is configured for environment-based deployment (`PORT`, `MONGO_URI`, `JWT_SECRET`)
- Current production API reference in Flutter points to Render:
  `https://sangham-app.onrender.com/api`
- See `PHASE_1_LAUNCH_PLAN.md` for production launch and rollout guidance

## Useful Commands
### Backend
```bash
cd /home/runner/work/Sangham_app/Sangham_app/server
npm install
npm run dev
npm run seed
```

### Flutter
```bash
cd /home/runner/work/Sangham_app/Sangham_app/sangham_app
flutter pub get
flutter run
flutter build apk --release
```