# YOLO 기반 스마트폰 등급 판별 시스템 로직

## 전체 플로우 다이어그램

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
5. YOLO 모델로 각 이미지 분석 (conf=0.25, iou=0.7)
    ↓
6. 검출 결과 파싱 (바운딩 박스, 클래스, 신뢰도, 마스크)
    ↓
7. 심각도 결정 (severe/moderate/minor)
    ↓
8. 손상 점수 계산 (가중치 기반)
    ↓
9. 등급 결정 (S/A/B/C/D)
    ↓
10. JSON 응답 반환
    ↓
[Flutter 앱]
    ↓
11. 결과 화면 표시
```

---

## 상세 단계별 설명

### 1단계: 이미지 업로드 및 전송 (Flutter 앱)

**파일**: `flutter_app/lib/screens/inspection_screen.dart`

```dart
// 사용자가 전면/후면 이미지 선택
XFile? _frontImage;
XFile? _backImage;

// 이미지를 bytes로 변환
final frontBytes = await _frontImage!.readAsBytes();
final backBytes = await _backImage!.readAsBytes();

// Base64로 인코딩하여 서버로 전송
final requestBody = {
  'images': {
    'front': base64Encode(frontBytes),
    'back': base64Encode(backBytes),
  },
};
```

---

### 2단계: 서버에서 이미지 수신 및 디코딩

**파일**: `yolo_server/server.py` (194-202줄)

```python
@app.post("/api/inspect")
async def inspect_phone(request: InspectionRequest):
    # Base64 문자열을 PIL Image로 변환
    images = {}
    for view_name, base64_str in request.images.items():
        if view_name in ["front", "back"]:
            images[view_name] = base64_to_image(base64_str)
```

**함수**: `base64_to_image()` (64-67줄)
- Base64 문자열을 디코딩
- BytesIO로 변환 후 PIL Image 객체 생성

---

### 3단계: YOLO 모델로 이미지 분석

**파일**: `yolo_server/server.py` (70-113줄)

**함수**: `analyze_image(image, view_name)`

```python
def analyze_image(image: Image.Image, view_name: str) -> Dict:
    # YOLO 모델 실행
    # conf=0.25: 신뢰도 25% 이상만 검출
    # iou=0.7: 겹치는 박스 제거 (IoU 0.7 이상)
    results = model(image, conf=0.25, iou=0.7)
    
    detections = []
    for result in results:
        boxes = result.boxes      # 바운딩 박스 정보
        masks = result.masks      # 세그멘테이션 마스크 (있을 경우)
        
        for i, box in enumerate(boxes):
            # 바운딩 박스 좌표 추출
            x1, y1, x2, y2 = box.xyxy[0].cpu().numpy()
            
            # 신뢰도 (confidence) 추출
            confidence = float(box.conf[0].cpu().numpy())
            
            # 클래스 ID 추출
            class_id = int(box.cls[0].cpu().numpy())
            
            # 클래스 이름 가져오기 (예: "scratch", "crack", "ding" 등)
            class_name = model.names.get(class_id, "unknown")
            
            # 마스크 영역 계산 (세그멘테이션 모델인 경우)
            mask_area = 0
            if masks is not None:
                mask = masks.data[i].cpu().numpy()
                mask_area = np.sum(mask > 0.5)  # 마스크 픽셀 수
            
            detections.append({
                "class": class_name,           # 손상 유형
                "confidence": confidence,      # 신뢰도 (0.0 ~ 1.0)
                "bbox": [x1, y1, x2, y2],     # 바운딩 박스 좌표
                "area": mask_area,             # 마스크 영역 크기
                "view": view_name,             # "front" 또는 "back"
            })
    
    return {
        "detections": detections,  # 검출된 모든 손상 목록
        "count": len(detections),  # 검출 개수
    }
