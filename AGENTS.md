This file is the context for coding agents (Claude Code, Codex, OpenHands, …) working on this repository. The human-facing editing guide — adding events/news, changing design, debugging deploys — lives in [`docs/editing.md`](docs/editing.md).

## Project context

`landau` is the public website for the **LANDAU Kernel** initiative — an *upstream-first* Linux kernel fork project led by the [Russian Linux Kernel Community (RULKC)](https://rulkc.org). The repo is content-only (no application code): project description, planned and past events ("Открытый микрофон" series, RULKC Meetup, OSDevConf), news, and contact channels.

Authoritative content language is **Russian**. English appears only in the project name, slogan, and a few section headings.

## Stack

- **Hugo extended**, version pinned in `.hugo-version` (currently `0.160.1`).
- **Hugo binary tarball SHA256** pinned in `.hugo-sha256` (`hugo_extended_${ver}_linux-amd64.tar.gz`). The deploy workflow downloads from `github.com/gohugoio/hugo/releases` and verifies before extracting. Both files are bumped atomically by `.github/workflows/hugo-update.yml`.
- **Theme** is `pages-themes/hacker` (the original GitHub Pages theme) **flattened into plain CSS** at `static/css/hacker.css`. Source commit is recorded in the file header. Background sprites live at `static/images/{bkg,bullet}.png`.
- **Layouts** are minimal Go templates in `layouts/_default/{baseof,single,list}.html` + `layouts/index.html`. They reproduce the Jekyll theme's `_layouts/default.html` skeleton (header with site title + description, container with `#main_content`).
- **Domain**: `landau.one`, served by nginx on a self-hosted server.
- **Build & deploy**: GitHub Actions → rsync into the nginx docroot.

## Build, preview, deploy

There is no Node, Ruby, or Go toolchain to install — Hugo is a single binary.

| Action | Command | Notes |
| --- | --- | --- |
| Local preview | `hugo server -D` | Install via `brew install hugo` (extended, latest stable). Local version may differ slightly from the CI pin; that's OK for previewing markdown. |
| Local build | `hugo --gc --minify` | Output is `public/`. |
| New event | `hugo new events/<slug>/index.md` | Uses `archetypes/events.md` as template. Page bundle so photos/files can sit alongside. |
| New news post | `hugo new news/<slug>.md` | Uses `archetypes/news.md`. |
| Production deploy | `git push origin main` | Triggers `.github/workflows/deploy.yml`. |

Until you have content ready to publish, keep `draft: true` in frontmatter — Hugo skips drafts by default in production builds.

## Repository layout

```
.github/
  workflows/
    ci.yml              # build sanity check + artifact upload (push, PR)
    spelling.yml        # codespell (EN typos) + hunspell (RU+EN, with allow list)
    release-drafter.yml # push to main → recompute YYYY.MM.N, refresh draft release
    release-deploy.yml  # release: published → build + rsync to landau.one + prune
    hugo-update.yml     # weekly cron: bump .hugo-version + .hugo-sha256, open PR
  dependabot.yml        # github-actions ecosystem only
  release-drafter.yml   # release-drafter config: changelog template only
.codespellrc            # codespell config (skip patterns, ignore-words-list)
.spellcheck-allow.txt   # extra allowed words for hunspell (proper nouns, jargon)
.hugo-version           # pinned Hugo version (e.g. 0.160.1)
.hugo-sha256            # SHA256 of hugo_extended_<ver>_linux-amd64.tar.gz
hugo.toml               # site config: baseURL=https://landau.one/, relativeURLs=true
archetypes/             # `hugo new` templates: default, events, news
scripts/
  spellcheck.sh         # markdown stripper + hunspell -d ru_RU,en_US driver
content/
  _index.md             # home page (was Jekyll's index.md)
  events/
    _index.md           # /events/ landing
    open-mic-001/
      index.md          # event page bundle; photos go alongside this file
  news/
    _index.md           # /news/ landing (placeholder, no posts yet)
layouts/
  _default/{baseof,single,list}.html
  index.html
static/
  css/hacker.css        # theme, plain CSS
  images/{bkg,bullet}.png
  rulkc.png             # RULKC logo, referenced from _index.md
docs/
  editing.md            # editor's quick reference (human-facing)
README.md               # title only, not part of rendered site
AGENTS.md               # this file (agent context)
LICENSE
```

## URL conventions

- `relativeURLs = true` in `hugo.toml`. All HTML `href`/`src` attributes that start with `/` are rewritten by Hugo to relative paths from the current page. RSS, sitemap, canonical, and Open Graph still emit absolute URLs against `baseURL = "https://landau.one/"` (those need to be absolute by spec).
- When linking between pages from inside markdown, write a leading-slash absolute path (`[home](/)`, `[event](/events/open-mic-001/)`) — Hugo will canonicalise it. Avoid `./foo.md`-style Jekyll-flavoured links.
- The event page `content/events/open-mic-001/index.md` carries `aliases: ['/open_mic_27_03_2026.html']`. Hugo emits a tiny HTML redirect at that path so any old GitHub Pages link still works.

## Theme update procedure

The `pages-themes/hacker` upstream is rarely changed (last commit on master is from 2024), so we don't track it as a submodule — we lifted the SCSS once. To refresh:

1. Pick a new commit SHA in `https://github.com/pages-themes/hacker`.
2. Pull the SCSS sources (`_sass/_default_colors.scss`, `_sass/jekyll-theme-hacker.scss`, `_sass/rouge-base16-dark.scss`) and re-flatten variables into `static/css/hacker.css`. Update the comment header with the new commit SHA.
3. If `assets/images/bkg.png` or `bullet.png` changed, refresh `static/images/{bkg,bullet}.png`.
4. Verify with `hugo server` that the page still renders identically (no visual regression is the whole point of having lifted the theme).

There is no SCSS toolchain in this repo on purpose — the CSS is final, hand-flattened, and human-readable.

## CI and release pipeline

The release model is **PR-based, manually-published** (inspired by `jethome-iot/docs`):

1. Work happens on feature branches; PRs target `main`.
2. On every push and PR, two workflows run:
   - **`ci.yml`** — installs the pinned Hugo, builds with `--panicOnWarning`, uploads `public/` as an artifact (kept ≤ 7 days, ≤ 10 newest).
   - **`spelling.yml`** — `codespell` (English typos) + `scripts/spellcheck.sh` (hunspell with `ru_RU,en_US`, filtered through `.spellcheck-allow.txt`). Both must pass.
3. Once a PR is merged into `main`, **`release-drafter.yml`** runs: it computes the next CalVer tag (`YYYY.MM.N`, where N restarts at 0 each calendar month), then refreshes the draft GitHub Release with all merged PRs since the previous tag, listed flat in chronological order.
4. The maintainer **manually publishes the draft release** when ready. That fires **`release-deploy.yml`**, which builds Hugo with `HUGO_PARAMS_VERSION=<tag>`, rsyncs `public/` into the nginx docroot at `landau.one`, then prunes published releases (and their tags) beyond the 7 most recent.

A push to `main` therefore does **not** publish to landau.one — it only updates CI, the draft release, and the artifact list. Production deploys require an explicit human action (clicking "Publish release" in the GitHub UI, or running `release-deploy.yml` via `workflow_dispatch`).

### Footer version

`layouts/_default/baseof.html` renders a small footer with the build's release tag. The value comes from Hugo's environment-driven params convention:

- `release-deploy.yml` sets `HUGO_PARAMS_VERSION=<release tag>` for production builds → footer shows `v2026.05.0`.
- `ci.yml` sets `HUGO_PARAMS_VERSION=dev-<sha>` for sanity-build artifacts → footer shows `vdev-abc1234`.
- A bare local `hugo server` with no env var → the template falls back to `dev`.

### Versioning algorithm (CalVer `YYYY.MM.N`)

`.github/workflows/release-drafter.yml` derives the next tag from the most recent existing tag:

- If the latest tag's year + month equals today's UTC year + month → `N = latest.N + 1`.
- Otherwise (new month, or no tags yet) → `N = 0`.

So the first release in any month is `.0`, not `.1`. Bash arithmetic uses `10#` prefix to force base-10 parsing (otherwise `08` would be misread as octal and break in August/September).

### Spell checking

- **codespell** (`.codespellrc`) — fast English typo scan; trips on common dropped/transposed-letter misspellings. Effectively zero false positives on our content; runs everywhere.
- **hunspell** via `scripts/spellcheck.sh` — strips YAML frontmatter, fenced code blocks, inline code spans, HTML tags, URLs, emails, and common markdown punctuation, then feeds the remainder through `hunspell -d ru_RU,en_US -l`. Words in `.spellcheck-allow.txt` are accepted as correct. Add proper nouns and technical jargon (LANDAU, RULKC, BSP, frontmatter, …) there as content grows.
- The script can also be run locally: `bash scripts/spellcheck.sh` (needs `hunspell-ru` and `hunspell-en-us` packages).

### Supply chain

- **All Action versions are pinned to specific tags** (e.g. `actions/checkout@v6.0.2`, `release-drafter/release-drafter@v7.2.0`). Dependabot watches the `github-actions` ecosystem and opens weekly PRs.
- **Hugo is bumped by a custom cron workflow**, not Dependabot. The workflow enforces a 7-day release soak (skips releases younger than a week, per the global supply-chain rule), fetches the official `checksums.txt` from the GitHub release to populate `.hugo-sha256`, smoke-tests `hugo --gc --minify` against the current site, then opens a PR. Manual trigger via `workflow_dispatch`.
- **No third-party action is used for release pruning or artifact pruning** — both are done with `gh api` directly. Smaller trust surface, no dependency on community accounts.
- **Deploy secrets** required in repo settings:
  - `DEPLOY_SSH_KEY` — full PEM, including the `-----BEGIN/END-----` lines
  - `DEPLOY_SSH_HOST` — hostname (matches the entry in `DEPLOY_SSH_KNOWNHOSTS`)
  - `DEPLOY_SSH_USER` — SSH login user
  - `DEPLOY_SSH_PATH` — absolute path on the server, the nginx docroot, no trailing slash. The deploy step rsyncs `public/` directly into this path with `--delete` (no atomic release directory yet — there's a brief window during sync where the site is in an inconsistent state).
  - `DEPLOY_SSH_KNOWNHOSTS` — output of `ssh-keyscan -t ed25519,rsa <host>`. The deploy step writes this to `~/.ssh/known_hosts` and uses `StrictHostKeyChecking=yes`.

## Editorial conventions

These are conventions visible in the existing two pages — keep them when adding content:

- Top-level page heading uses an emoji prefix (`# ⚛️ …`, `# 🎙️ …`). Emoji is part of the brand voice.
- Section dividers are `---` on their own line.
- Event pages start with the structure in `archetypes/events.md`: 📅 date, ⏰ time, 📍 format, 👥 organizer block at the top; "Регистрация и контакты" at the bottom; "⬅️ Вернуться на главную" backlink as the last line.
- Contact channels in `_index.md` are rendered as a **two-column markdown table**, with the logo card as a separate single-row table — preserve this layout, since plain-CSS rendering depends on it.
- Russian typography: keep punctuation, em-dashes, and quotation marks as they are.

## Things to verify before claiming a deploy task is done

- `hugo --gc --minify` exits 0 with no warnings other than informational ones.
- The home page renders the LANDAU description, the contact table, the RULKC logo card, and a working link into `/events/open-mic-001/`.
- `/open_mic_27_03_2026.html` redirects to the event page (Hugo writes a meta-refresh stub there from the `aliases` frontmatter).
- All `mailto:`, `https://t.me/…`, and `https://rulkc.org` links remain clickable and unchanged.
- After a `git push origin main`, the GitHub Actions run for `.github/workflows/deploy.yml` succeeds end to end (build + rsync). Confirm `landau.one` actually serves the new content.
