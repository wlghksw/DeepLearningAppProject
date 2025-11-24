# YOLO 스마트폰 검사 서버

Flutter 앱에서 사용할 수 있는 YOLO 모델 서버입니다.

## 설치

```bash
cd yolo_server
pip install -r requirements.txt
```

## 실행

```bash
python3 server.py
```

**참고**: macOS에서는 `python` 대신 `python3`를 사용하세요.

서버가 `http://localhost:8000`에서 실행됩니다.

## API 엔드포인트

### Health Check
```
GET /health
```

### 스마트폰 검사
```
POST /api/inspect
Content-Type: application/json

{
  "images": {
    "front": "base64_encoded_image",
    "back": "base64_encoded_image",
    "left": "base64_encoded_image",
    "right": "base64_encoded_image"
  },
  "battery_health": 85
}
```

## Flutter 앱 설정

Flutter 앱에서 YOLO 서버 URL을 설정하려면:

```bash
# 환경 변수로 설정
export YOLO_API_URL="http://localhost:8000"
flutter run

# 또는 코드에서 직접 수정
# lib/services/yolo_service.dart의 _baseUrl 변경
```

## 모델 경로

기본 모델 경로: `../YOLO_TRAINING_RESULTS/smartphone_ver3/weights/best.pt`

다른 모델을 사용하려면 `server.py`의 `MODEL_PATH`를 수정하세요.