```

**YOLO 모델 정보**:
- 모델 경로: `YOLO_TRAINING_RESULTS/smartphone_ver3/weights/best.pt`
- 모델 타입: Segmentation (세그멘테이션)
- 검출 가능한 손상 유형: 학습 데이터셋에 따라 다름 (예: scratch, crack, ding, scuff 등)

---

### 4단계: 심각도 결정

**파일**: `yolo_server/server.py` (116-125줄)

**함수**: `determine_severity(damage_count, confidence)`

```python
def determine_severity(damage_count: int, confidence: float) -> str:
    if damage_count == 0:
        return "none"
    
    # 신뢰도가 80% 이상이고 손상이 3개 이상 → 심각
    if confidence > 0.8 and damage_count > 3:
        return "severe"
    
    # 신뢰도가 50% 이상 → 보통
    elif confidence > 0.5:
        return "moderate"
    
    # 그 외 → 경미
    else:
        return "minor"
```

**심각도 판단 기준**:
- **severe**: 신뢰도 > 80% AND 손상 개수 > 3
- **moderate**: 신뢰도 > 50%
- **minor**: 신뢰도 ≤ 50%
- **none**: 손상 없음

---

### 5단계: 손상 점수 계산 (가중치 시스템)

**파일**: `yolo_server/server.py` (128-185줄)

**함수**: `calculate_grade(damages, battery_health)`

#### 가중치 정의

```python
# 위치별 가중치
LOCATION_WEIGHTS = {
    "front": 3.0,  # 화면 손상은 가장 중요 (3배)
    "back": 2.0,   # 후면 손상 (2배)
}

# 심각도별 가중치
SEVERITY_WEIGHTS = {
    "severe": 2.0,    # 심각한 손상 (2배)
    "moderate": 1.0,  # 보통 손상 (1배)
    "minor": 0.5,     # 경미한 손상 (0.5배)
    "none": 0.0,      # 손상 없음
}
```

#### 손상 점수 계산 로직

```python
damage_score = 0.0

for damage in damages:
    location = damage.get("location", "").lower()  # "front" 또는 "back"
    severity = damage.get("severity", "minor")     # "severe", "moderate", "minor"
    
    # 위치 가중치 찾기
    location_weight = LOCATION_WEIGHTS.get(location, 1.0)
    
    # 심각도 가중치
    severity_weight = SEVERITY_WEIGHTS.get(severity, 1.0)
    
    # 최종 손상 점수 = 위치 가중치 × 심각도 가중치
    damage_score += location_weight * severity_weight
```

**예시 계산**:
1. 전면에 minor 손상 1개: 3.0 × 0.5 = **1.5점**
2. 후면에 moderate 손상 1개: 2.0 × 1.0 = **2.0점**
3. 전면에 severe 손상 1개: 3.0 × 2.0 = **6.0점**
4. 총 손상 점수: 1.5 + 2.0 + 6.0 = **9.5점**

---

### 6단계: 등급 결정

**파일**: `yolo_server/server.py` (175-185줄)

```python
# 등급 결정 (손상 점수만으로 결정)
if damage_score == 0:
    return "S"  # 최상급: 손상 없음
elif damage_score <= 3:
    return "A"  # 우수: 미세한 손상
elif damage_score <= 10:
    return "B"  # 양호: 적당한 손상
elif damage_score <= 20:
    return "C"  # 보통: 많은 손상
else:
    return "D"  # 미흡: 심각한 손상
```

**등급 기준표**:

| 등급 | 손상 점수 범위 | 설명 | 예시 |
|------|---------------|------|------|
| **S** | 0점 | 손상 없음 | 새것과 같은 상태 |
| **A** | 0 < 점수 ≤ 3 | 미세한 손상 | 전면 minor 1개 (1.5점) 또는 후면 moderate 1개 (2.0점) |
| **B** | 3 < 점수 ≤ 10 | 적당한 손상 | 전면 minor 2개 (3.0점) + 후면 moderate 1개 (2.0점) = 5.0점 |
| **C** | 10 < 점수 ≤ 20 | 많은 손상 | 전면 severe 2개 (12.0점) + 후면 moderate 2개 (4.0점) = 16.0점 |
| **D** | 점수 > 20 | 심각한 손상 | 전면 severe 3개 이상 (18.0점+) |

---

### 7단계: 결과 생성 및 반환

**파일**: `yolo_server/server.py` (226-272줄)

```python
# 조건 설명 생성
screen_damages = [d for d in all_damages if "front" in d["location"].lower()]
back_damages = [d for d in all_damages if "back" in d["location"].lower()]

