# EmoLearnAR

EmoLearnAR is an Android-focused Final Year Project MVP for student engagement monitoring. It uses a Flutter mobile app for the live camera interface and a Python Flask backend for real-time facial emotion recognition.

The AR layer is intentionally lightweight: the app renders emotion text, icons, confidence, scanning guides, and session status over `CameraPreview` using Flutter `Stack` and `Positioned` widgets. It does not use SLAM or a game/AR engine.

## Features

- Android Flutter app with Material 3 UI
- Live camera preview
- Real-time frame upload to Flask
- DeepFace + OpenCV emotion detection
- Emotion categories: `Positive`, `Neutral`, `Confused`, `Negative`
- AR-style overlay on top of camera feed
- Provider state management
- SQLite session and emotion-log storage
- Live analytics dashboard with `fl_chart`
- Session history, JSON and Excel export

## Project Structure

```text
lib/
├── main.dart
├── core/
├── models/
├── services/
├── screens/
├── widgets/
└── routes/

backend/
├── app.py
├── requirements.txt
└── README.md
```

## Backend Setup

Use Python 3.10 or 3.11 for best TensorFlow compatibility.

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python app.py
```

Health check:

```powershell
curl http://192.168.100.76:5000/health
```

Fast UI demo without DeepFace:

```powershell
cd backend
$env:EMOLEARNAR_MOCK="1"
python app.py
```

## Flutter Setup

Install Flutter and Android Studio, then run:

```powershell
flutter pub get
flutter run
```

The default API URL is `http://192.168.100.76:5000`. For a different host, update `baseUrl` in `lib/services/api_service.dart` to your computer LAN IP, for example:

```dart
ApiService(baseUrl: 'http://192.168.100.76:5000')
```

## Emotion Mapping

DeepFace emotions are mapped into the project classes:

| DeepFace | EmoLearnAR |
| --- | --- |
| happy | Positive |
| neutral | Neutral |
| surprise, fear | Confused |
| angry, sad, disgust | Negative |

## Demo Flow

1. Start the Flask backend.
2. Run the Flutter app on Android.
3. Open `Start Monitoring`.
4. Press `Start`.
5. The app captures frames every 1.6 seconds and sends them to `/detect`.
6. The returned emotion appears as an AR overlay.
7. Open the dashboard for live percentages and charts.
8. Stop the session and export the report (JSON or Excel) from the summary screen.

## Notes

- Face detection uses OpenCV Haar Cascade with IoU deduplication, supporting up to 5 faces per frame.
- `android:usesCleartextTraffic="true"` is enabled for local HTTP testing.
- If this project is opened on a machine with Flutter installed, running `flutter create . --platforms=android` can regenerate any missing platform wrapper files without overwriting the existing `lib/` code.
