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
 

