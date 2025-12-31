# Repository Guidelines

## Project Structure & Module Organization
- `storj_uploader_frontend_container_app/`: React + TypeScript frontend (components in `src/components`, API in `src/api.ts`).
- `storj_uploader_backend_api_container_app/`: FastAPI backend (entry in `main.py`, models in `models.py`).
- `storj_container_app/`: Storj/rclone uploader utilities and container scripts.
- `android_storj_uploader/`: Kotlin Android app (source under `app/src/main`).
- `flutter_app_storj_uploader/`: Flutter web app.
- `infrastructure/`: Azure Container Apps Bicep templates and deployment docs.

## Build, Test, and Development Commands
Frontend (React):
```bash
cd storj_uploader_frontend_container_app
npm install
npm start              # dev server (port 9010)
npm run build          # production build
npm test               # Jest via react-scripts
npm run test:e2e        # Playwright e2e
```
Backend (FastAPI):
```bash
cd storj_uploader_backend_api_container_app
pip install -r requirements.txt
python main.py          # runs on port 8010 by default
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
Android:
```bash
cd android_storj_uploader
./gradlew assembleDebug
./gradlew installDebug
```
Flutter:
```bash
cd flutter_app_storj_uploader
flutter pub get
flutter run -d web-server --web-port 8080
```
Azure build/push: `az acr build --registry <acr> --image storj-frontend:latest ./storj_uploader_frontend_container_app`.

## Coding Style & Naming Conventions
- Follow existing file formatting; avoid reflowing unrelated code.
- TypeScript/React: PascalCase components, camelCase props, shared types in `src/types.ts`.
- Python: 4-space indentation, snake_case functions/vars.
- Kotlin: PascalCase classes, camelCase methods, keep XML IDs descriptive.
- Tailwind CSS is the primary styling approach in the web frontend.

## Testing Guidelines
- Frontend uses `react-scripts test` (Jest) and Playwright for e2e.
- Backend has no formal test runner configured; use `/health` and upload curl calls for smoke tests.
- Android/Flutter tests are not standardized yet; add tests under the conventional `app/src/test` or `test/` folders when introducing new logic.

## Commit & Pull Request Guidelines
- History shows a mix of Conventional Commit prefixes (`feat:`, `fix:`) and short messages (e.g., `m`); prefer descriptive `feat:`/`fix:`/`chore:` subjects for clarity.
- PRs should include: a brief summary, linked issue (if any), and screenshots for UI changes (frontend or Android).

## Configuration & Secrets
- Frontend: `.env` with `REACT_APP_API_URL`.
- Backend: `.env` for upload/temp dirs and size limits.
- Android: `android_storj_uploader/local.properties` for API base URL.
- Infrastructure: `infrastructure/main.bicepparam` for ACR and resource settings.
- Do not commit secrets (access grants, client secrets); use Key Vault or local env files.
