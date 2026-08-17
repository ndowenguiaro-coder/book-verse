import re
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field, field_validator, ConfigDict

EMAIL_RE = re.compile(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")

class GenreBase(BaseModel):
    name: str = Field(min_length=1, max_length=50)
    @field_validator("name")
    @classmethod
    def clean_name(cls, value: str) -> str:
        value = " ".join(value.strip().split())
        if not value: raise ValueError("Le nom est obligatoire.")
        return value
class GenreCreate(GenreBase): pass
class GenreResponse(GenreBase):
    id: int
    model_config = ConfigDict(from_attributes=True)

class CategoryBase(BaseModel):
    name: str = Field(min_length=1, max_length=50)
    @field_validator("name")
    @classmethod
    def clean_name(cls, value: str) -> str:
        value = " ".join(value.strip().split())
        if not value: raise ValueError("Le nom est obligatoire.")
        return value
class CategoryCreate(CategoryBase): pass
class CategoryResponse(CategoryBase):
    id: int
    model_config = ConfigDict(from_attributes=True)

class BookBase(BaseModel):
    title: str = Field(min_length=1, max_length=150)
    author: str = Field(min_length=1, max_length=100)
    description: Optional[str] = Field(default=None, max_length=5000)
    audio_url: Optional[str] = Field(default=None, max_length=500)
    @field_validator("title", "author")
    @classmethod
    def clean_text(cls, value: str) -> str:
        return " ".join(value.strip().split())
class BookResponse(BookBase):
    id: int
    pdf_filename: str
    cover_filename: Optional[str] = None
    view_count: int
    created_at: datetime
    genre: Optional[GenreResponse] = None
    category: Optional[CategoryResponse] = None
    model_config = ConfigDict(from_attributes=True)

class FavoriteResponse(BaseModel):
    id: int
    book_id: int
    user_id: int
    model_config = ConfigDict(from_attributes=True)

class ReadingProgressUpdate(BaseModel):
    current_page: int = Field(ge=1, le=1000000)
class ReadingProgressResponse(BaseModel):
    book_id: int
    current_page: int
    updated_at: datetime
    model_config = ConfigDict(from_attributes=True)

class UserCreate(BaseModel):
    email: str
    password: str = Field(min_length=8, max_length=128)
    display_name: Optional[str] = Field(default=None, max_length=100)
    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: str) -> str:
        value = value.strip().lower()
        if not EMAIL_RE.match(value): raise ValueError("Adresse e-mail invalide.")
        return value
class UserLogin(BaseModel):
    email: str
    password: str = Field(min_length=1, max_length=128)
    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: str) -> str:
        value = value.strip().lower()
        if not EMAIL_RE.match(value): raise ValueError("Adresse e-mail invalide.")
        return value
class UserResponse(BaseModel):
    id: int
    email: str
    display_name: Optional[str] = None
    is_admin: bool = False
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)
class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
