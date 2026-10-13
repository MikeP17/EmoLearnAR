# EmoLearnAR Backend

Flask API for real-time facial emotion recognition. It accepts a camera frame and returns one of the project emotion classes:

- `Positive`
- `Neutral`
- `Confused`
- `Negative`

## Setup

Use Python 3.10 or 3.11 for the smoothest TensorFlow and DeepFace setup.

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python app.py
```

The API runs on `http://0.0.0.0:5000`.

The Flutter app connects to the backend at `http://192.168.100.76:5000` by default.
To use a different host, update `baseUrl` in `lib/services/api_service.dart`.

## Demo Mock Mode

If the Python AI dependencies are not installed yet, you can still test the Flutter camera and overlay loop:

```powershell
$env:EMOLEARNAR_MOCK="1"
python app.py
```

## API

### `GET /health`

Returns backend readiness and whether DeepFace is available.

### `POST /detect`

Send multipart form data with an image field named `image`, or send raw JPEG bytes as the request body.

Response (multi-face, up to 5 faces):

```json
{
  "faces": [
    {
      "id": 1,
      "emotion": "Positive",
      "confidence": 0.91,
      "x": 120,
      "y": 80,
      "w": 160,
      "h": 200
    }
  ]
}
```

Returns `{"faces": []}` when no faces are detected.
