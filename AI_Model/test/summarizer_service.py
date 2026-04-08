import re
from pathlib import Path
from typing import List

import torch
from fastapi import FastAPI
from pydantic import BaseModel
from transformers import AutoTokenizer, AutoModelForSeq2SeqLM
from peft import PeftModel

BASE_MODEL = "google/flan-t5-small"
ADAPTER_DIR = Path("models/summarizer")

app = FastAPI(title="StudyMate Summarizer API")


class SummarizeRequest(BaseModel):
    text: str


class SummarizeResponse(BaseModel):
    summary: str


tokenizer = None
model = None
device = "cuda" if torch.cuda.is_available() else "cpu"


def load_model():
    global tokenizer, model
    tokenizer = AutoTokenizer.from_pretrained(ADAPTER_DIR)
    base_model = AutoModelForSeq2SeqLM.from_pretrained(BASE_MODEL)
    model = PeftModel.from_pretrained(base_model, ADAPTER_DIR)
    model.to(device).eval()


def clean_text(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r'(?m)^\s*\d+\s*$', '', text)
    text = re.sub(r'[ \t]+', ' ', text)
    text = re.sub(r'(?<![.!?:])\n(?!\n)', ' ', text)
    text = re.sub(r'\n{2,}', '\n\n', text)
    return text.strip()


def split_into_chunks(text: str, max_chars: int = 1800) -> List[str]:
    paragraphs = [p.strip() for p in text.split("\n\n") if p.strip()]
    chunks = []
    current = ""

    for p in paragraphs:
        if len(p) > max_chars:
            # hard split very long paragraph
            for i in range(0, len(p), max_chars):
                sub = p[i:i + max_chars].strip()
                if sub:
                    if current:
                        chunks.append(current)
                        current = ""
                    chunks.append(sub)
            continue

        if len(current) + len(p) + 2 <= max_chars:
            current = f"{current}\n\n{p}".strip()
        else:
            if current:
                chunks.append(current)
            current = p

    if current:
        chunks.append(current)

    return chunks


def summarize_chunk(text: str) -> str:
    prompt = "Summarize the following study notes clearly:\n\n" + text

    inputs = tokenizer(
        prompt,
        return_tensors="pt",
        truncation=True,
        max_length=512
    ).to(device)

    with torch.no_grad():
        out = model.generate(
            **inputs,
            max_new_tokens=100,
            num_beams=4,
            early_stopping=True,
            no_repeat_ngram_size=3
        )

    return tokenizer.decode(out[0], skip_special_tokens=True).strip()


def merge_summaries(chunk_summaries: List[str]) -> str:
    if not chunk_summaries:
        return "No summary could be generated."

    if len(chunk_summaries) == 1:
        return chunk_summaries[0]

    combined = "\n".join(f"- {s}" for s in chunk_summaries)

    final_prompt = (
        "Combine the following partial summaries into one clear study summary:\n\n"
        + combined
    )

    inputs = tokenizer(
        final_prompt,
        return_tensors="pt",
        truncation=True,
        max_length=512
    ).to(device)

    with torch.no_grad():
        out = model.generate(
            **inputs,
            max_new_tokens=140,
            num_beams=4,
            early_stopping=True,
            no_repeat_ngram_size=3
        )

    return tokenizer.decode(out[0], skip_special_tokens=True).strip()


def summarize_big_text(text: str) -> str:
    cleaned = clean_text(text)
    if not cleaned:
        return "No summary could be generated."

    chunks = split_into_chunks(cleaned, max_chars=1800)
    chunk_summaries = []

    for chunk in chunks[:8]:
        s = summarize_chunk(chunk)
        if s:
            chunk_summaries.append(s)

    return merge_summaries(chunk_summaries)


@app.on_event("startup")
def startup_event():
    load_model()


@app.post("/summarize", response_model=SummarizeResponse)
def summarize(req: SummarizeRequest):
    summary = summarize_big_text(req.text)
    return SummarizeResponse(summary=summary)