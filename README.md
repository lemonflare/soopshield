# SoopShield iOS Tweak

SoopShield is an iOS tweak for SOOP that provides ad-blocking functionality through native iOS hook points. It blocks ad requests at the network level and hides ad elements in WebView components.

## Features

- **Native URL-level ad blocking**: Blocks SOOP ad endpoints at URLSession layer
- **WebView ad UI hiding**: Removes ad banners and chat ads in WKWebView using DOM manipulation
- **Request interception**: Stubs fetch/XMLHttpRequest calls to ad endpoints
- **Theos build system**: Rootless package build (`.deb`) for modern jailbreaks
- **GitHub Actions CI/CD**: Automated build and IPA injection workflows

## Requirements

- macOS or Linux/WSL
- Theos + iOS SDK
- For IPA injection workflow: a decrypted IPA URL you are legally authorized to use

## GitHub Actions 사용 방법 / How to Use GitHub Actions

### 방법 1: 빌드 아티팩트 다운로드 / Method 1: Download Build Artifacts

**한글 / Korean:**

1. `Actions` 탭으로 이동합니다.
2. `Build SoopShield iOS` 워크플로우를 선택합니다.
3. `Run workflow`를 클릭합니다.
4. 워크플로우가 완료되면, 요약 페이지에서 아티팩트를 다운로드합니다.
5. `.deb` 파일과 `.dylib` 파일이 포함되어 있습니다.

**English:**

1. Navigate to the `Actions` tab.
2. Select the `Build SoopShield iOS` workflow.
3. Click `Run workflow`.
4. Once completed, download artifacts from the workflow summary.
5. Contains `.deb` package and `.dylib` file.

### 방법 2: IPA 주입 / Method 2: IPA Injection

**한글 / Korean:**

1. `Actions` 탭으로 이동합니다.
2. `Inject SoopShield into IPA` 워크플로우를 선택합니다.
3. `Run workflow`를 클릭하고 다음 입력값을 작성합니다:
   - `ipa_url`: 복호화된 IPA 파일의 다운로드 URL (필수)
   - `app_name`: 앱 이름 override (선택, 기본값: `SOOP`)
   - `bundle_id`: 번들 ID override (비워두면 원래 ID 유지)
   - `display_name`: 출력 IPA 파일 이름 (기본값: `SOOP+Shield`)
4. 워크플로우가 완료될 때까지 기다립니다.
5. Draft release에서 주입된 IPA를 다운로드합니다.

**English:**

1. Navigate to the `Actions` tab.
2. Select the `Inject SoopShield into IPA` workflow.
3. Click `Run workflow` and fill in the inputs:
   - `ipa_url`: Download URL of decrypted IPA file (required)
   - `app_name`: App name override (optional, default: `SOOP`)
   - `bundle_id`: Bundle ID override (leave empty to keep original)
   - `display_name`: Output IPA file name (default: `SOOP+Shield`)
4. Wait for workflow completion.
5. Download the injected IPA from the draft release.

## 로컬 빌드 / Local Build

```bash
export THEOS=/opt/theos
make clean
make package DEBUG=0 FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
```

Or:

```bash
bash build.sh
```

## 디버깅 / Debugging

```bash
log stream --predicate 'eventMessage CONTAINS "SoopShield"' --level debug
```

예상되는 로그 메시지 / Expected log messages:

- `[SoopShield] Tweak loaded in bundle: ...`
- `[SoopShield] Returned empty ad response: ...`
- `[SoopShield] Stubbed ad JSON response: ...`

주입된 앱이 즉시 종료하고 dyld 크래시(`arm64e.old does not match fat header (arm64e)`)가 발생할 경우, 최신 워크플로우로 재빌드하세요. IPA 주입은 `arm64` 전용 dylib를 사용합니다. App Store 앱은 `arm64`로 실행되므로, `arm64e` 슬라이스가 포함되면 dyld가 잘못된 슬라이스를 선택하여 시작할 때 충돌할 수 있습니다.

If the injected app exits immediately with a dyld crash like `arm64e.old does not match fat header (arm64e)`, rebuild with the latest workflow. IPA injection uses an `arm64`-only dylib because App Store apps run as `arm64`; including an `arm64e` slice can make dyld select the wrong slice and crash at launch.

