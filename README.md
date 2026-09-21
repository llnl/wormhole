# Wormhole

## Development

Start the token service and its database:

```
docker compose up
```

The API is then available at `http://localhost:5000` (override with `TOKEN_SERVICE_PORT`).

Run the UI against it:

```
cd ui
npm install
npm run dev
```

The UI dev server runs at `http://localhost:5173` and proxies `/token-service` to the backend above.

### Testing

```
cd ui
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

## Governance

Contributions are welcome. Contributors should look in `CONTRIBUTING.md` for project guidelines on how to create and structure pull requests.

This project is licensed under the Apache 2.0 license with LLVM exception. The full license text is available in `LICENSE`.

LLNL-CODE-2020712
