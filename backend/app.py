import os
import random
from typing import Any

import cv2
import numpy as np
from flask import Flask, jsonify, request

try:
    from flask_cors import CORS
except ImportError:
    CORS = None

try:
    from deepface import DeepFace
except ImportError:
    DeepFace = None

try:
    import mediapipe as mp
except ImportError:
    mp = None


app = Flask(__name__)
if CORS is not None:
    CORS(app)

CASCADE_PATH = cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
FACE_CASCADE = cv2.CascadeClassifier(CASCADE_PATH)

MAX_FACES = 5
MAX_PROCESSING_WIDTH = 720
MIN_FACE_SIZE = 48
MIN_FACE_AREA_RATIO = 0.008
MIN_MEDIAPIPE_CONFIDENCE = 0.62
MIN_HAAR_DETECTION_SCORE = 1.8
MIN_BLUR_SCORE = 28.0
MIN_EMOTION_CONFIDENCE = 0.32
FACE_PADDING_RATIO = 0.22

EMOTION_MAP = {
    "happy": "Positive",
    "neutral": "Neutral",
    "surprise": "Confused",
    "fear": "Confused",
    "angry": "Negative",
    "sad": "Negative",
    "disgust": "Negative",
}


@app.get("/health")
def health():
    return jsonify(
        {
            "status": "ok",
            "deepface_loaded": DeepFace is not None,
            "mediapipe_loaded": mp is not None,
            "mock_mode": _mock_mode_enabled(),
            "max_faces": MAX_FACES,
        }
    )


@app.post("/detect")
def detect():
    image = _read_image_from_request()
    if image is None:
        return jsonify({"error": "Missing image frame"}), 400

    if _mock_mode_enabled():
        return jsonify({"faces": _mock_faces(image)})

    if DeepFace is None:
        return jsonify({"error": "DeepFace is not installed. Run pip install -r requirements.txt"}), 503

    candidates = _detect_ranked_faces(image)
    if not candidates:
        print(f"[DETECT] No faces found | image shape={image.shape}")
        return jsonify({"faces": []})

    faces = []
    rejected_low_confidence = 0
    for candidate in candidates[:MAX_FACES]:
        try:
            analysis = DeepFace.analyze(
                img_path=candidate["crop"],
                actions=["emotion"],
                enforce_detection=False,
                detector_backend="opencv",
                silent=True,
            )
            result = analysis[0] if isinstance(analysis, list) else analysis
            emotion, confidence = _map_deepface_result(result)
            if confidence < MIN_EMOTION_CONFIDENCE:
                rejected_low_confidence += 1
                continue

            x, y, w, h = candidate["box"]
            print(
                f"[EMOTION] face #{len(faces)+1} → {emotion} ({confidence:.3f}) | "
                f"raw: happy={result.get('emotion',{}).get('happy',0):.1f} "
                f"neutral={result.get('emotion',{}).get('neutral',0):.1f} "
                f"surprise={result.get('emotion',{}).get('surprise',0):.1f} "
                f"fear={result.get('emotion',{}).get('fear',0):.1f} "
                f"angry={result.get('emotion',{}).get('angry',0):.1f} "
                f"sad={result.get('emotion',{}).get('sad',0):.1f} "
                f"disgust={result.get('emotion',{}).get('disgust',0):.1f}"
            )
            faces.append(
                {
                    "id": len(faces) + 1,
                    "emotion": emotion,
                    "confidence": confidence,
                    "x": int(x),
                    "y": int(y),
                    "w": int(w),
                    "h": int(h),
                }
            )
        except Exception:
            continue

    if faces:
        status = "face_detected"
    elif rejected_low_confidence > 0:
        status = "low_confidence"
    else:
        status = "no_face"

    return jsonify({"faces": faces, "status": status})


def _read_image_from_request():
    if "image" in request.files:
        data = request.files["image"].read()
    else:
        data = request.get_data()

    if not data:
        return None

    buffer = np.frombuffer(data, dtype=np.uint8)
    return cv2.imdecode(buffer, cv2.IMREAD_COLOR)


def _resize_for_detection(image):
    height, width = image.shape[:2]
    if width <= MAX_PROCESSING_WIDTH:
        return image, 1.0

    scale = MAX_PROCESSING_WIDTH / width
    resized = cv2.resize(
        image,
        (MAX_PROCESSING_WIDTH, int(height * scale)),
        interpolation=cv2.INTER_AREA,
    )
    return resized, scale


def _detect_ranked_faces(image):
    mediapipe = _detect_faces_mediapipe(image)
    if mediapipe:
        print(
            f"[DETECT] MediaPipe found {len(mediapipe)} face(s) | "
            f"top score={mediapipe[0]['detection_score']:.3f}"
        )
        deduped = _deduplicate_by_iou(mediapipe)
        deduped.sort(key=lambda item: item["rank_score"], reverse=True)
        return deduped[:MAX_FACES]

    haar = _detect_faces_haar(image)
    if haar:
        print(
            f"[DETECT] Haar fallback found {len(haar)} face(s) | "
            f"top score={haar[0]['detection_score']:.3f}"
        )

    deduped = _deduplicate_by_iou(haar)
    deduped.sort(key=lambda item: item["rank_score"], reverse=True)
    return deduped[:MAX_FACES]


