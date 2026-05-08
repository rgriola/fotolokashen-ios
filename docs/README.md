# iOS Documentation Index

**Last Updated**: May 8, 2026  
**App Version**: 1.6.0

---

## Active Reference Docs

| File | Purpose | Status |
|------|---------|--------|
| [API.md](./API.md) | Mobile API reference | ⚠️ Partially stale — see deprecation notice inside |
| [AUTHENTICATION_FLOW.md](./AUTHENTICATION_FLOW.md) | OAuth2 + PKCE flow details | ✅ Current |
| [IOS_PHOTO_UPLOAD_SECURITY_REVIEW.md](./IOS_PHOTO_UPLOAD_SECURITY_REVIEW.md) | Upload security audit | ✅ Current (server-mediated pipeline) |
| [PRODUCTION_DATE_API.md](./PRODUCTION_DATE_API.md) | Production date field spec | ✅ Current |
| [APP_ICON_SETUP.md](./APP_ICON_SETUP.md) | App icon configuration | ✅ Current |

## Root-Level Docs

| File | Purpose |
|------|---------|
| [../README.md](../README.md) | App overview, setup, feature list, project structure — **primary reference** |
| [../CHANGELOG.md](../CHANGELOG.md) | Full version history with technical details |
| [../pipeline.md](../pipeline.md) | Photo upload pipeline architecture (Camera + Library paths) |

## Archive

The `archive/` directory contains historical docs organized as:

- **`archive/`** — Original archive from pre-v1.5 sessions (clustering, maps, phase summaries)
- **`archive/pre-v1.5-setup/`** — Session 1 setup guide and scratch files (Jan 2026, pre-Xcode project)
- **`archive/pipeline-audits/`** — Superseded pipeline audit summaries

> ⚠️ Do not delete archive docs — they contain historical implementation context.

---

## What to Read First (by role)

**Setting up the project for the first time** → `README.md → Getting Started`

**Understanding the upload pipeline** → `pipeline.md`, then `IOS_PHOTO_UPLOAD_SECURITY_REVIEW.md`

**Understanding auth flow** → `AUTHENTICATION_FLOW.md`

**Looking up an API endpoint** → `API.md` (check deprecation notice), then `README.md → API Endpoints`

**Understanding version history** → `CHANGELOG.md`
