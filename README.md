# SoopShield iOS Tweak

SoopShield is an iOS tweak for SOOP that ports ad-blocking rules from the browser extension (`extension/AdBlock`) into native iOS hook points.

It blocks known ad request endpoints at URLSession level and applies best-effort ad/banner hiding in `WKWebView`.

## Features

- Native URL request pre-blocking for SOOP ad endpoints
- WKWebView DOM-based ad/banner hiding and close-button auto click
- Theos rootless package build (`.deb`)
- GitHub Actions workflows for:
  - tweak build artifacts (`.deb`, `.dylib`)
  - dylib injection into user-supplied IPA

## Source Mapping (Extension -> Tweak)

Rules were mapped from:

- `extension/AdBlock/blockAds.json`
- `extension/AdBlock/hideMainBanner.js`
- `extension/AdBlock/hideChatBanner.js`
- `extension/AdBlock/hideBanner.css`

## Requirements

- macOS or Linux/WSL
- Theos + iOS SDK
- For IPA injection workflow: a decrypted IPA URL you are legally allowed to use

## Quick Start (GitHub Actions)

1. Open the `Actions` tab.
2. Run `Inject SoopShield into IPA`.
3. Fill inputs:
   - `ipa_url`: decrypted IPA download URL
   - `app_name`: optional app name override (default `SOOP`)
   - `bundle_id`: leave empty unless necessary
   - `display_name`: output IPA file name
4. Wait for workflow completion.
5. Download the IPA from the draft release.

## Local Build

```bash
export THEOS=/opt/theos
make clean
make package DEBUG=0 FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
```

Or:

```bash
bash build.sh
```

## Debugging

```bash
log stream --predicate 'eventMessage CONTAINS "SoopShield"' --level debug
```

Expected logs include:

- `[SoopShield] Tweak loaded in bundle: ...`
- `[SoopShield] Blocked ad request: ...`

If the injected app exits immediately with a dyld crash like `arm64e.old does not match fat header (arm64e)`, rebuild with the latest workflow. IPA injection uses an `arm64`-only dylib because App Store apps such as SOOP run as `arm64`; including an `arm64e` slice can make dyld select the wrong slice and abort at launch.

## Project Layout

```text
soop_shield/
├── Tweak.x
├── Makefile
├── control
├── SoopShield.plist
├── build.sh
├── README.md
├── README_INJECTOR.md
├── .github/workflows/build.yml
├── .github/workflows/inject_ipa.yml
└── extension/
    └── AdBlock/
```

## Notes

- Bundle ID override can break login/keychain/app-group behavior.
- URL patterns/selectors may change after SOOP app updates.
- This repository does not provide IPA files.
- If no tweak logs appear, verify your target app bundle ID in `SoopShield.plist`.

## Disclaimer

- This project is for educational and research purposes only.
- You are responsible for legal/terms compliance and any account/device impact.
- This project is unofficial and not affiliated with SOOP Co., Ltd.
- Do not redistribute generated IPA files without legal rights.

## License

MIT
