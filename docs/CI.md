# Automatic checks (Phase 12)

| Workflow | When | What |
|---|---|---|
| `build-apk.yml` | every push to main, or by hand | full build: analyse, tests, release APK + Play bundle |
| `checks.yml` | every other branch, every pull request, or by hand | analyse + tests only (about 3 minutes, no signing secrets needed) |
| `apply-update.yml` | by hand | unpacks the newest `saralbook-app-phase*.zip` from the repo root |

`apply-update.yml` never changes files in `.github/workflows`. To add or change a workflow, create the file on GitHub
(Add file > Create new file > `.github/workflows/checks.yml`) and paste the new content.

## What the checks guard
* `flutter analyze --no-fatal-infos`: any **warning** (for example an unused import) fails the build; hints do not.
* `flutter test`: everything under `test/` (maths, splitting, links, admin switches, push, screens).

## When a check fails
Open the failed run > the red step > read the first lines of the error. Send them to Claude with the phase you applied.
