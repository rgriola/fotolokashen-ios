# iOS Authentication Flow

> How the Fotolokashen iOS app authenticates via OAuth 2.0 PKCE, handles email verification, and manages deep links.
>
> **Full cross-platform docs**: See `fotolokashen/docs/guides/authentication-flow.md` in the web repo.

---

## Login Flow

```
LoginView → AuthService.startLogin()
  → ASWebAuthenticationSession opens fotolokashen.com/login
  → User logs in on web
  → OAuth redirect: fotolokashen://oauth-callback?code=xxx
  → AuthService.handleCallback()
  → POST /api/auth/oauth/token (code exchange)
  → access_token + refresh_token saved to Keychain
  → isAuthenticated = true
```

---

## Registration Flow (New Account)

```
LoginView → AuthService.startRegistration()
  → ASWebAuthenticationSession opens fotolokashen.com/register
  → User fills form → backend detects iOS via User-Agent
  → "Check Your Email" card shown in panel
  → User closes panel → opens email → taps verify link

  Email link: /verify-email?token=xxx&platform=ios

  →  verify-email page calls GET /api/auth/verify-email
  → Token verified → one-time autoLoginToken generated
  → autoLoginToken stored as SHA-256 hash in DB
  → Page redirects: fotolokashen://email-verified?token=xxx

  → DeepLinkManager.handleURL() receives deep link
  → AuthService.handleAutoLogin(token)
  → POST /api/auth/auto-login { token, client_id, device_name }
  → Server hashes token → finds user → returns access_token
  → Tokens saved to Keychain → isAuthenticated = true
  → Safari panel dismissed
```

---

## ⚠️ Known UX Gap — "Email Already Exists"

**Current behavior (broken):**

When a user opens the Create Account panel but already has an account:
1. `POST /api/auth/register` returns `409 EMAIL_EXISTS`
2. The web form shows an inline error message (toast not visible in Safari panel)
3. **The panel stays open — the user has no way to navigate to login from within the panel**

**Expected behavior:**

The panel should close and the app should prompt the user to log in instead.

**Required fix (not yet implemented):**

| Where | Change |
|---|---|
| `RegisterForm.tsx` | Detect `EMAIL_EXISTS` + iOS context → show brief message → redirect: `fotolokashen://register-redirect?action=login&reason=account_exists` |
| `AuthService.startRegistration()` | Append `&source=ios` to registration URL |
| `DeepLinkManager.swift` | Handle `register-redirect` → dismiss panel → alert user → call `startLogin()` |

See `fotolokashen/docs/guides/authentication-flow.md` for full implementation spec.

---

## Deep Links

| URL | Handler | Purpose |
|-----|---------|---------| 
| `fotolokashen://oauth-callback?code=xxx` | `AuthService.handleCallback()` | OAuth code exchange after login |
| `fotolokashen://email-verified?token=xxx` | `DeepLinkManager` → auto-login | Post-verification auto-login |
| `fotolokashen://register-redirect?action=login&reason=account_exists` | `DeepLinkManager` | ⚠️ **Not yet implemented** — "email exists" redirect |
| `fotolokashen://location/{id}` | `DeepLinkManager.navigateToLocation()` | Open a specific location |

---

## Token Security

All auth tokens (verification, reset, auto-login) are stored as **SHA-256 hashes** in the database. The raw token is sent to the user and hashed server-side on verification.

The `autoLoginToken` is:
- Generated as `crypto.randomBytes(32).toString('base64url')` on the web server
- Sent raw as a URL param in the `fotolokashen://email-verified?token=xxx` deep link
- Stored in DB as `SHA-256(rawToken)`
- On `POST /api/auth/auto-login`, the server hashes the incoming token before lookup

The token is **single-use** (cleared immediately on first use) and expires after **5 minutes**.

---

## How Platform Detection Works

The web backend detects iOS via the `User-Agent` header during registration and appends `&platform=ios` to the verification email link. This lets the `verify-email` web page trigger `fotolokashen://email-verified` instead of the web login redirect.

> **Limitation:** User-Agent sniffing can fail on non-standard browsers. A future improvement is for `AuthService.startRegistration()` to append `?source=ios` explicitly to the registration URL, making detection reliable and explicit.

---

## Key Files

| File | Role |
|------|------|
| `AuthService.swift` | OAuth PKCE flow, `startLogin()`, `startRegistration()`, `handleAutoLogin()` |
| `DeepLinkManager.swift` | URL routing, `emailVerified` flag, deep link dispatching |
| `ContentView.swift` / `LoginView` | Observes `emailVerified`, auto-triggers login |
| `Info.plist` | Registers `fotolokashen` custom URL scheme |
| `ConfigLoader.swift` | Backend URL, OAuth client ID, redirect URI |
