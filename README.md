# AI 기반 스마트폰 품질 판별 시스템

YOLO 딥러닝 모델을 활용한 스마트폰 손상 검출 및 등급 판별 시스템입니다.

## 프로젝트 개요

이 프로젝트는 Flutter 모바일 앱과 Python FastAPI 서버로 구성된 AI 기반 스마트폰 검사 시스템입니다. YOLO v8 Segmentation 모델을 사용하여 스마트폰 이미지에서 손상을 자동으로 검출하고, 가중치 기반 점수 시스템으로 등급을 산정합니다.

## 시스템 구조

```
┌─────────────────┐
│  Flutter 앱     │
│  (클라이언트)    │
└────────┬────────┘
         │ HTTP POST
         │ (Base64 이미지)
         ↓
┌─────────────────┐
│  FastAPI 서버   │
│  (YOLO 서버)    │
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│  YOLO 모델      │
│  (smartphone_   │
│   ver3/best.pt) │
└─────────────────┘
```

## 전체 플로우

```
[Flutter 앱]
    ↓
1. 사용자가 전면/후면 이미지 업로드
    ↓
2. 이미지를 base64로 인코딩
    ↓
3. HTTP POST 요청 → YOLO 서버 (http://localhost:8000/api/inspect)
    ↓
[YOLO 서버]
    ↓
4. Base64 디코딩 → PIL Image 변환
    ↓
5. YOLO 모델로 각 이미지 분석 (conf=0.1, iou=0.5)
    ↓
6. 검출 결과 파싱 (바운딩 박스, 클래스, 신뢰도, 마스크)
    ↓
7. 심각도 결정 (severe/moderate/minor)
    ↓
8. 손상 점수 계산 (가중치 기반)
    ↓
9. 등급 결정 (S/A/B/C/D)
    ↓
10. JSON 응답 반환 (시각화 이미지 포함)
    ↓
[Flutter 앱]
    ↓
11. 결과 화면 표시 (등급, 손상 목록, 시각화 이미지)
```

## 핵심 기능

### 1. YOLO 모델 검출

**모델 정보**:
- 모델 경로: `YOLO_TRAINING_RESULTS/smartphone_ver3/weights/best.pt`
- 모델 타입: YOLOv8 Segmentation (세그멘테이션)
- 검출 가능한 클래스:
  - `oil` (오일/기름 얼룩)
  - `scratch` (스크래치)
  - `stain` (얼룩)

**검출 과정**:
```python
# YOLO 모델 실행
results = model(image, conf=0.1, iou=0.5)

# 각 검출 결과에서 추출
- 바운딩 박스 좌표 (x1, y1, x2, y2)
- 신뢰도 (confidence: 0.0 ~ 1.0)
- 클래스 ID 및 이름
- 세그멘테이션 마스크 (있는 경우)
```

### 2. 심각도 판정

```python
def determine_severity(damage_count, confidence, class_name):
    # 크랙(crack)이나 심각한 손상은 무조건 severe
    if "crack" in class_name.lower():
        return "severe"
    
    # 검출된 손상이 많으면 severe (5개 이상)
    if damage_count >= 5:
        return "severe"
    
    # 신뢰도가 높고 손상이 많으면 severe
    if confidence > 0.6 and damage_count >= 3:
        return "severe"
    
    # 신뢰도가 중간 이상이면 moderate
    elif confidence > 0.3:
        return "moderate"
    
    # 그 외는 minor
    else:
        return "minor"
```

**심각도 기준**:
- **severe**: 크랙 검출 OR 손상 5개 이상 OR (신뢰도 > 60% AND 손상 3개 이상)
- **moderate**: 신뢰도 > 30%
- **minor**: 신뢰도 ≤ 30%

### 3. 가중치 기반 점수 계산

**가중치 정의**:

| 항목 | 가중치 | 설명 |
|------|--------|------|
| **위치별** | | |
| 화면 손상 (front) | 3.0 | 가장 중요 |
| 후면 손상 (back) | 2.0 | 중간 중요도 |
| **심각도별** | | |
| severe | 2.0 | 심각한 손상 |
| moderate | 1.0 | 보통 손상 |
| minor | 0.5 | 경미한 손상 |

**점수 계산 공식**:
```
손상 점수 = Σ(위치 가중치 × 심각도 가중치)
```

