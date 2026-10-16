# TestFlight

GitHub Actions archives `com.lojo.PilgrimAtlas` on every push to `main` after unit tests and UI tests pass. The build number is the GitHub Actions run number. A re-run of the same run appends `.attempt`. Settings shows that number.

Sideloading with xtool still uses team `N9H4648NB9` and the install id `XTL-N9H4648NB9.com.lojo.PilgrimAtlas`. TestFlight uses the unprefixed bundle id `com.lojo.PilgrimAtlas`.

Never commit API keys, `.p8` files, or provisioning profiles.

## GitHub secrets

Copy these from [lojo-watch-remote](https://github.com/macdadyj/lojo-watch-remote) (Settings → Secrets and variables → Actions). Same names:

| Secret | What it is |
| --- | --- |
| `ASC_KEY_ID` | App Store Connect API key id |
| `ASC_ISSUER_ID` | App Store Connect issuer id |
| `ASC_KEY_P8` | The `.p8` key, PEM or base64 |
| `DEVELOPMENT_TEAM` | Apple Developer Team ID (not the xtool `N9H4648NB9` prefix) |

## App Store Connect clicks

Do these once. The workflow cannot create an App ID or an app record.

1. Sign in at [developer.apple.com/account](https://developer.apple.com/account) with the Lojo team that owns Watch Remote.
2. **Certificates, Identifiers & Profiles** → **Identifiers** → **+**.
3. Choose **App IDs** → **App**.
4. Description `Pilgrim Atlas`. Bundle ID **Explicit** `com.lojo.PilgrimAtlas`. Continue → Register.
5. Open [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **Apps** → **+** → **New App**.
6. Platform **iOS**. Name `Pilgrim Atlas`. Primary language English (U.S.). Bundle ID `com.lojo.PilgrimAtlas`. SKU `pilgrim-atlas`. User Access Full Access.
7. After the first upload, **TestFlight** → the iOS build → **Internal Testing**. If no group exists, create **Internal** and add Jon.
8. Confirm **Export Compliance** is already answered (the build sets `ITSAppUsesNonExemptEncryption` to false).
9. Install from TestFlight. **Settings** in the app shows **Build** matching the Actions run number.

If step 4 says the bundle id is taken, someone already registered `com.lojo.PilgrimAtlas`. Use that App ID and pick it in step 6.

## Local checks that do not need a Mac

```bash
python3 scripts/asc_signing.py --self-test
python3 scripts/asc_testflight.py --self-test
scripts/archive-upload.sh --self-test
python3 -m pytest pipeline/tests/test_rules.py pipeline/tests/test_built_pack.py -q
```
