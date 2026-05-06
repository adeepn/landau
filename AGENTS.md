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
    deploy.yml          # build + rsync to landau.one on push to main
    hugo-update.yml     # weekly cron: bump .hugo-version + .hugo-sha256, open PR
  dependabot.yml        # github-actions ecosystem only
.hugo-version           # pinned Hugo version (e.g. 0.160.1)
.hugo-sha256            # SHA256 of hugo_extended_<ver>_linux-amd64.tar.gz
hugo.toml               # site config: baseURL=https://landau.one/, relativeURLs=true
archetypes/             # `hugo new` templates: default, events, news
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

## CI / supply chain

- **All Action versions are pinned to specific tags** (e.g. `actions/checkout@v6.0.2`). Dependabot watches the `github-actions` ecosystem and opens weekly PRs.
- **Hugo is bumped by a custom cron workflow**, not Dependabot. The workflow enforces a 7-day release soak (skips releases younger than a week, per the global supply-chain rule), fetches the official `checksums.txt` from the GitHub release to populate `.hugo-sha256`, smoke-tests `hugo --gc --minify` against the current site, then opens a PR. Manual trigger via `workflow_dispatch`.
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