**예시**:
- 전면에 minor 스크래치 1개: 3.0 × 0.5 = **1.5점**
- 후면에 moderate 오일 얼룩 1개: 2.0 × 1.0 = **2.0점**
- 전면에 severe 손상 1개: 3.0 × 2.0 = **6.0점**
- 총 손상 점수: 1.5 + 2.0 + 6.0 = **9.5점**

### 4. 등급 결정

```python
# severe 손상이 1개라도 있으면 자동으로 D등급
if severe_count > 0:
    return "D"

# 손상 점수 기반 등급 결정
if damage_score == 0:
    return "S"  # 최상급: 손상 없음
elif damage_score <= 2:
    return "A"  # 우수: 미세한 손상
elif damage_score <= 8:
    return "B"  # 양호: 적당한 손상
elif damage_score <= 15:
    return "C"  # 보통: 많은 손상
else:
    return "D"  # 미흡: 심각한 손상
```

**등급 기준표**:

| 등급 | 손상 점수 범위 | 설명 | 예시 |
|------|---------------|------|------|
| **S** | 0점 | 손상 없음 | 새것과 같은 상태 |
| **A** | 0 < 점수 ≤ 2 | 미세한 손상 | 전면 minor 1개 (1.5점) |
| **B** | 2 < 점수 ≤ 8 | 적당한 손상 | 전면 minor 2개 (3.0점) + 후면 moderate 1개 (2.0점) = 5.0점 |
| **C** | 8 < 점수 ≤ 15 | 많은 손상 | 전면 severe 1개 (6.0점) + 후면 moderate 2개 (4.0점) = 10.0점 |
| **D** | 점수 > 15 OR severe 1개 이상 | 심각한 손상 | 전면 severe 2개 이상 (12.0점+) |

## 프로젝트 구조

```
DeepLearning/
├── flutter_app/              # Flutter 모바일 앱
│   ├── lib/
│   │   ├── main.dart
│   │   ├── screens/
│   │   │   └── inspection_screen.dart  # 메인 검사 화면
│   │   ├── services/
│   │   │   ├── yolo_service.dart        # YOLO 서버 통신
│   │   │   ├── gemini_service.dart      # Gemini AI 통신
│   │   │   └── inspection_service.dart  # 검사 서비스 추상화
│   │   ├── models/
│   │   │   └── inspection_report.dart   # 검사 결과 모델
│   │   └── theme/
│   │       └── app_theme.dart
│   └── pubspec.yaml
│
├── yolo_server/              # Python FastAPI 서버
│   ├── server.py             # 메인 서버 코드
│   ├── requirements.txt      # Python 의존성
│   ├── start_server.sh       # 서버 실행 스크립트
│   └── check_model_classes.py # 모델 클래스 확인
│
└── YOLO_TRAINING_RESULTS/     # YOLO 모델 학습 결과
    └── smartphone_ver3/
        ├── weights/
        │   └── best.pt        # 학습된 모델 (사용 중)
        ├── args.yaml          # 학습 설정
        └── results.csv        # 학습 결과
```

## 시작하기

### 1. YOLO 서버 실행

```bash
cd yolo_server

# 의존성 설치
pip install -r requirements.txt

# 서버 실행
python3 server.py
# 또는
./start_server.sh
```

서버가 `http://localhost:8000`에서 실행됩니다.

### 2. Flutter 앱 실행

```bash
cd flutter_app

# 의존성 설치
flutter pub get

# 앱 실행 (Chrome)
flutter run -d chrome

# 앱 실행 (iOS)
flutter run -d ios

# 앱 실행 (Android)
flutter run -d android
```

## API 엔드포인트

### Health Check
```
GET http://localhost:8000/health
```

**응답**:
```json
{
  "status": "ok",
  "model_loaded": true
}
```

### 스마트폰 검사
```
POST http://localhost:8000/api/inspect
```

**요청**:
```json
{
  "images": {
    "front": "base64_encoded_image_string",
    "back": "base64_encoded_image_string"
  }
}
```

**응답**:
```json
{
  "grade": "B",
  "summary": "총 3개 결함 검출, 등급: B",
  "batteryHealth": 0,
  "screenCondition": "화면 상태: 2개 결함 검출",
  "backCondition": "후면 상태: 1개 결함 검출",
  "frameCondition": "프레임 상태: 양호",
  "overallAssessment": "양호한 상태입니다. 일부 사용 흔적이 보입니다.",
  "damages": [
    {
      "type": "scratch",
      "location": "front - bbox: [100, 200, 300, 400]",
      "severity": "minor"
    }
  ],
  "visualizedImages": {
    "front": "base64_encoded_visualized_image",
    "back": "base64_encoded_visualized_image"
  }
}
```

