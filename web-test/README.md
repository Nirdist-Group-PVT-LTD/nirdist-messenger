# Web Test App

This is a lightweight browser app for testing Nirdist backend endpoints without Flutter build steps.

## What it does

- Checks `/api/health`
- Provides preset requests for auth, social, and chat APIs
- Lets you send custom HTTP requests to any endpoint
- Supports optional Bearer token
- Saves base URL and token in local storage

## Run locally

Use any static server from the `app` folder.

### Option 1: Python

```bash
cd app
python -m http.server 5500
```

Open:

- `http://localhost:5500/web-test/`

### Option 2: VS Code Live Server

Open `web-test/index.html` and start Live Server.

## Suggested base URLs

- Render: `https://nirdist-backend-uctd.onrender.com`
- Local: `http://localhost:8080`

## Notes

- If Render free instance is sleeping, first request can take time.
- CORS is enabled in backend security config for testing.
- For protected endpoints, paste a JWT in Bearer Token.
