# Wormhole UI

## Development

Start the token service and its database (from this directory):

```
docker compose up
```

The API is then available at `http://localhost:5000` (override with `TOKEN_SERVICE_PORT`).

Run the UI against it:

```
npm install
npm run dev
```

The UI dev server runs at `http://localhost:5173` and proxies `/token-service` to the backend above.

### Testing

```
npm run test
```

Playwright/Chromium tests that mock the token-service API, so no backend is needed. The mocks
and the app's `Token`/`TokenRepository` are typed against `src/api-types.ts`, generated from
the backend's OpenAPI spec via `npm run gen:api-types` (needs a running backend). `npm run
check:api-types` fails if regenerating produces a diff.

```
npm run test:integration
```

Runs the same flow against a real backend instead of mocks (start it first, per above).
Assumes the database is empty and restores that state afterward, so it runs alone and serially.
