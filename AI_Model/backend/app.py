from fastapi import FastAPI, UploadFile, File, HTTPException
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import tempfile
import os

from backend.pipeline import (
    process_text_structure,
    generate_keypoints_and_flashcards,
    rank_topics_and_subtopics,
    summarize_selected_topic,
    generate_quiz_for_topic,
    analyze_image_text,
)
from backend.pdf_utils import extract_text_from_pdf_file

app = FastAPI(title="StudyMate AI API")

MAX_TEXT_LENGTH = 50000


# -----------------------------
# Request models
# -----------------------------

class NotesRequest(BaseModel):
    text: str


class ChunkItemRequest(BaseModel):
    chunk_index: int
    chunk_text: str
    topic_label: str
    subtopic_label: str
    section_type: str
    topic_priority: str


class TopicSummaryRequest(BaseModel):
    extracted_text: str
    chunks: List[ChunkItemRequest]
    topic_label: str
    subtopic_label: Optional[str] = None


class QuizRequest(BaseModel):
    extracted_text: str
    chunks: List[ChunkItemRequest]
    topic_label: str
    subtopic_label: Optional[str] = None
    max_questions: int = 5


# -----------------------------
# Response models
# -----------------------------

class ChunkTopicItem(BaseModel):
    chunk_index: int
    chunk_text: str
    topic_label: str
    subtopic_label: str
    section_type: str
    topic_priority: str


class TopicGroupItem(BaseModel):
    topic_label: str
    subtopics: List[str]
    chunk_indexes: List[int]


class FlashcardItem(BaseModel):
    front: str
    back: str


class KeyPointItem(BaseModel):
    text: str
    importance: str
    score: float
    topic_label: str
    subtopic_label: str


class QuizItem(BaseModel):
    question: str
    option_a: str
    option_b: str
    option_c: str
    correct_option: str
    explanation: str
    topic_label: str
    subtopic_label: str


class StructuredNotesResponse(BaseModel):
    extracted_text: str
    chunks: List[ChunkTopicItem]
    topics: List[TopicGroupItem]


class KeyPointsResponse(BaseModel):
    key_points: List[KeyPointItem]
    flashcards: List[FlashcardItem]


class ImportanceResponse(BaseModel):
    important_topics: List[str]
    important_subtopics: List[str]


class TopicSummaryResponse(BaseModel):
    topic_label: str
    subtopic_label: Optional[str]
    summary: str


class QuizResponse(BaseModel):
    topic_label: str
    subtopic_label: Optional[str]
    questions: List[QuizItem]


# -----------------------------
# Helpers
# -----------------------------

def _truncate_text(text: str) -> str:
    text = (text or "").strip()
    if not text:
        raise HTTPException(status_code=400, detail="Text is empty.")
    if len(text) > MAX_TEXT_LENGTH:
        text = text[:MAX_TEXT_LENGTH]
    return text


# -----------------------------
# Root
# -----------------------------

@app.get("/")
def root():
    return {"message": "StudyMate AI backend is running"}


# -----------------------------
# Text processing
# -----------------------------

@app.post("/process_notes", response_model=StructuredNotesResponse)
def process_notes(req: NotesRequest):
    cleaned_text = _truncate_text(req.text)
    return process_text_structure(cleaned_text)


# -----------------------------
# Image processing
# -----------------------------

@app.post("/process_notes_image", response_model=StructuredNotesResponse)
async def process_notes_image(file: UploadFile = File(...)):
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Only image files are allowed.")

    image_bytes = await file.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="Uploaded image is empty.")

    extracted_text = analyze_image_text(image_bytes)
    extracted_text = _truncate_text(extracted_text)
    return process_text_structure(extracted_text)


# -----------------------------
# PDF processing
# -----------------------------

@app.post("/process_notes_pdf", response_model=StructuredNotesResponse)
async def process_notes_pdf(file: UploadFile = File(...)):
    if file.content_type != "application/pdf":
        raise HTTPException(status_code=400, detail="Only PDF files are allowed.")

    pdf_bytes = await file.read()
    if not pdf_bytes:
        raise HTTPException(status_code=400, detail="Uploaded PDF is empty.")

    tmp_path = None
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".pdf") as tmp:
            tmp.write(pdf_bytes)
            tmp_path = tmp.name

        extracted_text = extract_text_from_pdf_file(tmp_path)
        extracted_text = _truncate_text(extracted_text)

        return process_text_structure(extracted_text)

    finally:
        if tmp_path and os.path.exists(tmp_path):
            os.remove(tmp_path)


# -----------------------------
# Key points + flashcards
# -----------------------------

@app.post("/generate_keypoints", response_model=KeyPointsResponse)
def generate_keypoints(req: NotesRequest):
    cleaned_text = _truncate_text(req.text)
    return generate_keypoints_and_flashcards(cleaned_text)


# -----------------------------
# Importance
# -----------------------------

@app.post("/rank_importance", response_model=ImportanceResponse)
def rank_importance(req: NotesRequest):
    cleaned_text = _truncate_text(req.text)
    return rank_topics_and_subtopics(cleaned_text)


# -----------------------------
# Topic/Subtopic summary
# -----------------------------

@app.post("/summarize_topic", response_model=TopicSummaryResponse)
def summarize_topic(req: TopicSummaryRequest):
    if not req.extracted_text or not req.extracted_text.strip():
        raise HTTPException(status_code=400, detail="Extracted text is empty.")

    return summarize_selected_topic(
        extracted_text=req.extracted_text,
        chunks=[c.model_dump() for c in req.chunks],
        topic_label=req.topic_label,
        subtopic_label=req.subtopic_label,
    )


# -----------------------------
# Quiz generation
# -----------------------------

@app.post("/generate_quiz", response_model=QuizResponse)
def generate_quiz(req: QuizRequest):
    if not req.extracted_text or not req.extracted_text.strip():
        raise HTTPException(status_code=400, detail="Extracted text is empty.")

    return generate_quiz_for_topic(
        extracted_text=req.extracted_text,
        chunks=[c.model_dump() for c in req.chunks],
        topic_label=req.topic_label,
        subtopic_label=req.subtopic_label,
        max_questions=req.max_questions,
    )