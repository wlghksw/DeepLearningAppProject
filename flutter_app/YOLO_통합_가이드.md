# YOLO ver3 모델 통합 가이드

## ✅ 완료된 작업

1. **YOLO 서비스 생성** (`lib/services/yolo_service.dart`)
   - YOLO 서버 API와 통신하는 서비스
   - 이미지 업로드 및 분석 결과 수신

2. **통합 검사 서비스** (`lib/services/inspection_service.dart`)
   - Gemini AI와 YOLO 모델을 선택적으로 사용 가능
   - 하이브리드 모드 지원 (둘 다 사용)

3. **UI 업데이트** (`lib/screens/inspection_screen.dart`)
   - 검사 모드 선택 UI 추가
   - YOLO 서버 연결 상태 확인

4. **YOLO 서버** (`yolo_server/server.py`)
   - FastAPI 기반 서버
   - YOLO ver3 모델 로드 및 분석

## 🚀 사용 방법

### 1. YOLO 서버 실행

```bash
# 서버 디렉토리로 이동
cd /Users/cjh/Desktop/DeepLearning/yolo_server

# 의존성 설치
pip install -r requirements.txt

# 서버 실행
python server.py
```

서버가 `http://localhost:8000`에서 실행됩니다.

### 2. Flutter 앱에서 YOLO 사용

#### 방법 1: 환경 변수 설정
```bash
export YOLO_API_URL="http://localhost:8000"
flutter run
```

#### 방법 2: 코드에서 직접 수정
`lib/services/yolo_service.dart` 파일의 `_baseUrl`을 수정:
```dart
static const String _baseUrl = 'http://localhost:8000';
```

### 3. 앱에서 모드 선택

앱 실행 후:
1. **"Gemini AI"** 버튼: Gemini AI 사용 (기존 방식)
2. **"YOLO ver3"** 버튼: YOLO 모델 사용 (새로 추가)

YOLO 모드를 선택하면 서버 연결 상태가 표시됩니다.

## 📊 모델 성능

- **Box Detection mAP@50**: 99.12%
- **Precision**: 97.84%
- **Recall**: 97.82%

## 🔧 문제 해결

### 서버 연결 실패
- YOLO 서버가 실행 중인지 확인
- `http://localhost:8000/health` 접속 테스트
- 방화벽 설정 확인

### 모델 파일 없음
- `YOLO_TRAINING_RESULTS/smartphone_ver3/weights/best.pt` 파일 확인
- `server.py`의 `MODEL_PATH` 수정

### 이미지 분석 실패
- 이미지가 올바른 형식인지 확인 (JPEG/PNG)
- 서버 로그 확인

## 🎯 다음 단계

1. **프로덕션 배포**
   - 서버를 클라우드에 배포 (AWS, GCP 등)
   - HTTPS 설정
   - 인증 추가

2. **성능 최적화**
   - 모델 양자화
   - 배치 처리
   - 캐싱

3. **하이브리드 모드 개선**
   - Gemini와 YOLO 결과 통합 알고리즘 개선
   - 가중치 기반 통합


