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
import hashlib
import tempfile
import os
import traceback
from PIL import Image, ImageDraw, ImageFont, ImageOps
from ultralytics import YOLO
import numpy as np

# ==================== 설정 ====================
MODEL_PATH = os.path.join(
    os.path.dirname(__file__),
    "../smartphone_ver4_detect2/best.pt"
)

# YOLO 예측 파라미터 (노트북과 동일하게 설정)
PREDICT_CONFIG = {
    "conf": 0.4,
    "augment": False,
    "imgsz": 640,
    "iou": 0.7,
    "device": "cpu",
    "half": False,
}

# 손상 클래스 색상 (시각화용)
DAMAGE_COLORS = {
    'oil': (255, 0, 0),      # 빨강
    'scratch': (0, 255, 0),  # 초록
    'stain': (0, 0, 255),    # 파랑
    'crack': (255, 165, 0), # 주황
}

# 등급 계산 가중치
LOCATION_WEIGHTS = {"front": 3.0, "back": 2.0}
SEVERITY_WEIGHTS = {"severe": 2.0, "moderate": 1.0, "minor": 0.5, "none": 0.0}

# ==================== FastAPI 앱 초기화 ====================
app = FastAPI(
    title="YOLO 스마트폰 검사 API",
    description="YOLO 모델을 사용한 스마트폰 결함 검출 서버",
    version="2.0.0"
)

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ==================== 모델 로드 ====================
def load_model():
    """YOLO 모델 로드 및 정보 출력"""
    if not os.path.exists(MODEL_PATH):
        raise FileNotFoundError(f"모델 파일을 찾을 수 없습니다: {MODEL_PATH}")
    
    model = YOLO(MODEL_PATH)
    
    # 모델 정보 출력
    print(f"\n{'='*60}")
    print(f"✅ YOLO 모델 로드 완료")
    print(f"   경로: {os.path.abspath(MODEL_PATH)}")
    print(f"   클래스: {model.names}")
    
    # 모델 파일 해시
    def sha256_file(path):
        h = hashlib.sha256()
        with open(path, "rb") as f:
            for chunk in iter(lambda: f.read(1024*1024), b""):
                h.update(chunk)
        return h.hexdigest()
    
    model_hash = sha256_file(MODEL_PATH)
    print(f"   SHA256: {model_hash[:16]}...")
    
    # 버전 정보
    try:
        import ultralytics
        print(f"   ultralytics 버전: {ultralytics.__version__}")
    except:
        pass
    
    print(f"{'='*60}\n")
    
    return model

model = load_model()

# ==================== 데이터 모델 ====================
class InspectionRequest(BaseModel):
    """검사 요청 모델"""
    images: Dict[str, str]  # {"front": "base64...", "back": "base64..."}
    battery_health: int = 0


class Damage(BaseModel):
    """손상 정보 모델"""
    type: str
    location: str
    severity: str


class InspectionResponse(BaseModel):
    """검사 응답 모델"""
    grade: str
    summary: str
    batteryHealth: int
    screenCondition: str
    backCondition: str
    frameCondition: str
    overallAssessment: str
    damages: List[Damage]
    visualizedImages: Optional[Dict[str, str]] = None

# ==================== 유틸리티 함수 ====================
def base64_to_image(base64_str: str) -> Image.Image:
    """Base64 문자열을 PIL Image로 변환"""
    if ',' in base64_str:
        base64_str = base64_str.split(',')[1]
    
    raw = base64.b64decode(base64_str)
    
    # 이미지 해시 로깅
    image_hash = hashlib.sha256(raw).hexdigest()
    print(f"📸 이미지 업로드: SHA256={image_hash[:16]}..., 크기={len(raw)} bytes")
    
    image = Image.open(io.BytesIO(raw))
    
    # EXIF 회전 정보 반영
    image = ImageOps.exif_transpose(image)
    
    # RGB 모드로 변환
    if image.mode != 'RGB':
        image = image.convert('RGB')
    
    print(f"   크기: {image.size}, 모드: {image.mode}")
    return image


def image_to_base64(image: Image.Image) -> str:
    """PIL Image를 Base64 문자열로 변환"""
    buffer = io.BytesIO()
    image.save(buffer, format='JPEG', quality=85)
    return base64.b64encode(buffer.getvalue()).decode('utf-8')


