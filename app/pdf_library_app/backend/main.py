import os
import re
import shutil
import uuid
from typing import List, Optional

from dotenv import load_dotenv
load_dotenv()

from fastapi import FastAPI, Depends, HTTPException, UploadFile, File, Form, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text
from sqlalchemy.orm import Session

import models
import schemas
import auth
from database import engine, get_db

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
UPLOAD_DIR = os.path.join(BASE_DIR, "uploads")
PDF_DIR = os.path.join(UPLOAD_DIR, "pdfs")
COVER_DIR = os.path.join(UPLOAD_DIR, "covers")
WEB_APP_DIR = os.path.join(BASE_DIR, "..", "web_app")
os.makedirs(PDF_DIR, exist_ok=True)
os.makedirs(COVER_DIR, exist_ok=True)

models.Base.metadata.create_all(bind=engine)

# Lightweight compatibility migration for databases created by earlier BookVerse builds.
def migrate_legacy_schema():
    with engine.begin() as conn:
        cols = {row[1] for row in conn.execute(text("PRAGMA table_info(users)"))}
        if cols and "is_admin" not in cols:
            conn.execute(text("ALTER TABLE users ADD COLUMN is_admin BOOLEAN NOT NULL DEFAULT 0"))

migrate_legacy_schema()

app = FastAPI(
    title="BookVerse API",
    description="Bibliothèque numérique, lecture PDF, favoris, progression et audio.",
    version="2.0.0",
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in os.getenv("CORS_ORIGINS", "*").split(",") if o.strip()],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.mount("/static/covers", StaticFiles(directory=COVER_DIR), name="covers")

MAX_PDF_BYTES = int(os.getenv("MAX_PDF_MB", "100")) * 1024 * 1024
MAX_COVER_BYTES = int(os.getenv("MAX_COVER_MB", "10")) * 1024 * 1024
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".gif"}


def _safe_filename(filename: str, fallback_ext: str) -> str:
    base = os.path.basename(filename or "file")
    stem, ext = os.path.splitext(base)
    stem = re.sub(r"[^a-zA-Z0-9._-]+", "_", stem).strip("._") or "file"
    ext = ext.lower() or fallback_ext
    return f"{uuid.uuid4().hex}_{stem[:80]}{ext}"


def _save_upload(upload: UploadFile, destination: str, max_bytes: int) -> str:
    written = 0
    name = _safe_filename(upload.filename or "file", ".bin")
    path = os.path.join(destination, name)
    try:
        with open(path, "wb") as buffer:
            while True:
                chunk = upload.file.read(1024 * 1024)
                if not chunk:
                    break
                written += len(chunk)
                if written > max_bytes:
                    raise HTTPException(status_code=413, detail="Fichier trop volumineux.")
                buffer.write(chunk)
    except Exception:
        if os.path.exists(path):
            os.remove(path)
        raise
    return name


def _get_book(book_id: int, db: Session) -> models.Book:
    book = db.query(models.Book).filter(models.Book.id == book_id).first()
    if not book:
        raise HTTPException(status_code=404, detail="Livre introuvable.")
    return book

@app.get("/health")
def health():
    return {"status": "ok", "service": "bookverse-api", "version": app.version}

