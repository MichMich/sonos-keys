# Releases

The Release workflow runs when a tag such as `v1.0.0` reaches GitHub.
The tag must point to a commit on `main`. Use three numeric version parts.

The workflow builds one app for Intel and Apple Silicon on a temporary macOS runner.
It sets the app version from the tag and the build number from the workflow run number.
It signs the app with Developer ID Application and the hardened runtime.
It submits the app to Apple, checks acceptance, and staples the notarization ticket to the app.
It publishes a ZIP and a SHA-256 checksum only after these checks pass.
After publication, it updates the version and checksum in `MichMich/homebrew-tap`.
An older release run cannot downgrade the cask. A repeated run with unchanged content does not create another commit.

## Repository secrets

Configure these secrets in GitHub Settings → Secrets and variables → Actions:

| Secret | Value |
| --- | --- |
| `DEVELOPER_ID_CERTIFICATE_BASE64` | Base64-encoded PKCS#12 file with the distribution certificate and its private key. |
| `DEVELOPER_ID_CERTIFICATE_PASSWORD` | The PKCS#12 password. |
| `APPLE_API_PRIVATE_KEY` | The contents of the App Store Connect team API key `.p8` file. |
| `APPLE_API_KEY_ID` | The API key ID. |
| `APPLE_API_ISSUER_ID` | The API issuer ID. |
| `HOMEBREW_TAP_TOKEN` | A fine-grained GitHub token for `MichMich/homebrew-tap`, with Contents read and write permission. |

Use a dedicated team API key with the Developer role.
Keep certificates, passwords, and private keys outside this repository.
The workflow imports the certificate into a temporary keychain and removes temporary credentials after the job.
GitHub also discards the hosted runner after the job.

For the Homebrew token, select only `homebrew-tap` under repository access.
Grant Contents read and write permission. Metadata read access is automatic.
Store the token in the `sonos-keys` repository secret named `HOMEBREW_TAP_TOKEN`.
Renew the token before its expiration date. Do not put the token in this repository or a chat.

## Publish a version

First check the app on a Mac. See the release checks in the README.
Commit the release code to `main`, then create and push the version tag:

```sh
git tag v1.0.0
git push origin v1.0.0
```

Open GitHub Actions to check the Release run.
After success, download the ZIP from GitHub Releases and copy the app to Applications.
The app still needs Accessibility, Input Monitoring, and local network permissions.

If a run fails, fix the cause and retry the run when the tagged source needs no change.
If the source needs a change, use a new version tag.
A repeated successful run replaces the assets for that tag.
If the Homebrew step fails, the app release remains available. Correct the token or cask issue, then retry the job.

## Decisions and follow-up

- Use one universal ZIP to keep the download choice simple.
- Use native Xcode tools and GitHub CLI. No extra release framework is required.
- Pin the checkout action to a commit. Credentials are available only in the steps that need them.
- Apple API authentication passed. The `v0.1.0` build stopped on an unsupported About-panel option.
- The About panel uses the copyright text from `Info.plist`. The `v0.1.1` tag checks the corrected build and notarization.
- Next task: download the first release and check startup, media keys, permissions, and the About panel.

See [Apple notarization](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)
and [GitHub certificate setup](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications).
