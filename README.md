# Local Auto App (Rural Rides)

A real-time ride-hailing and tracking platform designed for auto-rickshaws, consisting of three Flutter applications and a centralized Firebase backend.

---

## 📱 Applications Overview

### 1. [Rider App](./rider)
- **Anonymous Authentication:** Instant access without mandatory upfront credentials.
- **Geohash Proximity Search:** Dynamic real-time search of nearby available drivers (0.5 km to 5.0 km radius).
- **Interactive Google Maps:** Live vehicle markers with automatic spiderfying for overlapping drivers.
- **Direct Calling & Logging:** Call drivers directly with automatic backend logging.

### 2. [Driver App](./driver)
- **Onboarding & KYC:** Multi-step registration with identity & driving license document verification.
- **Single-Device Enforcement:** Prevents duplicate concurrent logins across devices.
- **Background Location Broadcasting:** Headless foreground tracking (`flutter_foreground_task`) streaming geohashed coordinates directly to Firebase Realtime Database.
- **Online / Offline Toggle:** Interactive radar interface with instant system-tray status controls.

### 3. [Admin Dashboard](./admin)
- **KYC & Driver Verification:** Review pending driver applications, verify documents, and approve/reject/hold accounts.
- **Call Analytics:** Live monitoring of platform activity and call frequencies.
- **Broadcast System:** Push marketing and operational visual announcements targeted to drivers, riders, or both.
- **Remote Version Control:** Force or recommend app updates dynamically via remote config.

---

## 🔥 Backend & Cloud Architecture

- **Firebase Realtime Database (RTDB):** High-frequency, low-latency sync for live driver coordinates (`liveLocations`) and remote app settings.
- **Cloud Firestore:** Relational/document storage for driver profiles, verification statuses, and call logs.
- **Cloud Functions:** Privileged operations for driver status transitions, data wiping, and admin push notifications.
- **Cloud Storage:** Secure storage for driver KYC documents and broadcast banners.
