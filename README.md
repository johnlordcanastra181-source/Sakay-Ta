# Sakay Ta

"Sakay Ta! Abot ta sa destinasyon nato." A responsive Flutter UI prototype for a Philippine Habal-Habal and Tricycle ride-hailing app.

## Included screens

- Login and role/language controls
- Passenger dashboard, profile, trip tracking, and ride history
- Driver registration, dashboard, wallet, performance, and heading-home route

## Run

```bash
flutter pub get
flutter run
```

## Project tooling policy

Sakay Ta application code and maintained repository utilities use Dart. Check
that no project-owned Python artifact or executable command has been introduced:

```bash
dart run tool/verify_no_python.dart
```

Flutter may generate `ios/Flutter/ephemeral/flutter_lldb_helper.py` for LLDB
debugging. That SDK-generated file is not Sakay Ta application or migration
logic and should not be edited.

## Google Maps setup

The passenger Home screen now uses a live Google Map with GPS, destination search,
reverse geocoding, and route rendering.

### 1) Enable Google Maps Platform APIs

Enable these APIs in your Google Cloud project:

- Maps SDK for Android
- Maps SDK for iOS
- Maps JavaScript API
- Places API
- Routes API
- Geocoding API

### 2) Add your API key

#### Android
Add this line to `android/local.properties`:

```properties
GOOGLE_MAPS_API_KEY=YOUR_REAL_GOOGLE_MAPS_KEY
```

#### iOS
Replace the placeholder value in `ios/Flutter/Maps.xcconfig`:

```xcconfig
GOOGLE_MAPS_API_KEY=YOUR_REAL_GOOGLE_MAPS_KEY
```

#### Web
Replace the placeholder value in `web/maps_api_key.js`:

```js
window.GOOGLE_MAPS_API_KEY = 'YOUR_REAL_GOOGLE_MAPS_KEY';
```

### 3) Run with Dart defines for Google service calls

Mobile:

```bash
flutter run --dart-define=GOOGLE_MAPS_API_KEY=YOUR_REAL_GOOGLE_MAPS_KEY
```

Web:

```bash
flutter run -d chrome --dart-define=WEB_GOOGLE_MAPS_API_KEY=YOUR_REAL_GOOGLE_MAPS_KEY
```

### 4) Postman testing

The project now includes:

- `postman/specs/google-maps-routing.openapi.yaml`
- `postman/environments/google-maps.local.yaml`
- `postman/collections/Google Maps Support/`

Set `googleMapsApiKey` in the Postman environment before sending the Google Maps requests.

The app uses Flutter's built-in Material icon set and has no third-party runtime dependencies.
