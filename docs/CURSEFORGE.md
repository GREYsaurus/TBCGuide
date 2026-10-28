# Publishing on CurseForge

TBCGuide releases are built and checked locally (`tools/build.ps1 all`) and published as GitHub releases. The workflow `.github/workflows/curseforge.yml` then uploads **the same zip** to CurseForge whenever a GitHub release is published. Pre-releases go up as **beta**.

The one-time setup below needs the project owner's CurseForge account.

## 1. Create the project (once)

Sign in at <https://authors.curseforge.com> and start a new project:

| Field | Value |
|---|---|
| Game / class | World of Warcraft, Addons |
| Name | TBCGuide |
| Summary | Free TBC Classic 1-70 leveling guide with built-in quest data, talents and quest automation. |
| Description | paste `docs/curseforge/DESCRIPTION.md` |
| Main category | Quests & Leveling |
| Other categories (optional) | Map & Minimap, Class |
| License | GNU General Public License version 3 (GPLv3) |
| Logo / avatar | `docs/curseforge/logo.png` (400×400, original artwork: a compass with a guide arrow and quest marker) |
| Source URL | https://github.com/GREYsaurus/TBCGuide |
| Issues URL | https://github.com/GREYsaurus/TBCGuide/issues |

New projects, and each uploaded file, are reviewed by CurseForge moderation before they become public.

## 2. Connect GitHub (once)

1. Note the **project ID** shown on the project's page. TBCGuide's is **1771321**; it is also recorded in the TOC as `X-Curse-Project-ID`.
2. Create an API token: CurseForge account settings, then **API tokens**.
3. In GitHub, open the repository's **Settings > Secrets and variables > Actions**:
   - add the **secret** `CF_API_KEY` with the token;
   - add the **variable** `CURSEFORGE_PROJECT_ID` with the project ID.
   - Optional variable `CURSEFORGE_GAME_VERSION` (default `2.5.6`). The workflow looks up CurseForge's game version with this exact name and stops with a list of candidates if it does not find exactly one.

## 3. Upload

- **Existing release:** in GitHub, go to **Actions > Publish to CurseForge > Run workflow** and enter the tag (for example `v0.2.0`).
- **Future releases:** publishing a GitHub release triggers the upload automatically.
- **By hand (alternative):** on the CurseForge project, upload `TBCGuide-<version>.zip` from the GitHub release. Choose game version *2.5.6* (Burning Crusade Classic) and release type *Beta* for pre-releases.

Without the secret and variable, the workflow skips the upload with a notice instead of failing.
