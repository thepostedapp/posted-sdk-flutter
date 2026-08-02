# Dead link sweep (POS-526)

Every link in this repo's docs (READMEs, CHANGELOG, examples, and code-comment URLs in config
files) was enumerated and HTTP-checked (200 = keep, 404/dead/error-redirect = dead). Internal
anchors and relative file paths were checked against actual headings/files.

## Result: no dead links found in the doc scope

| repo-relative-path | dead URL | referencing doc |
| --- | --- | --- |
| — | none found | — |

All external links returned `200`:

- `README.md`, `CHANGELOG.md`, `example/README.md`: `https://posted.app`,
  `https://posted.app/auth/signup`, `https://developer.apple.com/account`
- `pubspec.yaml` / `example/pubspec.yaml` doc-comment links: `https://dart.dev/tools/pub/pubspec`,
  `https://flutter.dev/to/asset-from-package`, `https://flutter.dev/to/resolution-aware-images`,
  `https://flutter.dev/to/font-from-package`
- `analysis_options.yaml` / `example/analysis_options.yaml`:
  `https://dart.dev/guides/language/analysis-options`, `https://dart.dev/tools#ides-and-editors`,
  `https://dart.dev/lints`, `https://dart.dev/tools/pub/dependencies#version-constraints`
- `example/android/app/build.gradle.kts`: `https://flutter.dev/to/review-gradle-config`
- `ios/posted_sdk.podspec`: `http://guides.cocoapods.org/syntax/podspec.html`,
  `https://developer.apple.com/documentation/bundleresources/privacy_manifest_files`

All internal/relative links resolved (files exist, anchors match actual headings):
`README.md#migrating-from-2x-to-30`, `README.md#migration-from-detour_flutter_plugin`,
`README.md#1-resolveinitiallink--resolveapplaunchconfig`,
`README.md#2-processlinkstring-url-is-deprecated`, `README.md#custom-scheme-for-host-apps`,
`./example`, `./example/README.md`, `./CHANGELOG.md`, `./LICENSE`,
`CHANGELOG.md → ./README.md#migrating-from-2x-to-30`.

Test fixture URLs (`detour.dev`, `godetour.dev`, `ex.co`, `example.com` in `test/**`) are
intentionally-fake sample domains used as test data, not documentation links, and were excluded
from this sweep.

## Flagged, not removed — out of scope for this sweep

`pubspec.yaml:5-6` (`repository`/`issue_tracker` → `github.com/thepostedapp/posted-sdk-flutter`)
returns `404` to an anonymous request. This is package manifest metadata, not one of the doc
categories in scope for POS-526 (READMEs/CHANGELOG/MIGRATION/examples/code-comment URLs), and an
anonymous 404 from GitHub is ambiguous — it is returned identically for a nonexistent repo and for
an existing **private** repo. Flagging for board/CTO to confirm whether `thepostedapp/posted-sdk-flutter`
should be public, or the URL is wrong, before anyone edits publish-affecting package metadata.
