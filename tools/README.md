# TRACEN 개발 도구

## 카메라 필터 LUT

TRACEN 시그니처 필터 4종(Golden Route / Night Trace / Faded Map / Mono Path)은
`lib/models/filter_recipe.dart`의 레시피에서 생성한 64³ LUT를 셰이더
(`shaders/lut_filter.frag`)로 적용합니다. 이 폴더는 그 LUT를 굽는 스크립트입니다.

## LUT PNG 레이아웃

`lib/utils/lut_math.dart`에 정의된 계약:

- 512×512 RGBA8 PNG, 64³ 큐브를 8×8 타일(타일당 64×64)로 펼침.
- 타일 인덱스 = blue 레벨(0-63): `tileX = b % 8`, `tileY = b ~/ 8`.
- 타일 내부: x = red 레벨, y = green 레벨.

이 레이아웃은 `tools/generate_luts.dart`, `lib/utils/lut_math.dart`,
`shaders/lut_filter.frag` 세 곳이 전부 공유합니다. **레이아웃을 바꾸려면 이
세 곳을 전부 같이 고쳐야 합니다.**

## 현재 LUT 생성 — 레시피에서

```sh
dart run tools/generate_luts.dart [--out assets/luts]
```

`lib/models/camera_filter.dart`의 4개 필터 레시피를 `FilterRecipe.applyRgb`로
64³ 그리드 전체에 돌려서 `assets/luts/<id>.png`를 씁니다. `identity.png`도
같이 생성되는데, 이건 실기기에서 셰이더가 "아무 색도 안 바꾸는" LUT을 넣었을
때 원본과 1-2 레벨 이내로 일치하는지 확인하는 디버그용입니다.

## 나중에 Lightroom/DaVinci `.cube`로 교체하기

이 레시피 기반 LUT은 시작점입니다. 실제 필름/컬러그레이딩 LUT으로 바꾸려면:

1. Lightroom이나 DaVinci Resolve에서 **sRGB/Rec.709 입출력**으로 `.cube`를
   내보냅니다(크기는 보통 17/33/65 중 하나 — 아무 크기나 됩니다, 자동으로
   64³로 리샘플됩니다). DOMAIN이 0..1이 아닌 `.cube`는 지원하지 않습니다.
2. 변환:
   ```sh
   dart run tools/cube_to_lut_png.dart path/to/GoldenRoute.cube assets/luts/golden_route.png
   ```
   파일명은 반드시 아래 중 하나와 정확히 일치해야 합니다(앱이 이 이름으로
   찾습니다 — `TracenFilter.lutAsset` 참고):
   - `golden_route.png`
   - `night_trace.png`
   - `faded_map.png`
   - `mono_path.png`
3. 나머지 3개도 같은 방식으로 반복.
4. **그레인/비네트/야간 디노이즈는 `.cube`로 옮길 수 없습니다** — 이건 LUT
   (픽셀당 색 매핑)이 아니라 셰이더의 공간적 효과라서, `FilterRecipe`의
   `grain`/`vignette`/`shadowDenoise` 필드에 그대로 남아 적용됩니다. `.cube`를
   바꿔도 이 값들은 레시피에서 따로 조정하세요.
5. (선택) 실시간 미리보기용 `ColorMatrix`는 여전히 레시피 기반이라
   `.cube`와 미세하게 안 맞을 수 있습니다 — 저장 화면(실제 LUT)과 미리보기
   사이에 차이가 느껴지면 레시피 파라미터를 `.cube`에 맞게 조정하세요.

## 검증

```sh
flutter test test/camera_filter/
```

`filter_recipe_test.dart`가 피부 보호(Monk Skin Tone 10단계, hue 변화/미백
방지)를, `lut_math_test.dart`가 LUT 레이아웃/샘플링 정확도를,
`cube_parser_test.dart`가 `.cube` 파싱을 검증합니다. LUT PNG를 바꾼 뒤에는
`test/camera_filter/lut_math_test.dart`의 "실제 필터 LUT이 applyRgb와 일치"
테스트가 더는 레시피 기준이 아니게 되므로(의도된 일 — `.cube`로 바꾸는
목적이 레시피와 달라지는 것이니), 그 특정 비교 테스트는 `.cube` 교체 후
의미가 없어집니다. 레이아웃/파싱 테스트는 계속 유효합니다.

## 핀 공유 카드 — 나라 외곽선 데이터

`build_countries.py`는 이 저장소의 유일한 Python 스크립트입니다 — 앱이나
CI가 실행하지 않는 1회성 개발 도구라서 Dart 대신 Python으로 작성했습니다
(GeoJSON 단순화·정리가 Python stdlib만으로 충분히 간단함). 외부 라이브러리
의존성 없음 — 표준 라이브러리만 사용.

[Natural Earth](https://github.com/nvkelso/natural-earth-vector)(퍼블릭
도메인)의 `geojson/ne_50m_admin_0_countries.geojson`을 내려받아 실행하면,
나라별 외곽선을 `assets/countries/{ISO_A2}.json` + 전체 bbox 인덱스
`assets/countries/_index.json`으로 구워냅니다. 앱은 이 자산으로 핀 좌표가
어느 나라에 속하는지 네트워크 없이 판별하고 외곽선을 그립니다
(`lib/services/country_outline_service.dart`).

```sh
python3 tools/build_countries.py path/to/ne_50m_admin_0_countries.geojson
```

Natural Earth 데이터가 갱신되거나 외곽선 디테일/파일 크기를 조정하고 싶으면
(`--min-area-ratio`로 작은 섬 제거 기준 조정 가능) 같은 명령으로 재생성 후
`assets/countries/`를 다시 커밋하면 됩니다. 각 파일은 exterior ring만 담고
(구멍/hole 제거), 가장 큰 폴리곤의 1% 미만인 조각은 제거되며, Douglas-Peucker로
단순화됩니다(나라 크기에 비례한 epsilon이라 러시아/캐나다 같은 큰 나라도
터무니없이 커지지 않음).