def _detect_faces_mediapipe(image):
    if mp is None:
        return []

    resized, scale = _resize_for_detection(image)
    rgb = cv2.cvtColor(resized, cv2.COLOR_BGR2RGB)
    image_height, image_width = resized.shape[:2]
    image_area = image_height * image_width
    candidates = []

    with mp.solutions.face_detection.FaceDetection(
        model_selection=0,
        min_detection_confidence=MIN_MEDIAPIPE_CONFIDENCE,
    ) as detector:
        results = detector.process(rgb)

    for detection in results.detections or []:
        detection_score = float(detection.score[0]) if detection.score else 0.0
        if detection_score < MIN_MEDIAPIPE_CONFIDENCE:
            continue

        bbox = detection.location_data.relative_bounding_box
        x = int(max(0, bbox.xmin * image_width))
        y = int(max(0, bbox.ymin * image_height))
        w = int(min(image_width - x, bbox.width * image_width))
        h = int(min(image_height - y, bbox.height * image_height))
        if w <= 0 or h <= 0:
            continue

        candidate = _build_candidate(
            image=image,
            resized=resized,
            scale=scale,
            box=(x, y, w, h),
            image_area=image_area,
            detection_score=detection_score,
            detector_weight=1.0,
        )
        if candidate is not None:
            candidates.append(candidate)

    candidates.sort(
        key=lambda item: (
            item["detection_score"],
            item["area"],
            item["clarity"],
        ),
        reverse=True,
    )
    return candidates


def _detect_faces_haar(image):
    resized, scale = _resize_for_detection(image)
    gray = cv2.cvtColor(resized, cv2.COLOR_BGR2GRAY)
    equalized = cv2.equalizeHist(gray)

    faces, reject_levels, level_weights = FACE_CASCADE.detectMultiScale3(
        equalized,
        scaleFactor=1.05,
        minNeighbors=4,
        minSize=(MIN_FACE_SIZE, MIN_FACE_SIZE),
        outputRejectLevels=True,
    )

    if len(faces) == 0:
        return []

    image_area = resized.shape[0] * resized.shape[1]
    candidates = []
    for face, detection_score in zip(faces, level_weights):
        x, y, w, h = [int(value) for value in face]
        if detection_score < MIN_HAAR_DETECTION_SCORE:
            continue
        candidate = _build_candidate(
            image=image,
            resized=resized,
            scale=scale,
            box=(x, y, w, h),
            image_area=image_area,
            detection_score=float(detection_score),
            detector_weight=0.72,
        )
        if candidate is not None:
            candidates.append(candidate)

    candidates.sort(
        key=lambda item: (
            item["detection_score"],
            item["area"],
            item["clarity"],
        ),
        reverse=True,
    )
    return candidates


def _build_candidate(
    image,
    resized,
    scale,
    box,
    image_area,
    detection_score,
    detector_weight,
):
    x, y, w, h = box
    area = w * h
    area_ratio = area / image_area
    if area_ratio < MIN_FACE_AREA_RATIO:
        return None
    aspect_ratio = w / max(h, 1)
    if aspect_ratio < 0.62 or aspect_ratio > 1.55:
        return None

    image_height, image_width = resized.shape[:2]
    edge_margin_x = image_width * 0.015
    edge_margin_y = image_height * 0.015
    touches_edge = (
        x <= edge_margin_x
        or y <= edge_margin_y
        or x + w >= image_width - edge_margin_x
        or y + h >= image_height - edge_margin_y
    )
    if touches_edge and area_ratio < 0.035:
        return None

    crop = _crop_with_padding(resized, x, y, w, h)
    if crop.size == 0:
        return None

    clarity = _clarity_score(crop)
    if clarity < MIN_BLUR_SCORE:
        return None

    original_box = _scale_box_to_original((x, y, w, h), scale, image.shape)
    original_crop = _crop_with_padding(image, *original_box)
    rank_score = (
        float(detection_score) * 0.6 * detector_weight
        + min(area_ratio * 100, 2.0) * 0.25
        + min(clarity / 240, 1.0) * 0.15
    )

    return {
        "box": original_box,
        "crop": original_crop,
        "rank_score": rank_score,
        "detection_score": float(detection_score),
        "area": int(original_box[2] * original_box[3]),
        "clarity": clarity,
    }


def _iou(box1, box2):
    x1 = max(box1[0], box2[0])
    y1 = max(box1[1], box2[1])
    x2 = min(box1[2], box2[2])
    y2 = min(box1[3], box2[3])
    if x2 <= x1 or y2 <= y1:
        return 0.0
    inter = (x2 - x1) * (y2 - y1)
    area1 = (box1[2] - box1[0]) * (box1[3] - box1[1])
    area2 = (box2[2] - box2[0]) * (box2[3] - box2[1])
    return inter / (area1 + area2 - inter + 1e-8)


