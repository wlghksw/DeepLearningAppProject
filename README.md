# DeepLearningAppProject

순서 

1. 데이터 정제 

**Clipping 알고리즘**을 코드로 구현하여, 모든 라벨 데이터를 YOLO 포맷에 맞게 0과 1 사이로 정규화

1. 시나리오 기반 증강 

`Albumentations` 라이브러리를 활용해 **'가상의 빛 번짐(Sun Flare)'** 데이터를 인위적으로 생성

 또한 사용자가 다양한 각도에서 촬영할 것을 대비해 **회전 및 크기 조절**, 그리고 **조명 변화**까지 포함하여, 총 4가지 버전의 데이터셋을 구축하고 이를 하나로 통합

- **사용 라이브러리:** `Albumentations`
- **적용 내용:**
    1. **Sun Flare (빛 번짐):** 액정 반사를 시뮬레이션하기 위해 가상의 광원을 생성 (`RandomSunFlare`).
    2. **Geometric (기하학적 변형):** 다양한 촬영 각도와 거리에 대응하기 위해 회전 및 크기 조절 (`ShiftScaleRotate`).
    3. **Brightness (조명 변화):** 어두운 실내나 밝은 야외 환경 대응 (`RandomBrightnessContrast`)
 



# 코드 


import os
import cv2
import glob
import shutil
import albumentations as A
import numpy as np
from tqdm import tqdm


SOURCE_PATH = "./DeepLearningAppProject" 
OUTPUT_ROOT = "./final_datasets"


ENABLE_BASE       = True
ENABLE_FLARE      = True
ENABLE_GEOMETRIC  = True
ENABLE_BRIGHTNESS = True


def clamp_yolo_bbox(bbox):
    """
    YOLO 좌표(xc, yc, w, h)가 0~1 범위를 벗어났을 때,
    강제로 0~1 안으로 들어오도록 잘라주는 함수
    """
    xc, yc, w, h = bbox
    
    # 1. 코너 좌표(좌상단, 우하단)로 변환
    x1 = xc - w / 2
    y1 = yc - h / 2
    x2 = xc + w / 2
    y2 = yc + h / 2

    # 2. 0.0 ~ 1.0 사이로 강제 고정 (Clipping)
    x1 = max(0.0, min(1.0, x1))
    y1 = max(0.0, min(1.0, y1))
    x2 = max(0.0, min(1.0, x2))
    y2 = max(0.0, min(1.0, y2))

    # 3. 다시 YOLO 포맷(중심점, 너비, 높이)으로 변환
    new_w = x2 - x1
    new_h = y2 - y1
    
    # 너비나 높이가 0이 되어버린(화면 밖으로 완전히 나간) 박스는 제거 대상
    if new_w <= 0 or new_h <= 0:
        return None 
        
    new_xc = x1 + new_w / 2
    new_yc = y1 + new_h / 2
    
    return [new_xc, new_yc, new_w, new_h]

def read_yolo_label(txt_path):
    """라벨 파일을 읽어서 리스트로 변환 (보정 적용)"""
    bboxes = []
    class_labels = []
    if os.path.exists(txt_path):
        with open(txt_path, 'r') as f:
            lines = f.readlines()
            for line in lines:
                parts = line.strip().split()
                if len(parts) >= 5:
                    cls = int(parts[0])
                    raw_bbox = [float(x) for x in parts[1:5]]
                    
                    # ⭐ 여기서 보정 함수 실행!
                    clamped_bbox = clamp_yolo_bbox(raw_bbox)
                    
                    # 유효한 박스만 리스트에 추가
                    if clamped_bbox is not None:
                        bboxes.append(clamped_bbox)
                        class_labels.append(cls)
    return bboxes, class_labels

def save_yolo_label(txt_path, bboxes, class_labels):
    """변환된 라벨을 다시 파일로 저장"""
    with open(txt_path, 'w') as f:
        for bbox, cls in zip(bboxes, class_labels):
            # 저장 전 한 번 더 안전장치 (소수점 6자리)
            bbox = [max(0.0, min(1.0, x)) for x in bbox]
            line = f"{cls} {bbox[0]:.6f} {bbox[1]:.6f} {bbox[2]:.6f} {bbox[3]:.6f}\n"
            f.write(line)