## 프로젝트 구조 / Project Layout

```text
soop_shield/
├── Tweak.x                 # Main tweak implementation
├── Makefile                # Build configuration
├── control                 # Package metadata
├── SoopShield.plist        # Bundle filter configuration
├── build.sh                # Build script
├── README.md               # This file
├── README_INJECTOR.md      # Injector documentation
├── .github/
│   └── workflows/
│       ├── build.yml        # Build workflow
│       └── inject_ipa.yml   # IPA injection workflow
└── .gitignore              # Git ignore rules
```

## 참고 사항 / Notes

- **번들 ID 주의사항 / Bundle ID Warning**: 번들 ID를 변경하면 로그인, 키체인, 앱 그룹 기능이 작동하지 않을 수 있습니다.
- **앱 업데이트 / App Updates**: SOOP 앱이 업데이트되면 URL 패턴과 셀렉터가 변경될 수 있습니다.
- **IPA 제공 안함 / No IPA Files**: 이 저장소는 IPA 파일을 제공하지 않습니다.
- **번들 ID 확인 / Bundle ID Verification**: 트윅 로그가 표시되지 않으면 `SoopShield.plist`에서 대상 앱 번들 ID를 확인하세요.

## 면책 조항 / Disclaimer

**중요 / IMPORTANT**: 이 프로젝트를 사용하기 전에 다음 면책 조항을 주의 깊게 읽어주세요.

**한글 / Korean:**

1. **교육 및 연구 목적**: 이 프로젝트는 순수히 교육 및 연구 목적으로 제공됩니다.

2. **법적 책임**: 사용자는 자신의 관할권 내에서 적용되는 모든 법률, 규정, 서비스 약관을 준수할 책임이 있습니다. 이 프로젝트를 사용함으로써 발생하는 모든 법적 문제에 대해 개발자는 책임지지 않습니다.

3. **서비스 약관 위반**: 이 프로젝트는 SOOP 서비스 약관을 위반할 수 있습니다. 사용자는 본인의 계정 정지, 손해 배상, 기타 불이익에 대한 모든 책임을 집니다.

4. **비공식 프로젝트**: 이 프로젝트는 SOOP 주식회사와 전혀 무관한 비공식 프로젝트입니다. SOOP 공식적으로 승인되거나 지원되지 않습니다.

5. **배포 금지**: 이 프로젝트를 사용하여 생성된 IPA 파일을 법적 권리 없이 재배포하는 것은 엄격히 금지됩니다.

6. **보안 위험**: 수정된 IPA 파일을 설치할 경우 보안 위험에 노출될 수 있습니다. 본인의 책임 하에 사용해야 합니다.

7. **손해 배상**: 이 프로젝트의 사용으로 인해 발생하는 직간접적인 손해, 데이터 손실, 장기 손상, 계정 정지 등에 대해 개발자는 일체의 책임을 지지 않습니다.

8. **보증 부재**: 이 프로젝트는 어떠한 형태의 보증도 제공하지 않습니다. 소프트웨어는 "있는 그대로" 제공됩니다.

**English:**

1. **Educational and Research Purpose Only**: This project is provided strictly for educational and research purposes.

2. **Legal Liability**: Users are solely responsible for complying with all applicable laws, regulations, and terms of service in their jurisdiction. The developer assumes no liability for any legal consequences arising from the use of this project.

3. **Terms of Service Violation**: This project may violate the SOOP Terms of Service. Users assume full responsibility for any account suspension, damages, or other consequences.

4. **Unofficial Project**: This project is unofficial and has no affiliation with SOOP Co., Ltd. It is not officially endorsed or supported by SOOP.

5. **Distribution Prohibited**: Redistribution of IPA files generated using this project without proper legal authorization is strictly prohibited.

6. **Security Risks**: Installing modified IPA files may expose you to security risks. Use at your own risk.

7. **Damages**: The developer is not liable for any direct, indirect, incidental, special, or consequential damages resulting from the use of this project, including but not limited to data loss, device damage, or account suspension.

8. **No Warranty**: This project is provided without warranty of any kind. The software is provided "as is".

## 라이선스 / License

MIT License