# ---------------- AUTH ----------------
@app.post("/auth/register", response_model=schemas.UserResponse, status_code=201)
def register(user_in: schemas.UserCreate, db: Session = Depends(get_db)):
    email = user_in.email.strip().lower()
    if db.query(models.User).filter(models.User.email == email).first():
        raise HTTPException(status_code=409, detail="Un compte existe déjà avec cet e-mail.")
    user_count = db.query(models.User).count()
    user = models.User(
        email=email,
        hashed_password=auth.hash_password(user_in.password),
        display_name=(user_in.display_name or "").strip() or None,
        is_admin=(user_count == 0),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user

@app.post("/auth/login", response_model=schemas.Token)
def login(credentials: schemas.UserLogin, db: Session = Depends(get_db)):
    email = credentials.email.strip().lower()
    user = db.query(models.User).filter(models.User.email == email).first()
    if not user or not auth.verify_password(credentials.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="E-mail ou mot de passe incorrect.")
    return schemas.Token(access_token=auth.create_access_token({"sub": str(user.id)}))

@app.get("/auth/me", response_model=schemas.UserResponse)
def get_me(current_user: models.User = Depends(auth.get_current_user)):
    return current_user

# ---------------- GENRES/CATEGORIES ----------------
@app.post("/genres/", response_model=schemas.GenreResponse, status_code=201)
def create_genre(genre: schemas.GenreCreate, db: Session = Depends(get_db), _: models.User = Depends(auth.require_admin)):
    if db.query(models.Genre).filter(models.Genre.name.ilike(genre.name)).first():
        raise HTTPException(status_code=409, detail="Ce genre existe déjà.")
    item = models.Genre(name=genre.name)
    db.add(item); db.commit(); db.refresh(item); return item

@app.get("/genres/", response_model=List[schemas.GenreResponse])
def get_genres(db: Session = Depends(get_db)):
    return db.query(models.Genre).order_by(models.Genre.name.asc()).all()

@app.delete("/genres/{genre_id}", status_code=204)
def delete_genre(genre_id: int, db: Session = Depends(get_db), _: models.User = Depends(auth.require_admin)):
    item = db.query(models.Genre).filter(models.Genre.id == genre_id).first()
    if not item: raise HTTPException(status_code=404, detail="Genre introuvable.")
    if db.query(models.Book).filter(models.Book.genre_id == genre_id).first():
        raise HTTPException(status_code=409, detail="Ce genre est encore utilisé par un livre.")
    db.delete(item); db.commit()

@app.post("/categories/", response_model=schemas.CategoryResponse, status_code=201)
def create_category(category: schemas.CategoryCreate, db: Session = Depends(get_db), _: models.User = Depends(auth.require_admin)):
    if db.query(models.Category).filter(models.Category.name.ilike(category.name)).first():
        raise HTTPException(status_code=409, detail="Cette catégorie existe déjà.")
    item = models.Category(name=category.name)
    db.add(item); db.commit(); db.refresh(item); return item

@app.get("/categories/", response_model=List[schemas.CategoryResponse])
def get_categories(db: Session = Depends(get_db)):
    return db.query(models.Category).order_by(models.Category.name.asc()).all()

@app.delete("/categories/{category_id}", status_code=204)
def delete_category(category_id: int, db: Session = Depends(get_db), _: models.User = Depends(auth.require_admin)):
    item = db.query(models.Category).filter(models.Category.id == category_id).first()
    if not item: raise HTTPException(status_code=404, detail="Catégorie introuvable.")
    if db.query(models.Book).filter(models.Book.category_id == category_id).first():
        raise HTTPException(status_code=409, detail="Cette catégorie est encore utilisée par un livre.")
    db.delete(item); db.commit()

# ---------------- BOOKS ----------------
@app.post("/books/", response_model=schemas.BookResponse, status_code=201)
async def upload_book(
    title: str = Form(...), author: str = Form(...), description: Optional[str] = Form(None),
    genre_id: int = Form(...), category_id: int = Form(...), audio_url: Optional[str] = Form(None),
    pdf_file: UploadFile = File(...), cover_file: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db), _: models.User = Depends(auth.require_admin),
):
    if not (pdf_file.filename or "").lower().endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Le fichier principal doit être un PDF.")
    if not db.query(models.Genre).filter(models.Genre.id == genre_id).first(): raise HTTPException(404, "Genre introuvable.")
    if not db.query(models.Category).filter(models.Category.id == category_id).first(): raise HTTPException(404, "Catégorie introuvable.")
    pdf_name = _save_upload(pdf_file, PDF_DIR, MAX_PDF_BYTES)
    cover_name = None
    if cover_file and cover_file.filename:
        ext = os.path.splitext(cover_file.filename)[1].lower()
        if ext not in IMAGE_EXTENSIONS: raise HTTPException(400, "Format de couverture non pris en charge.")
        cover_name = _save_upload(cover_file, COVER_DIR, MAX_COVER_BYTES)
    try:
        book = models.Book(title=" ".join(title.strip().split()), author=" ".join(author.strip().split()), description=description, genre_id=genre_id, category_id=category_id, pdf_filename=pdf_name, cover_filename=cover_name, audio_url=audio_url)
        db.add(book); db.commit(); db.refresh(book); return book
    except Exception:
        for p in [os.path.join(PDF_DIR, pdf_name), os.path.join(COVER_DIR, cover_name) if cover_name else None]:
            if p and os.path.exists(p): os.remove(p)
        db.rollback(); raise