def _deduplicate_by_iou(candidates, iou_threshold=0.50):
    if len(candidates) <= 1:
        return candidates
    sorted_candidates = sorted(candidates, key=lambda c: c["rank_score"], reverse=True)
    keep = []
    for candidate in sorted_candidates:
        x, y, w, h = candidate["box"]
        box1 = (x, y, x + w, y + h)
        is_dup = False
        for kept in keep:
            kx, ky, kw, kh = kept["box"]
            box2 = (kx, ky, kx + kw, ky + kh)
            if _iou(box1, box2) > iou_threshold:
                is_dup = True
                break
        if not is_dup:
            keep.append(candidate)
    return keep


def _crop_with_padding(image, x, y, w, h):
    pad = int(max(w, h) * FACE_PADDING_RATIO)
    x1 = max(int(x) - pad, 0)
    y1 = max(int(y) - pad, 0)
    x2 = min(int(x + w) + pad, image.shape[1])
    y2 = min(int(y + h) + pad, image.shape[0])
    return image[y1:y2, x1:x2]


def _scale_box_to_original(box, scale, original_shape):
    x, y, w, h = box
    if scale == 1.0:
        return x, y, w, h

    original_height, original_width = original_shape[:2]
    inv = 1 / scale
    ox = int(round(x * inv))
    oy = int(round(y * inv))
    ow = int(round(w * inv))
    oh = int(round(h * inv))
    ox = max(0, min(ox, original_width - 1))
    oy = max(0, min(oy, original_height - 1))
    ow = max(1, min(ow, original_width - ox))
    oh = max(1, min(oh, original_height - oy))
    return ox, oy, ow, oh


def _clarity_score(crop):
    gray = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY)
    return float(cv2.Laplacian(gray, cv2.CV_64F).var())


def _map_deepface_result(result: dict[str, Any]):
    scores = result.get("emotion", {}) or {}
    normalized = {
        key.lower(): max(0.0, min(float(value) / 100, 1.0))
        for key, value in scores.items()
    }

    happy = normalized.get("happy", 0.0)
    neutral = normalized.get("neutral", 0.0)
    surprise = normalized.get("surprise", 0.0)
    fear = normalized.get("fear", 0.0)
    angry = normalized.get("angry", 0.0)
    sad = normalized.get("sad", 0.0)
    disgust = normalized.get("disgust", 0.0)

    # Weighted max+mean to eliminate the statistical bias
    # of max(3 scores) vs happy(1 score).
    # More sub-emotions → more weight on the mean so each
    # category is fairly comparable.
    negative_scores = [angry, sad, disgust]
    max_neg = max(negative_scores)
    mean_neg = sum(negative_scores) / 3
    negative = 0.6 * max_neg + 0.4 * mean_neg

    # When smiling, DeepFace often misreads open mouth as surprise.
    # Suppress surprise proportionally to avoid false Confused detections.
    if happy > 0.30:
        surprise *= max(0.25, 1.0 - happy)

    confused_scores = [surprise, fear]
    max_cnf = max(confused_scores)
    mean_cnf = sum(confused_scores) / 2
    confused = 0.7 * max_cnf + 0.3 * mean_cnf

    category_scores = {
        "Positive": happy,
        "Neutral": neutral,
        "Confused": confused,
        "Negative": negative,
    }
    best_category = max(category_scores, key=category_scores.get)
    best_score = category_scores[best_category]

    CONFIDENCE_FLOOR = 0.35
    if best_score >= CONFIDENCE_FLOOR:
        return best_category, round(best_score, 3)

    return "Neutral", round(neutral, 3)


def _mock_faces(image):
    height, width = image.shape[:2]
    emotions = ["Positive", "Neutral", "Confused", "Negative"]
    boxes = [
        (0.28, 0.26, 0.16),
        (0.54, 0.24, 0.15),
        (0.42, 0.48, 0.14),
    ]
    faces = []
    for index, (cx, cy, size) in enumerate(boxes, start=1):
        face_size = int(min(width, height) * size)
        x = int(width * cx - face_size / 2)
        y = int(height * cy - face_size / 2)
        faces.append(
            {
                "id": index,
                "emotion": random.choice(emotions),
                "confidence": round(random.uniform(0.72, 0.96), 2),
                "x": max(0, x),
                "y": max(0, y),
                "w": face_size,
                "h": face_size,
            }
        )
    return faces[:MAX_FACES]


def _mock_mode_enabled():
    return os.getenv("EMOLEARNAR_MOCK", "0").lower() in {"1", "true", "yes"}


if __name__ == "__main__":
    port = int(os.getenv("PORT", "5000"))
    app.run(host="0.0.0.0", port=port, threaded=True)