bbox_params = A.BboxParams(format='yolo', min_visibility=0.3, label_fields=['class_labels'], check_each_transform=False)

pipelines = {}

if ENABLE_FLARE:
    pipelines["dataset_flare"] = A.Compose([
        A.RandomSunFlare(flare_roi=(0, 0, 1, 0.5), src_radius=150, p=1.0)
    ], bbox_params=bbox_params)

if ENABLE_GEOMETRIC:
    pipelines["dataset_geometric"] = A.Compose([
        A.ShiftScaleRotate(shift_limit=0.05, scale_limit=0.2, rotate_limit=15, p=1.0)
    ], bbox_params=bbox_params)

if ENABLE_BRIGHTNESS:
    pipelines["dataset_brightness"] = A.Compose([
        A.RandomBrightnessContrast(brightness_limit=0.3, contrast_limit=0.3, p=1.0)
    ], bbox_params=bbox_params)


def process_and_save(pipeline_name, transform, subset, img_path, save_root):
    try:
        file_name = os.path.basename(img_path)
        label_name = os.path.splitext(file_name)[0] + ".txt"
        
        # 라벨 경로 찾기 (폴더 구조에 따라 다를 수 있음)
        # ../images/xxx.jpg -> ../labels/xxx.txt
        src_label_path = os.path.join(os.path.dirname(os.path.dirname(img_path)), "labels", label_name)
        
        # 저장 폴더 생성
        save_img_dir = os.path.join(save_root, pipeline_name, subset, "images")
        save_lbl_dir = os.path.join(save_root, pipeline_name, subset, "labels")
        os.makedirs(save_img_dir, exist_ok=True)
        os.makedirs(save_lbl_dir, exist_ok=True)

        # 이미지 읽기
        image = cv2.imread(img_path)
        if image is None: return
        image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

        # 라벨 읽기 (여기서 이미 보정됨)
        bboxes, class_labels = read_yolo_label(src_label_path)

        # 라벨이 없는 경우(배경 이미지) 처리
        if len(bboxes) == 0 and len(class_labels) == 0:
             # 빈 리스트로 진행
             pass

        # 증강 적용
        if transform:
            # Albumentations 실행
            augmented = transform(image=image, bboxes=bboxes, class_labels=class_labels)
            save_image = augmented['image']
            save_bboxes = augmented['bboxes']
            save_labels = augmented['class_labels']
        else:
            save_image = image
            save_bboxes = bboxes
            save_labels = class_labels

        # 파일명 접두사 처리
        prefix = pipeline_name.replace("dataset_", "") + "_"
        if pipeline_name == "dataset_base": prefix = ""
        
        final_img_name = prefix + file_name
        final_lbl_name = prefix + label_name

        # 저장
        cv2.imwrite(os.path.join(save_img_dir, final_img_name), cv2.cvtColor(save_image, cv2.COLOR_RGB2BGR))
        
        if save_bboxes:
            save_yolo_label(os.path.join(save_lbl_dir, final_lbl_name), save_bboxes, save_labels)
            
    except Exception as e:
        # 에러가 나도 멈추지 않고 로그만 출력하고 다음 사진으로 넘어감
        print(f"⚠️ 처리 실패 ({file_name}): {e}")


if __name__ == "__main__":
    subsets = ["train", "valid", "test"]
    
    # 1. Base (원본)
    if ENABLE_BASE:
        print(f"\n [Base Dataset] 처리 중...")
        for subset in subsets:
            img_paths = glob.glob(os.path.join(SOURCE_PATH, subset, "images", "*.*"))
            for path in tqdm(img_paths, desc=f"Base-{subset}"):
                process_and_save("dataset_base", None, subset, path, OUTPUT_ROOT)

    # 2. 증강 (Augmentation)
    for name, pipeline in pipelines.items():
        print(f"\n✨ [{name}] 처리 중...")
        for subset in subsets:
            img_paths = glob.glob(os.path.join(SOURCE_PATH, subset, "images", "*.*"))
            for path in tqdm(img_paths, desc=f"{name}-{subset}"):
                process_and_save(name, pipeline, subset, path, OUTPUT_ROOT)

    print(f"\n✅ 모든 작업 완료!")