@app.get("/books/", response_model=List[schemas.BookResponse])
def get_books(genre_id: Optional[int] = None, category_id: Optional[int] = None, search: Optional[str] = None, sort_by: Optional[str] = None, skip: int = 0, limit: int = 50, db: Session = Depends(get_db)):
    skip = max(0, skip); limit = min(max(1, limit), 100)
    query = db.query(models.Book)
    if genre_id is not None: query = query.filter(models.Book.genre_id == genre_id)
    if category_id is not None: query = query.filter(models.Book.category_id == category_id)
    if search and search.strip():
        like = f"%{search.strip()}%"
        query = query.filter(models.Book.title.ilike(like) | models.Book.author.ilike(like))
    if sort_by == "popular": query = query.order_by(models.Book.view_count.desc(), models.Book.id.desc())
    else: query = query.order_by(models.Book.created_at.desc(), models.Book.id.desc())
    return query.offset(skip).limit(limit).all()

@app.get("/books/{book_id}", response_model=schemas.BookResponse)
def get_book_details(book_id: int, db: Session = Depends(get_db)): return _get_book(book_id, db)

@app.patch("/books/{book_id}/view", response_model=schemas.BookResponse)
def register_book_view(book_id: int, db: Session = Depends(get_db)):
    book = _get_book(book_id, db); book.view_count += 1; db.commit(); db.refresh(book); return book

@app.get("/books/{book_id}/download")
def download_pdf(book_id: int, db: Session = Depends(get_db)):
    book = _get_book(book_id, db); path = os.path.join(PDF_DIR, book.pdf_filename)
    if not os.path.isfile(path): raise HTTPException(404, "Le fichier PDF n'existe plus sur le serveur.")
    return FileResponse(path=path, filename=os.path.basename(book.pdf_filename), media_type="application/pdf")

# ---------------- FAVORITES ----------------
@app.post("/favorites/", response_model=schemas.FavoriteResponse, status_code=201)
def add_favorite(book_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    _get_book(book_id, db)
    existing = db.query(models.Favorite).filter_by(book_id=book_id, user_id=current_user.id).first()
    if existing: return existing
    fav = models.Favorite(book_id=book_id, user_id=current_user.id); db.add(fav); db.commit(); db.refresh(fav); return fav

@app.delete("/favorites/{book_id}", status_code=204)
def remove_favorite(book_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    fav = db.query(models.Favorite).filter_by(book_id=book_id, user_id=current_user.id).first()
    if fav: db.delete(fav); db.commit()

@app.get("/favorites/", response_model=List[schemas.BookResponse])
def list_favorites(db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    return db.query(models.Book).join(models.Favorite, models.Favorite.book_id == models.Book.id).filter(models.Favorite.user_id == current_user.id).all()

# ---------------- READING PROGRESS ----------------
@app.put("/books/{book_id}/progress", response_model=schemas.ReadingProgressResponse)
def update_reading_progress(book_id: int, payload: schemas.ReadingProgressUpdate, db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    _get_book(book_id, db)
    progress = db.query(models.ReadingProgress).filter_by(book_id=book_id, user_id=current_user.id).first()
    if progress: progress.current_page = payload.current_page
    else: progress = models.ReadingProgress(book_id=book_id, user_id=current_user.id, current_page=payload.current_page); db.add(progress)
    db.commit(); db.refresh(progress); return progress

@app.get("/books/{book_id}/progress", response_model=Optional[schemas.ReadingProgressResponse])
def get_reading_progress(book_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    _get_book(book_id, db)
    return db.query(models.ReadingProgress).filter_by(book_id=book_id, user_id=current_user.id).first()

if os.path.isdir(WEB_APP_DIR):
    app.mount("/", StaticFiles(directory=WEB_APP_DIR, html=True), name="web_app")