## 검출 결과 시각화

서버는 검출된 손상을 이미지에 시각화하여 반환합니다:

- **초록 박스**: `scratch` (스크래치)
- **빨강 박스**: `oil` (오일 얼룩)
- **파랑 박스**: `stain` (얼룩)

각 박스에는 클래스명과 신뢰도가 표시됩니다.

## 설정

### YOLO 검출 임계값

`yolo_server/server.py`에서 조정 가능:

```python
# conf: 신뢰도 임계값 (낮을수록 더 많은 검출)
# iou: 겹치는 박스 제거 임계값
results = model(image, conf=0.1, iou=0.5)
```

### 등급 기준 조정

`yolo_server/server.py`의 `calculate_grade()` 함수에서 조정:

```python
# 등급 임계값 수정
if damage_score <= 2:    # A등급 기준
    return "A"
elif damage_score <= 8:  # B등급 기준
    return "B"
# ...
```

## 문제 해결

### 모델이 손상을 검출하지 못하는 경우

1. **임계값 확인**: `conf=0.1`로 설정되어 있는지 확인
2. **모델 클래스 확인**: 모델이 검출할 수 있는 클래스 확인
   ```bash
   cd yolo_server
   python3 check_model_classes.py
   ```
3. **서버 로그 확인**: 검출 과정이 로그에 출력됨

### 이미지 업로드가 안 되는 경우

1. **브라우저 권한**: 파일 접근 권한 확인
2. **에러 로그**: 브라우저 콘솔(F12)에서 에러 확인
3. **웹 호환성**: Chrome에서 테스트 권장

## 주요 파일 설명

- `yolo_server/server.py`: FastAPI 서버, YOLO 모델 통합, 등급 계산 로직
- `flutter_app/lib/screens/inspection_screen.dart`: 메인 검사 화면
- `flutter_app/lib/services/yolo_service.dart`: YOLO 서버 통신
- `YOLO_등급판별_로직_설명.md`: 상세 로직 설명 문서

## 데이터 흐름

```
이미지 업로드
    ↓
Base64 인코딩
    ↓
HTTP POST 요청
    ↓
서버 디코딩
    ↓
YOLO 모델 분석
    ↓
손상 검출 (바운딩 박스, 클래스, 신뢰도)
    ↓
심각도 결정
    ↓
손상 점수 계산 (가중치 적용)
    ↓
등급 결정 (S/A/B/C/D)
    ↓
시각화 이미지 생성
    ↓
JSON 응답 반환
    ↓
Flutter 앱 표시
```

## UI 특징

- **당근마켓 스타일**: 깔끔하고 심플한 디자인
- **실시간 검출 결과**: 검출된 손상 위치를 이미지에 표시
- **등급별 색상**: S(초록), A(파랑), B(주황), C(주황진한색), D(빨강)

## 성능

- **검출 속도**: 이미지당 약 1-3초 (GPU 사용 시 더 빠름)
- **정확도**: 모델 학습 데이터에 따라 다름
- **현재 모델**: smartphone_ver3 (60 epochs 학습)

## 향후 개선 사항

1. **모델 정확도 향상**
   - 더 많은 학습 데이터
   - 크랙(crack) 클래스 추가
   - 데이터 증강(Data Augmentation) 강화

2. **등급 판정 개선**
   - 실제 검수 데이터 기반 가중치 최적화
   - 등급 기준 임계값 검증 및 조정

3. **기능 추가**
   - 다중 각도 이미지 분석
   - 손상 크기 계산 (마스크 영역 활용)
   - 검사 이력 저장 및 관리

4. **성능 최적화**
   - 모델 양자화 (Quantization)
   - 배치 처리 지원
   - 캐싱 시스템

## 라이선스

이 프로젝트는 교육 및 연구 목적으로 개발되었습니다.

## 기여

버그 리포트나 기능 제안은 GitHub Issues를 통해 제출해주세요.

---

**참고**: 상세한 로직 설명은 `YOLO_등급판별_로직_설명.md` 파일을 참고하세요.

