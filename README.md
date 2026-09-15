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

## Governance

Contributions are welcome. Contributors should look in `CONTRIBUTING.md` for project guidelines on how to create and structure pull requests.

This project is licensed under the Apache 2.0 license with LLVM exception. The full license text is available in `LICENSE`.

LLNL-CODE-2020712
