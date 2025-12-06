"""
YOLO 스마트폰 결함 검출 서버
Flutter 앱에서 사용할 수 있는 FastAPI 서버
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Dict, List, Optional
import base64
import io
from PIL import Image, ImageDraw, ImageFont
import torch
from ultralytics import YOLO
import numpy as np
import os

app = FastAPI(title="YOLO 스마트폰 검사 API")

# CORS 설정 (Flutter 앱에서 접근 가능하도록)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 프로덕션에서는 특정 도메인만 허용
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# YOLO 모델 로드
MODEL_PATH = os.path.join(
    os.path.dirname(__file__),
    "../smartphone_ver4_detect/best.pt"
)

if not os.path.exists(MODEL_PATH):
    raise FileNotFoundError(f"모델 파일을 찾을 수 없습니다: {MODEL_PATH}")

model = YOLO(MODEL_PATH)
print(f"✅ YOLO 모델 로드 완료: {MODEL_PATH}")

# 모델이 검출할 수 있는 클래스 확인
print("\n📋 모델이 검출할 수 있는 클래스 목록:")
if hasattr(model, 'names'):
    if isinstance(model.names, dict):
        for class_id, class_name in model.names.items():
            print(f"  - 클래스 {class_id}: {class_name}")
    elif isinstance(model.names, list):
        for i, class_name in enumerate(model.names):
            print(f"  - 클래스 {i}: {class_name}")
    else:
        print(f"  모델 클래스 정보: {model.names}")
else:
    print("  ⚠️ 모델 클래스 정보를 찾을 수 없습니다.")
print()


class InspectionRequest(BaseModel):
    images: Dict[str, str]  # base64 인코딩된 이미지
    battery_health: int = 0  # 선택적 (기본값 0)


class Damage(BaseModel):
    type: str
    location: str
    severity: str


class InspectionResponse(BaseModel):
    grade: str
    summary: str
    batteryHealth: int
    screenCondition: str
    backCondition: str
    frameCondition: str
    overallAssessment: str
    damages: List[Damage]
    visualizedImages: Optional[Dict[str, str]] = None  # base64 인코딩된 시각화 이미지


def base64_to_image(base64_str: str) -> Image.Image:
    """Base64 문자열을 PIL Image로 변환"""
    try:
        # base64 문자열에서 데이터 부분만 추출 (data:image/...;base64, 부분 제거)
        if ',' in base64_str:
            base64_str = base64_str.split(',')[1]
        
        image_data = base64.b64decode(base64_str)
        image = Image.open(io.BytesIO(image_data))
        # RGB로 변환 (RGBA나 다른 형식일 수 있음)
        if image.mode != 'RGB':
            image = image.convert('RGB')
        return image
    except Exception as e:
        print(f"❌ 이미지 디코딩 오류: {str(e)}")
        raise ValueError(f"이미지 디코딩 실패: {str(e)}")


def image_to_base64(image: Image.Image) -> str:
    """PIL Image를 Base64 문자열로 변환"""
    buffer = io.BytesIO()
    image.save(buffer, format='JPEG', quality=85)
    return base64.b64encode(buffer.getvalue()).decode('utf-8')


def visualize_detections(image: Image.Image, detections: List[Dict], view_name: str) -> Image.Image:
    """검출된 손상을 이미지에 시각화"""
    # 이미지 복사
    vis_image = image.copy()
    draw = ImageDraw.Draw(vis_image)
    
    # 색상 정의
    colors = {
        'oil': (255, 0, 0),      # 빨강
        'scratch': (0, 255, 0),   # 초록
        'stain': (0, 0, 255),     # 파랑
    }
    
    # 각 검출 결과를 이미지에 그리기
    for det in detections:
        bbox = det['bbox']
        class_name = det['class']
        confidence = det['confidence']
        
        x1, y1, x2, y2 = bbox
        
        # 색상 선택
        color = colors.get(class_name, (255, 255, 0))  # 기본값: 노랑
        
        # 바운딩 박스 그리기
        draw.rectangle([x1, y1, x2, y2], outline=color, width=3)
        
        # 라벨 텍스트
        label = f"{class_name} {confidence:.2f}"
        
        # 텍스트 배경 그리기
        try:
            # 폰트 크기 계산
            font_size = max(12, int((x2 - x1) / 10))
            font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
        except:
            font = ImageFont.load_default()
        
        # 텍스트 크기 계산
        bbox_text = draw.textbbox((0, 0), label, font=font)
        text_width = bbox_text[2] - bbox_text[0]
        text_height = bbox_text[3] - bbox_text[1]
        
        # 텍스트 배경
        draw.rectangle(
            [x1, y1 - text_height - 4, x1 + text_width + 4, y1],
            fill=color,
            outline=color
        )
        
        # 텍스트 그리기
        draw.text(
            (x1 + 2, y1 - text_height - 2),
            label,
            fill=(255, 255, 255),
            font=font
        )
    
    return vis_image


def analyze_image(image: Image.Image, view_name: str) -> Dict:
    """YOLO 모델로 이미지 분석"""
    # conf 임계값을 더 낮춰서 스크래치도 검출 (0.1로 변경)
    results = model(image, conf=0.1, iou=0.5)
    
    detections = []
    for result in results:
        boxes = result.boxes
        masks = result.masks
        
        # 검출된 박스가 없으면 로그 출력
        if boxes is None or len(boxes) == 0:
            print(f"⚠️ {view_name} 이미지에서 검출된 손상 없음 (conf=0.1)")
            # 더 낮은 임계값으로 재시도
            results_low = model(image, conf=0.05, iou=0.3)
            for result_low in results_low:
                boxes_low = result_low.boxes
                if boxes_low is not None and len(boxes_low) > 0:
                    print(f"  💡 conf=0.05로 재시도: {len(boxes_low)}개 검출됨")
                    boxes = boxes_low
                    masks = result_low.masks
                    break
            if boxes is None or len(boxes) == 0:
                continue
        
        for i, box in enumerate(boxes):
            # 바운딩 박스 정보
            x1, y1, x2, y2 = box.xyxy[0].cpu().numpy()
            confidence = float(box.conf[0].cpu().numpy())
            class_id = int(box.cls[0].cpu().numpy())
            
            # 클래스 이름 (데이터셋에 따라 다를 수 있음)
            try:
                if hasattr(model, 'names') and isinstance(model.names, dict):
                    class_name = model.names.get(class_id, "unknown")
                elif hasattr(model, 'names') and isinstance(model.names, list):
                    class_name = model.names[class_id] if class_id < len(model.names) else "unknown"
                else:
                    class_name = f"class_{class_id}"
            except Exception:
                class_name = f"class_{class_id}"
            
            # 마스크 정보 (있는 경우)
            mask_area = 0
            if masks is not None and i < len(masks.data):
                mask = masks.data[i].cpu().numpy()
                mask_area = np.sum(mask > 0.5)
            
            detections.append({
                "class": class_name,
                "confidence": confidence,
                "bbox": [float(x1), float(y1), float(x2), float(y2)],
                "area": mask_area,
                "view": view_name,
            })
            
            # 디버깅: 검출된 손상 로그 출력
            bbox_area = (x2 - x1) * (y2 - y1)
            print(f"✅ {view_name}에서 검출: {class_name} (신뢰도: {confidence:.3f}, 위치: [{x1:.0f}, {y1:.0f}, {x2:.0f}, {y2:.0f}], 영역: {bbox_area:.0f}px², 마스크: {mask_area}px²)")
    
    print(f"📊 {view_name} 총 검출 개수: {len(detections)}")
    
    # 검출된 클래스별 통계
    if detections:
        class_counts = {}
        for det in detections:
            class_name = det["class"]
            class_counts[class_name] = class_counts.get(class_name, 0) + 1
        print(f"  📈 클래스별 검출 통계: {class_counts}")
    return {
        "detections": detections,
        "count": len(detections),
    }


def determine_severity(damage_count: int, confidence: float, class_name: str = "") -> str:
    """결함 심각도 결정"""
    if damage_count == 0:
        return "none"
    
    # 크랙(crack)이나 심각한 손상은 무조건 severe
    severe_keywords = ["crack", "broken", "shatter", "fracture", "chip"]
    if any(keyword in class_name.lower() for keyword in severe_keywords):
        print(f"  🔴 심각한 손상 감지: {class_name} → severe")
        return "severe"
    
    # 검출된 손상이 많으면 severe (5개 이상)
    if damage_count >= 5:
        print(f"  🔴 다수 손상 감지 ({damage_count}개) → severe")
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


def calculate_grade(damages: List[Dict], battery_health: int) -> str:
    """
    등급 계산 (가중치 기반 점수 시스템)
    
    가중치:
    - 화면 손상: 3.0 (가장 중요)
    - 후면 손상: 2.0
    - 프레임 손상: 1.0
    - 심각도별 가중치:
      - severe: 2.0
      - moderate: 1.0
      - minor: 0.5
    - 배터리 성능: 100점 만점 (90% 이상 = 100점, 80% = 80점, ...)
    """
    # 위치별 가중치 (전면, 후면만)
    LOCATION_WEIGHTS = {
        "front": 3.0,  # 화면 손상은 가장 중요
        "back": 2.0,   # 후면 손상
    }
    
    # 심각도별 가중치
    SEVERITY_WEIGHTS = {
        "severe": 2.0,
        "moderate": 1.0,
        "minor": 0.5,
        "none": 0.0,
    }
    
    # 손상 점수 계산 (배터리 없이 손상만으로 등급 결정)
    damage_score = 0.0
    for damage in damages:
        location = damage.get("location", "").lower()
        severity = damage.get("severity", "minor")
        
        # 위치 가중치 찾기
        location_weight = 1.0
        for loc_key, weight in LOCATION_WEIGHTS.items():
            if loc_key in location:
                location_weight = weight
                break
        
        # 심각도 가중치
        severity_weight = SEVERITY_WEIGHTS.get(severity, 1.0)
        
        # 최종 손상 점수 = 위치 가중치 × 심각도 가중치
        damage_score += location_weight * severity_weight
    
    # 등급 결정 (손상 점수만으로 결정)
    # severe 손상이 있으면 자동으로 D등급
    severe_count = sum(1 for d in damages if d.get("severity") == "severe")
    if severe_count > 0:
        print(f"  🔴 severe 손상 {severe_count}개 발견 → D등급")
        return "D"
    
    # 손상 점수 기반 등급 결정
    if damage_score == 0:
        return "S"  # 최상급: 손상 없음
    elif damage_score <= 2:
        return "A"  # 우수: 미세한 손상 (기존 3에서 2로 낮춤)
    elif damage_score <= 8:
        return "B"  # 양호: 적당한 손상 (기존 10에서 8로 낮춤)
    elif damage_score <= 15:
        return "C"  # 보통: 많은 손상 (기존 20에서 15로 낮춤)
    else:
        return "D"  # 미흡: 심각한 손상


@app.get("/health")
async def health_check():
    """서버 상태 확인"""
    return {"status": "ok", "model_loaded": model is not None}


@app.post("/api/inspect", response_model=InspectionResponse)
async def inspect_phone(request: InspectionRequest):
    """스마트폰 검사 (전면, 후면만)"""
    try:
        print(f"\n{'='*60}")
        print(f"📥 검사 요청 수신")
        print(f"   이미지 키: {list(request.images.keys())}")
        print(f"   배터리 상태: {request.battery_health}")
        
        # 이미지 디코딩 (전면, 후면만)
        images = {}
        for view_name, base64_str in request.images.items():
            if view_name in ["front", "back"]:
                print(f"   🔄 {view_name} 이미지 디코딩 중... (길이: {len(base64_str)} chars)")
                try:
                    images[view_name] = base64_to_image(base64_str)
                    print(f"   ✅ {view_name} 이미지 디코딩 성공: {images[view_name].size}")
                except Exception as e:
                    print(f"   ❌ {view_name} 이미지 디코딩 실패: {str(e)}")
                    raise
        
        # 각 이미지 분석
        all_damages = []
        analysis_results = {}
        
        for view_name, image in images.items():
            print(f"\n{'='*60}")
            print(f"🔍 {view_name} 이미지 분석 시작...")
            print(f"   이미지 크기: {image.size[0]}x{image.size[1]}px")
            result = analyze_image(image, view_name)
            analysis_results[view_name] = result
            print(f"{'='*60}\n")
            
            # 결함 정보 생성
            for det in result["detections"]:
                severity = determine_severity(
                    result["count"],
                    det["confidence"],
                    det["class"]  # 클래스 이름 전달
                )
                
                print(f"  - 손상 유형: {det['class']}, 신뢰도: {det['confidence']:.2f}, 심각도: {severity}")
                
                # severity가 "none"이 아니면 추가
                if severity != "none":
                    all_damages.append({
                        "type": det["class"],
                        "location": f"{view_name} - bbox: {det['bbox']}",
                        "severity": severity,
                    })
                else:
                    print(f"  ⚠️ 심각도가 'none'으로 판정되어 제외됨")
        
        print(f"\n📋 총 검출된 손상: {len(all_damages)}개")
        
        # 등급 계산
        grade = calculate_grade(all_damages, request.battery_health)
        print(f"🎯 최종 등급: {grade} (손상 개수: {len(all_damages)})")
        
        # 조건 설명 생성
        screen_damages = [d for d in all_damages if "front" in d["location"].lower()]
        back_damages = [d for d in all_damages if "back" in d["location"].lower()]
        frame_damages = []  # 프레임 이미지 없음
        
        screen_condition = f"화면 상태: {len(screen_damages)}개 결함 검출" if screen_damages else "화면 상태: 양호"
        back_condition = f"후면 상태: {len(back_damages)}개 결함 검출" if back_damages else "후면 상태: 양호"
        frame_condition = f"프레임 상태: {len(frame_damages)}개 결함 검출" if frame_damages else "프레임 상태: 양호"
        
        # 요약 생성
        summary = f"총 {len(all_damages)}개 결함 검출, 등급: {grade}"
        
        # 종합 평가
        if grade == "S":
            assessment = "최상급 상태입니다. 거의 새것과 같은 품질입니다."
        elif grade == "A":
            assessment = "우수한 상태입니다. 미세한 사용 흔적만 있습니다."
        elif grade == "B":
            assessment = "양호한 상태입니다. 일부 사용 흔적이 보입니다."
        elif grade == "C":
            assessment = "보통 상태입니다. 명확한 사용 흔적이 있습니다."
        else:
            assessment = "미흡한 상태입니다. 상당한 손상이 있습니다."
        
        # Damage 객체 생성
        damage_objects = [
            Damage(
                type=d["type"],
                location=d["location"],
                severity=d["severity"]
            )
            for d in all_damages
        ]
        
        # 검출 결과 시각화
        visualized_images = {}
        for view_name, image in images.items():
            view_detections = [
                {
                    "bbox": [float(x) for x in det["bbox"]],
                    "class": det["class"],
                    "confidence": det["confidence"]
                }
                for det in analysis_results[view_name]["detections"]
            ]
            
            if view_detections:
                vis_image = visualize_detections(image, view_detections, view_name)
                visualized_images[view_name] = image_to_base64(vis_image)
                print(f"📸 {view_name} 이미지 시각화 완료 ({len(view_detections)}개 검출 표시)")
            else:
                # 검출이 없어도 원본 이미지 반환
                visualized_images[view_name] = image_to_base64(image)
        
        return InspectionResponse(
            grade=grade,
            summary=summary,
            batteryHealth=0,  # 배터리 정보 없음
            screenCondition=screen_condition,
            backCondition=back_condition,
            frameCondition=frame_condition,
            overallAssessment=assessment,
            damages=damage_objects,
            visualizedImages=visualized_images,
        )
        
    except Exception as e:
        import traceback
        error_detail = f"검사 실패: {str(e)}\n{traceback.format_exc()}"
        print(f"❌ 에러 발생: {error_detail}")  # 서버 로그에 출력
        print(f"❌ 요청 데이터: images keys = {list(request.images.keys()) if request.images else 'None'}")
        # 더 자세한 에러 정보 반환
        error_message = str(e)
        if len(error_message) > 200:
            error_message = error_message[:200] + "..."
        raise HTTPException(status_code=500, detail=f"검사 실패: {error_message}")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)


