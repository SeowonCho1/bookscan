# BookScan

**종이를 디지털로. 서버 없이, 기기 안에서 끝.**

카메라로 책·문서를 스캔하고, 보정·OCR·PDF까지 한 번에 처리하는 **로컬 우선** Flutter 앱입니다.  
촬영한 이미지와 텍스트는 **내 폰에만** 남습니다.

---

## 왜 BookScan?

| | |
|---|---|
| **프라이버시** | OCR·저장 모두 기기 내부. 클라우드 업로드 없음 |
| **오프라인** | 네트워크 없이 스캔 → PDF → 공유까지 가능 |
| **실용성** | 문서명·OCR 텍스트 통합 검색, 페이지 순서 편집, 필터 보정 |
| **가벼움** | SQLite + 로컬 파일. MVP에 필요한 것만 담았습니다 |

---

## 주요 기능

- **문서 스캔** — `cunning_document_scanner` 기반 자동 문서 감지·연속 촬영
- **페이지 편집** — 크롭, 순서 변경, 컬러 / 그레이스케일 / 흑백 필터
- **PDF 내보내기** — 문서 단위 PDF 생성 및 미리보기
- **OCR** — Google ML Kit으로 기기 내 텍스트 인식 (한글·영문)
- **검색** — 문서 제목 + OCR 본문을 한 번에 검색
- **공유** — 생성된 PDF를 카카오톡·메일 등 시스템 공유 시트로 전송
- **플랜 구분** — 무료(연속 10장) / 승인(연속 100장), 설정에서 개발용 토글 가능

---

## 화면 흐름

```
홈 (문서 목록·검색)
 │
 ├─► 새 스캔 ──► 페이지 편집 ──► 문서 상세
 │                                  ├─► PDF 내보내기
 │                                  ├─► OCR 결과
 │                                  └─► 페이지별 보정
 └─► 설정 (승인 모드 시뮬레이션)
```

| 경로 | 화면 |
|------|------|
| `/` | 홈 — 문서 목록, 검색, 스캔 시작 |
| `/document/:id` | 문서 상세 — 커버, PDF, OCR 상태 |
| `/document/:id/pages` | 페이지 목록·순서 편집 |
| `/document/:id/page/:pageId/edit` | 단일 페이지 크롭·필터 |
| `/document/:id/export` | PDF 생성·미리보기 |
| `/document/:id/ocr` | OCR 전체 텍스트 |
| `/settings` | 앱 설정 |

---

## 기술 스택

| 영역 | 선택 |
|------|------|
| 프레임워크 | Flutter 3 · Dart ^3.11 |
| 상태 관리 | Riverpod |
| 라우팅 | go_router |
| DB | sqflite (SQLite) |
| 스캔 | cunning_document_scanner |
| OCR | google_mlkit_text_recognition |
| PDF | pdf · pdfx |
| 이미지 | image · image_cropper |

---

## 빠른 시작

### 요구 사항

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.x)
- Android Studio / Xcode (각 플랫폼 빌드용)
- 실기기 또는 에뮬레이터 (카메라·OCR 테스트는 **실기기 권장**)

### 설치 & 실행

```bash
git clone <repository-url>
cd bookscan

flutter pub get
flutter doctor          # Android toolchain 등 확인
flutter devices         # 연결된 기기 목록
flutter run -d <device-id>
```

### 품질 확인

```bash
flutter analyze
flutter test
```

---

## 프로젝트 구조

```
lib/
├── main.dart                 # 진입점 — DB 초기화, Riverpod, 라우터
├── app.dart                  # MaterialApp + 테마
├── config/
│   └── app_constants.dart    # 플랜·촬영 상한 등 상수
├── router/
│   └── app_router.dart       # go_router 경로 정의
├── providers/
│   └── providers.dart        # Riverpod 프로바이더 (문서, 검색, 플랜)
├── database/
│   └── app_database.dart     # SQLite 스키마·마이그레이션
├── models/                   # Document, ScanPage, OCR 레코드
├── data/
│   └── document_repository.dart   # 문서 CRUD·PDF·OCR 오케스트레이션
├── services/                 # 스캔, 이미지, PDF, OCR, 저장소
├── screens/                  # UI 화면
└── theme/
    └── app_theme.dart        # 포레스트 그린 Material 3 테마
```

**데이터 흐름:** `screens` → `providers` → `document_repository` → `services` + `database`

---

## 데이터 저장

| 저장소 | 내용 |
|--------|------|
| `bookscan.db` (SQLite) | 문서 메타, 페이지 정보, OCR 텍스트 |
| 앱 문서 디렉터리 | 스캔·보정 이미지, 생성 PDF |
| SharedPreferences | 개발용 승인 모드 등 경량 설정 |

---

## 릴리스 빌드

```bash
# Google Play (AAB)
flutter build appbundle

# APK 직접 배포
flutter build apk --release
```

Android 서명(keystore)은 `android/app/build.gradle.kts`에 설정합니다.

---

## 로드맵 (MVP 이후)

- [ ] 서버 연동 — 승인 플랜·동기화
- [ ] 클라우드 백업 (선택)
- [ ] iOS 실기기 QA 강화

---

## 개발 참고

로컬에서 구조·개념을 더 자세히 보려면 `BOOKSCAN_로컬_개발_가이드.md`를 참고하세요.  
(기본적으로 `.gitignore`에 포함되어 있을 수 있습니다.)

---

## 라이선스

Private project — `publish_to: 'none'`
