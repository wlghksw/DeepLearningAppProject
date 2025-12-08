# YOLO 기반 스마트폰 결함 검출 시스템

AI 기반 스마트폰 중고 거래 플랫폼으로, YOLOv8 모델을 활용하여 스마트폰의 외관 결함을 자동으로 검출하고 등급을 판정하는 시스템입니다.

## 프로젝트 개요

이 프로젝트는 **Flutter 모바일 앱**과 **FastAPI 백엔드 서버**로 구성된 풀스택 애플리케이션입니다. 사용자가 스마트폰 사진을 업로드하면 YOLO 딥러닝 모델이 자동으로 결함을 검출하고, 검출 결과를 바탕으로 S/A/B/C/D 등급을 자동 판정합니다.

### 주요 기능

- **AI 기반 결함 검출**: YOLOv8 모델을 사용한 실시간 스마트폰 외관 결함 검출
- **자동 등급 판정**: 검출 결과를 바탕으로 S/A/B/C/D 등급 자동 판정
- **다각도 이미지 분석**: 전면/후면 이미지 분석 지원
- **마켓플레이스**: 등급별 스마트폰 거래 플랫폼
- **대시보드**: 검수 현황 및 통계 시각화
- **모던 UI/UX**: 당근마켓 스타일의 직관적인 사용자 인터페이스

## 프로젝트 구조

```
DeepLearning/
├── flutter_app/              # Flutter 모바일 앱
│   ├── lib/
│   │   ├── screens/          # 화면 컴포넌트
│   │   ├── services/        # API 서비스 (YOLO, Gemini 등)
│   │   ├── providers/       # 상태 관리
│   │   ├── widgets/         # 재사용 가능한 위젯
│   │   └── models/          # 데이터 모델
│   └── pubspec.yaml         # Flutter 의존성
│
├── yolo_server/              # FastAPI 백엔드 서버
│   ├── server.py            # 메인 서버 파일
│   ├── requirements.txt     # Python 의존성
│   └── README.md            # 서버 설정 가이드
│
└── smartphone_ver4_detect2/ # YOLO 모델 파일
    └── best.pt              # 학습된 YOLO 모델
```

## 시작하기

### 사전 요구사항

- **Python 3.8+**
- **Flutter SDK 3.5+**
- **Node.js** (Firebase CLI용, 선택사항)

### 1. YOLO 서버 설정

```bash
# 서버 디렉토리로 이동
cd yolo_server

# 가상환경 생성 (선택사항)
python3 -m venv venv
source venv/bin/activate  # macOS/Linux
# 또는
venv\Scripts\activate     # Windows

# 의존성 설치
pip install -r requirements.txt

# 서버 실행
python3 server.py
```

서버는 기본적으로 `http://localhost:8000`에서 실행됩니다.

### 2. Flutter 앱 설정

```bash
# Flutter 앱 디렉토리로 이동
cd flutter_app

# 의존성 설치
flutter pub get

# 앱 실행
flutter run
```

#### 플랫폼별 실행

```bash
# 웹 브라우저
flutter run -d chrome

# iOS 시뮬레이터
flutter run -d ios

# Android 에뮬레이터
flutter run -d android

# macOS
flutter run -d macos
```

### 3. YOLO 서버 URL 설정

Flutter 앱에서 YOLO 서버에 연결하려면 `lib/services/yolo_service.dart` 파일의 `_baseUrl`을 수정하세요:

```dart
static const String _baseUrl = 'http://localhost:8000';
```

**참고**: 모바일 디바이스에서 실행하는 경우, `localhost` 대신 실제 서버 IP 주소를 사용해야 합니다.

## API 문서

### Health Check

```http
GET /health
```

서버 상태 및 모델 로드 상태를 확인합니다.

**응답 예시:**

```json
{
  "status": "ok",
  "model_loaded": true,
  "model_path": "/path/to/best.pt"
}
```

### 스마트폰 검사

```http
POST /api/inspect
Content-Type: application/json
```

스마트폰 이미지를 분석하고 등급을 판정합니다.

**요청 본문:**

```json
{
  "images": {
    "front": "base64_encoded_image_string",
    "back": "base64_encoded_image_string"
  },
  "battery_health": 85
}
```

**응답 예시:**

```json
{
  "grade": "A",
  "damages": [
    {
      "type": "scratch",
      "location": "front",
      "severity": "minor"
    }
  ],
  "analysis": {
    "front": {
      "detections": [...],
      "count": 2
    }
  },
  "visualization": {
    "front": "base64_encoded_image_with_annotations"
  }
}
```

## 등급 판정 시스템

