# IPA Injector Guide (SoopShield)

This repository includes `Inject SoopShield into IPA` GitHub Actions workflow.

## Quick Steps

1. Open `Actions` tab.
2. Run `Inject SoopShield into IPA`.
3. Fill inputs:
   - `ipa_url`: decrypted IPA download URL
   - `app_name`: optional display app name override
   - `bundle_id`: keep empty unless you must change it
   - `display_name`: output IPA file name
4. Wait for workflow completion.
5. Download generated IPA from draft release.

## Important

- Bundle ID override can break login/keychain/app-group behavior.
- This workflow does not provide IPA files by itself.
- Use only IPAs you are legally allowed to handle.
