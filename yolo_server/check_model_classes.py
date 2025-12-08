#!/usr/bin/env python3
"""YOLO 모델의 클래스 정보 확인"""
from ultralytics import YOLO
import os

model_path = os.path.join(
    os.path.dirname(__file__),
    "../smartphone_ver4_detect2/best.pt"
)

if os.path.exists(model_path):
    model = YOLO(model_path)
    print("📋 모델이 검출할 수 있는 클래스 목록:")
    print(f"   모델 경로: {model_path}\n")
    
    if hasattr(model, 'names'):
        if isinstance(model.names, dict):
            for class_id, class_name in sorted(model.names.items()):
                print(f"  - 클래스 {class_id}: {class_name}")
        elif isinstance(model.names, list):
            for i, class_name in enumerate(model.names):
                print(f"  - 클래스 {i}: {class_name}")
        else:
            print(f"  {model.names}")
    else:
        print("  ⚠️ 클래스 정보 없음")
else:
    print(f"⚠️ 모델 파일 없음: {model_path}")