시스템은 다음 기준에 따라 스마트폰 등급을 자동으로 판정합니다:

### 등급 기준

- **S등급**: 손상 없음 (damage_score = 0)
- **A등급**: 경미한 손상 (damage_score ≤ 2)
- **B등급**: 보통 손상 (damage_score ≤ 8)
- **C등급**: 심각한 손상 (damage_score ≤ 15)
- **D등급**: 매우 심각한 손상 (severe 손상 존재 또는 damage_score > 15)

### 가중치 시스템

- **위치 가중치**:

  - 전면(front): 3.0
  - 후면(back): 2.0
  - 기타: 1.0

- **심각도 가중치**:
  - severe: 2.0
  - moderate: 1.0
  - minor: 0.5
  - none: 0.0

### 심각도 판정 기준

- **severe**:

  - crack, broken, shatter 등 심각한 키워드 포함
  - 검출 개수 ≥ 5개
  - 신뢰도 > 0.6이고 검출 개수 ≥ 3개

- **moderate**:

  - 신뢰도 > 0.3

- **minor**:
  - 그 외의 경우

## 기술 스택

### 백엔드

- **FastAPI**: 고성능 Python 웹 프레임워크
- **YOLOv8 (Ultralytics)**: 객체 검출 딥러닝 모델
- **PIL (Pillow)**: 이미지 처리
- **NumPy**: 수치 연산

### 프론트엔드

- **Flutter**: 크로스 플랫폼 모바일 앱 프레임워크
- **Provider**: 상태 관리
- **GoRouter**: 라우팅
- **Firebase**: 백엔드 서비스 (선택사항)
- **Google Generative AI**: AI 기능 (선택사항)

### 모델

- **YOLOv8 Segmentation**: 스마트폰 결함 검출 모델
- **학습 데이터**: smartphone_ver4_detect2 데이터셋
- **모델 파일**: `smartphone_ver4_detect2/best.pt`

## 주요 의존성

### Python (yolo_server/requirements.txt)

```
fastapi
uvicorn
ultralytics
pillow
numpy
pydantic
```

### Flutter (flutter_app/pubspec.yaml)

```yaml
provider: ^6.1.2
go_router: ^14.0.0
http: ^1.2.0
image_picker: ^1.0.7
firebase_core: ^3.5.0
google_generative_ai: ^0.4.0
```

## 주요 화면

### 1. 대시보드

- 실시간 검수 현황
- 통계 및 요약 정보
- 최근 검수 내역

### 2. 검수 요청

- 스마트폰 정보 입력
- 전면/후면 이미지 업로드
- 배터리 건강도 입력
- AI 검수 실행

### 3. 마켓플레이스

- 등급별 스마트폰 목록
- 상세 정보 및 검수 결과 확인
- 거래 기능

## 검출 가능한 결함 유형

YOLO 모델이 검출할 수 있는 결함 유형:

- **oil**: 오일 얼룩
- **scratch**: 스크래치
- **stain**: 얼룩
- **crack**: 균열

각 결함은 바운딩 박스와 마스크로 정확히 표시됩니다.

## 개발 가이드

### 모델 변경

다른 YOLO 모델을 사용하려면 `yolo_server/server.py`의 `MODEL_PATH`를 수정하세요:

```python
MODEL_PATH = os.path.join(
    os.path.dirname(__file__),
    "../your_model_directory/best.pt"
)
```

### 예측 파라미터 조정

`yolo_server/server.py`의 `PREDICT_CONFIG`를 수정하여 모델 예측 파라미터를 조정할 수 있습니다:

```python
PREDICT_CONFIG = {
    "conf": 0.4,      # 신뢰도 임계값
    "augment": False,  # 데이터 증강
    "imgsz": 640,     # 이미지 크기
    "iou": 0.7,       # IoU 임계값
    "device": "cpu",  # 디바이스 (cpu/cuda)
}
```

## 문제 해결

### 서버가 시작되지 않는 경우

1. 모델 파일 경로 확인: `smartphone_ver4_detect2/best.pt` 파일이 존재하는지 확인
2. Python 버전 확인: Python 3.8 이상 필요
3. 의존성 설치 확인: `pip install -r requirements.txt` 실행

### Flutter 앱이 서버에 연결되지 않는 경우

1. 서버가 실행 중인지 확인: `http://localhost:8000/health` 접속 테스트
2. CORS 설정 확인: 서버의 CORS 미들웨어가 올바르게 설정되어 있는지 확인
3. 네트워크 설정: 모바일 디바이스에서는 `localhost` 대신 실제 IP 주소 사용
