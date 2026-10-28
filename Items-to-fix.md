## Items to Fix

- Login has many conflicting issues between Web and iOS.
  most recent issue is possible user double fire on login producing two identical tokens based on time.

# addressed Oct 12 2026.

- ~~iOS button does not protect from this.~~ **Fixed Oct 12 2026**: the double
  fire wasn't the login button (already guarded by `isLoading`) — it was the
  OAuth callback being delivered twice (`ASWebAuthenticationSession`'s
  completion handler and `onOpenURL` both calling `handleCallback(url:)` for
  the same redirect). `AuthService.exchangeCodeForTokens` now de-duplicates
  concurrent calls for the same authorization code via an in-flight task
  guard. Backend also hardened: `/api/auth/oauth/token` now atomically claims
  the authorization code (`updateMany` with `used: false`) instead of a
  racy check-then-update, and `generateToken` adds a unique `jti` claim so
  two tokens issued in the same second can never collide. Regression tests
  added: `src/app/api/auth/oauth/token/__tests__/route.test.ts`,
  `src/lib/__tests__/auth.test.ts` (web), and
  `fotolokashenTests/AuthServiceOAuthCallbackTests.swift` (iOS).

  > > >