def visualize_detections(image: Image.Image, detections: List[Dict], view_name: str) -> Image.Image:
    """검출된 손상을 이미지에 시각화"""
    vis_image = image.copy()
    draw = ImageDraw.Draw(vis_image)
    
    for det in detections:
        x1, y1, x2, y2 = det['bbox']
        class_name = det['class']
        confidence = det['confidence']
        color = DAMAGE_COLORS.get(class_name, (255, 255, 0))
        
        # 바운딩 박스 그리기
        draw.rectangle([x1, y1, x2, y2], outline=color, width=3)
        
        # 라벨 그리기
        label = f"{class_name} {confidence:.2f}"
        try:
            font_size = max(12, int((x2 - x1) / 10))
            font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
        except:
            font = ImageFont.load_default()
        
        bbox_text = draw.textbbox((0, 0), label, font=font)
        text_width = bbox_text[2] - bbox_text[0]
        text_height = bbox_text[3] - bbox_text[1]
        
        # 라벨 배경
        draw.rectangle(
            [x1, y1 - text_height - 4, x1 + text_width + 4, y1],
            fill=color,
            outline=color
        )
        
        # 라벨 텍스트
        draw.text(
            (x1 + 2, y1 - text_height - 2),
            label,
            fill=(255, 255, 255),
            font=font
        )
    
    return vis_image

# ==================== 분석 함수 ====================
def analyze_image(image: Image.Image, view_name: str) -> Dict:
    """
    YOLO 모델로 이미지 분석
    노트북과 동일한 방식: 임시 파일로 저장 후 파일 경로로 예측
    """
    print(f"\n🔍 [{view_name}] 이미지 분석 시작 (크기: {image.size})")
    
    # 임시 파일로 저장
    with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as f:
        tmp_path = f.name
        image.save(f, format="JPEG", quality=95)
    
    try:
        # 노트북과 동일한 파라미터로 예측
        results = model.predict(source=tmp_path, **PREDICT_CONFIG)
    finally:
        # 임시 파일 삭제
        os.remove(tmp_path)
    
    detections = []
    for result in results:
        boxes = result.boxes
        masks = result.masks
        
        if boxes is None or len(boxes) == 0:
            print(f"   ⚠️ 검출된 객체 없음")
            continue
        
        print(f"   ✅ {len(boxes)}개 객체 검출")
        
        for i, box in enumerate(boxes):
            x1, y1, x2, y2 = box.xyxy[0].cpu().numpy()
            confidence = float(box.conf[0].cpu().numpy())
            class_id = int(box.cls[0].cpu().numpy())
            
            # 클래스 이름 가져오기
            if isinstance(model.names, dict):
                class_name = model.names.get(class_id, "unknown")
            elif isinstance(model.names, list):
                class_name = model.names[class_id] if class_id < len(model.names) else "unknown"
            else:
                class_name = f"class_{class_id}"
            
            # 마스크 정보 (segmentation 모델인 경우)
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
            
            # 검출 결과 로깅
            print(f"      [{i+1}] {class_name}: {confidence:.3f} "
                  f"(bbox: [{x1:.0f}, {y1:.0f}, {x2:.0f}, {y2:.0f}])")
    
    print(f"   📊 총 검출: {len(detections)}개\n")
    
    return {
        "detections": detections,
        "count": len(detections),
    }


def determine_severity(damage_count: int, confidence: float, class_name: str = "") -> str:
    """결함 심각도 결정"""
    if damage_count == 0:
        return "none"
    
    # 심각한 키워드 체크
    severe_keywords = ["crack", "broken", "shatter", "fracture", "chip"]
    if any(keyword in class_name.lower() for keyword in severe_keywords):
        return "severe"
    
    # 손상 개수와 신뢰도 기반 판정
    if damage_count >= 5:
        return "severe"
    
    if confidence > 0.6 and damage_count >= 3:
        return "severe"
    
    if confidence > 0.3:
        return "moderate"
    
    return "minor"


def calculate_grade(damages: List[Dict], battery_health: int) -> str:
    """등급 계산"""
    damage_score = 0.0
    
    for damage in damages:
        location = damage.get("location", "").lower()
        severity = damage.get("severity", "minor")
        
        # 위치 가중치
        location_weight = 1.0
        for loc_key, weight in LOCATION_WEIGHTS.items():
            if loc_key in location:
                location_weight = weight
                break
        
        # 심각도 가중치
        severity_weight = SEVERITY_WEIGHTS.get(severity, 1.0)
        damage_score += location_weight * severity_weight
    
    # severe 손상이 있으면 무조건 D등급
    if any(d.get("severity") == "severe" for d in damages):
        return "D"
    
    # 점수 기반 등급 판정
    if damage_score == 0:
        return "S"
    elif damage_score <= 2:
        return "A"
    elif damage_score <= 8:
        return "B"
    elif damage_score <= 15:
        return "C"
    else:
        return "D"

# ==================== API 엔드포인트 ====================
@app.get("/health")
async def health_check():
    """서버 상태 확인"""
    return {
        "status": "ok",
        "model_loaded": model is not None,
        "model_path": os.path.abspath(MODEL_PATH)
    }