screen_condition = f"화면 상태: {len(screen_damages)}개 결함 검출" if screen_damages else "화면 상태: 양호"
back_condition = f"후면 상태: {len(back_damages)}개 결함 검출" if back_damages else "후면 상태: 양호"

# 요약 생성
summary = f"총 {len(all_damages)}개 결함 검출, 등급: {grade}"

# 종합 평가
if grade == "S":
    assessment = "최상급 상태입니다. 거의 새것과 같은 품질입니다."
elif grade == "A":
    assessment = "우수한 상태입니다. 미세한 사용 흔적만 있습니다."
# ... (B, C, D 등급도 동일하게)

# JSON 응답 반환
return InspectionResponse(
    grade=grade,                    # "S", "A", "B", "C", "D"
    summary=summary,                 # "총 3개 결함 검출, 등급: B"
    batteryHealth=0,                 # 배터리 정보 없음
    screenCondition=screen_condition, # "화면 상태: 2개 결함 검출"
    backCondition=back_condition,     # "후면 상태: 1개 결함 검출"
    frameCondition="프레임 상태: 양호", # 프레임 이미지 없음
    overallAssessment=assessment,     # 종합 평가 텍스트
    damages=[                         # 검출된 손상 목록
        Damage(
            type="scratch",           # 손상 유형
            location="front - bbox: [100, 200, 300, 400]",
            severity="minor"          # 심각도
        ),
        # ... 더 많은 손상들
    ],
)
```

---

### 8단계: Flutter 앱에서 결과 표시

**파일**: `flutter_app/lib/screens/inspection_screen.dart`

```dart
// 서버 응답을 InspectionReport 객체로 변환
final report = await YOLOService.inspectPhoneFromBytes(
  frontBytes: frontBytes,
  backBytes: backBytes,
);

// 결과 화면에 표시
setState(() {
  _report = report;  // 등급, 요약, 손상 목록 등 포함
  _isAnalyzing = false;
});
```

**표시되는 정보**:
- 등급 (S/A/B/C/D) - 큰 원형 아이콘으로 표시
- 등급별 색상 (S=초록, A=파랑, B=주황, C=주황진한색, D=빨강)
- 화면 상태, 후면 상태, 프레임 상태
- 발견된 문제점 목록 (손상 유형, 위치, 심각도)
- 종합 평가 텍스트

---

## 핵심 포인트 요약

### 1. YOLO 모델의 역할
- **입력**: 전면/후면 이미지
- **출력**: 검출된 손상의 바운딩 박스, 클래스, 신뢰도, 마스크
- **모델 타입**: Segmentation (세그멘테이션)
- **임계값**: conf=0.25 (25% 이상 신뢰도만 검출), iou=0.7

### 2. 가중치 시스템
- **위치 가중치**: 화면(3.0) > 후면(2.0)
- **심각도 가중치**: severe(2.0) > moderate(1.0) > minor(0.5)
- **최종 점수**: Σ(위치 가중치 × 심각도 가중치)

### 3. 등급 결정
- **손상 점수만으로 결정** (배터리 정보 없음)
- S(0점) → A(≤3점) → B(≤10점) → C(≤20점) → D(>20점)

### 4. 데이터 흐름
```
이미지 → Base64 인코딩 → HTTP POST → 서버 디코딩 → YOLO 분석 
→ 손상 검출 → 심각도 결정 → 점수 계산 → 등급 결정 → JSON 응답 
→ Flutter 앱 표시
```

---

## 개선 가능한 부분

1. **YOLO 모델 정확도 향상**: 더 많은 학습 데이터로 모델 재학습
2. **가중치 조정**: 실제 검수 데이터를 바탕으로 가중치 최적화
3. **등급 기준 조정**: 손상 점수 임계값을 실제 데이터로 검증
4. **마스크 정보 활용**: 현재는 마스크 영역만 계산하지만, 실제 손상 크기 계산에 활용 가능
5. **다중 이미지 분석**: 같은 부위의 여러 각도 이미지로 정확도 향상

