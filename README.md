# BookVerse TOTAL

This package is an evolution of the original `BOOKprojet.zip` rather than a miniature reconstruction.

## What is included

- `app/` — working enhanced BookVerse source
  - `backend/` — FastAPI + SQLAlchemy
  - `flutter_app/` — Android/iOS/desktop Flutter client
  - `web_app/` — browser client
- `legacy/BOOKprojet_original.zip` — exact original project archive, preserved for rollback/reference
- `docs/` — architecture and animation documentation
- `pdf_library_app.zip` — original nested archive preserved from the source project

## Authentication changes

- E-mail normalized to lowercase.
- Stronger e-mail validation.
- Password minimum of 8 characters.
- Registration confirms the password in both Flutter and Web clients.
- JWT is checked against `/auth/me` at startup; expired/invalid tokens are removed.
- The first registered account becomes administrator so the initial library can be configured. Subsequent accounts are normal users.
- Production JWT secret must be supplied through `backend/.env`.

## Backend

```bash
cd app/backend
python -m venv .venv
# Windows: .venv\\Scripts\\activate
# Linux/macOS: source .venv/bin/activate
pip install -r requirements.txt
copy .env.example .env   # Windows
# cp .env.example .env  # Linux/macOS
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

## Flutter

```bash
cd app/flutter_app
flutter pub get
flutter run --dart-define=BOOKVERSE_API_URL=http://10.0.2.2:8000
```

For a physical Android phone, replace the API URL with the computer's LAN IP.

## Web

The FastAPI server can serve `web_app` at `/` and the API at `/api`-style routes directly from the same process.

## Verification performed in this environment

- Python source compilation/static syntax check.
- JavaScript syntax checks with Node.js.
- Archive integrity check.
- Source/file count comparison with the original.

Flutter SDK was not installed in the execution environment, so `flutter analyze` and `flutter test` could not be executed here. The source is nevertheless preserved and organized for a local Flutter build.