@app.post("/api/inspect", response_model=InspectionResponse)
async def inspect_phone(request: InspectionRequest):
    """스마트폰 검사 API"""
    try:
        # 1. 이미지 디코딩
        images = {}
        for view_name, base64_str in request.images.items():
            if view_name in ["front", "back"]:
                images[view_name] = base64_to_image(base64_str)
        
        if not images:
            raise ValueError("front 또는 back 이미지가 필요합니다.")
        
        # 2. 이미지 분석
        all_damages = []
        analysis_results = {}
        
        for view_name, image in images.items():
            result = analyze_image(image, view_name)
            analysis_results[view_name] = result
            
            # 검출 결과 상세 로깅
            print(f"{'='*60}")
            print(f"📋 [{view_name}] 검출 결과 상세:")
            print(f"   총 검출 개수: {result['count']}개")
            
            if result["detections"]:
                for idx, det in enumerate(result["detections"], 1):
                    print(f"   [{idx}] 클래스: {det['class']}, "
                          f"신뢰도: {det['confidence']:.3f}, "
                          f"bbox: [{det['bbox'][0]:.0f}, {det['bbox'][1]:.0f}, "
                          f"{det['bbox'][2]:.0f}, {det['bbox'][3]:.0f}]")
            else:
                print(f"   ⚠️ 검출된 객체 없음")
            print(f"{'='*60}\n")
            
            # 손상 정보 생성
            for det in result["detections"]:
                severity = determine_severity(
                    result["count"],
                    det["confidence"],
                    det["class"]
                )
                
                print(f"   → {det['class']} (신뢰도: {det['confidence']:.3f}) → 심각도: {severity}")
                
                all_damages.append({
                    "type": det["class"],
                    "location": view_name,
                    "severity": severity,
                })
        
        # 3. 등급 계산
        print(f"{'='*60}")
        print(f"📊 최종 손상 통계:")
        print(f"   총 손상 개수: {len(all_damages)}개")
        
        if all_damages:
            damage_counts = {}
            for d in all_damages:
                key = f"{d['type']} ({d['severity']})"
                damage_counts[key] = damage_counts.get(key, 0) + 1
            for key, count in damage_counts.items():
                print(f"   - {key}: {count}개")
        
        print(f"{'='*60}\n")
        
        grade = calculate_grade(all_damages, request.battery_health)
        print(f"🎯 최종 등급: {grade} (손상 개수: {len(all_damages)})\n")
        
        # 4. 조건 설명 생성
        screen_damages = [d for d in all_damages if "front" in d["location"].lower()]
        back_damages = [d for d in all_damages if "back" in d["location"].lower()]
        
        screen_condition = (
            f"화면 상태: {len(screen_damages)}개 결함 검출" 
            if screen_damages else "화면 상태: 양호"
        )
        back_condition = (
            f"후면 상태: {len(back_damages)}개 결함 검출" 
            if back_damages else "후면 상태: 양호"
        )
        frame_condition = "프레임 상태: 양호"
        
        summary = f"총 {len(all_damages)}개 결함 검출, 등급: {grade}"
        
        assessments = {
            "S": "최상급 상태입니다. 거의 새것과 같은 품질입니다.",
            "A": "우수한 상태입니다. 미세한 사용 흔적만 있습니다.",
            "B": "양호한 상태입니다. 일부 사용 흔적이 보입니다.",
            "C": "보통 상태입니다. 명확한 사용 흔적이 있습니다.",
            "D": "미흡한 상태입니다. 상당한 손상이 있습니다.",
        }
        
        # 5. Damage 객체 생성
        damage_objects = [
            Damage(type=d["type"], location=d["location"], severity=d["severity"])
            for d in all_damages
        ]
        
        # 6. 검출 결과 시각화
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
            else:
                visualized_images[view_name] = image_to_base64(image)
        
        # 7. 응답 반환
        return InspectionResponse(
            grade=grade,
            summary=summary,
            batteryHealth=request.battery_health,
            screenCondition=screen_condition,
            backCondition=back_condition,
            frameCondition=frame_condition,
            overallAssessment=assessments.get(grade, assessments["D"]),
            damages=damage_objects,
            visualizedImages=visualized_images,
        )
        
    except Exception as e:
        error_msg = str(e)
        print(f"\n❌ 에러 발생: {error_msg}")
        print(traceback.format_exc())
        
        if len(error_msg) > 200:
            error_msg = error_msg[:200] + "..."
        
        raise HTTPException(status_code=500, detail=f"검사 실패: {error_msg}")


# ==================== 서버 실행 ====================
if __name__ == "__main__":
    import uvicorn
    print(f"\n🚀 YOLO 서버 시작: http://0.0.0.0:8000")
    print(f"📖 API 문서: http://0.0.0.0:8000/docs\n")
    uvicorn.run(app, host="0.0.0.0", port=8000)
