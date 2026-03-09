import torch
import re
from pathlib import Path
from transformers import (
    AutoTokenizer,
    AutoModelForSeq2SeqLM,
    AutoModelForSequenceClassification
)
from peft import PeftModel
from backend.ocr import extract_text_from_image_bytes

device = "cuda" if torch.cuda.is_available() else "cpu"

# summarizer
SUM_BASE = "google/flan-t5-small"
SUM_ADAPTER = Path("models/summarizer")

sum_tokenizer = AutoTokenizer.from_pretrained(SUM_ADAPTER)
sum_base_model = AutoModelForSeq2SeqLM.from_pretrained(SUM_BASE)
summarizer = PeftModel.from_pretrained(sum_base_model, SUM_ADAPTER)
summarizer.to(device).eval()

# importance
IMP_MODEL_PATH = "models/importance"
imp_tokenizer = AutoTokenizer.from_pretrained(IMP_MODEL_PATH)
importance_model = AutoModelForSequenceClassification.from_pretrained(IMP_MODEL_PATH)
importance_model.to(device).eval()

# qg
QG_BASE = "google/flan-t5-small"
QG_ADAPTER = Path("models/qg")

qg_tokenizer = AutoTokenizer.from_pretrained(QG_ADAPTER)
qg_base_model = AutoModelForSeq2SeqLM.from_pretrained(QG_BASE)
qg_model = PeftModel.from_pretrained(qg_base_model, QG_ADAPTER)
qg_model.to(device).eval()


def split_sentences(text: str):
    sentences = re.split(r'(?<=[.!?])\s+', text.strip())
    return [s.strip() for s in sentences if s.strip()]


def parse_summary_output(generated: str):
    summary = generated.strip()
    key_points = []

    lines = [line.strip() for line in generated.splitlines() if line.strip()]

    for i, line in enumerate(lines):
        if line.lower().startswith("summary:"):
            summary = line.split(":", 1)[1].strip()
        elif line.lower().startswith("key points"):
            for bullet in lines[i + 1:]:
                bullet = bullet.lstrip("-•").strip()
                if bullet:
                    key_points.append(bullet)
            break

    return summary, key_points


def summarize_text(text: str):
    prompt = "summarize: " + text
    inputs = sum_tokenizer(prompt, return_tensors="pt", truncation=True).to(device)

    with torch.no_grad():
        output = summarizer.generate(
            **inputs,
            max_new_tokens=150,
            num_beams=4,
            early_stopping=True
        )

    raw = sum_tokenizer.decode(output[0], skip_special_tokens=True)
    summary, key_points = parse_summary_output(raw)
    return raw, summary, key_points


def detect_importance(sentences):
    if not sentences:
        return []

    inputs = imp_tokenizer(
        sentences,
        return_tensors="pt",
        padding=True,
        truncation=True
    ).to(device)

    with torch.no_grad():
        outputs = importance_model(**inputs)

    preds = outputs.logits.argmax(dim=1)

    important = []
    for s, p in zip(sentences, preds):
        if p.item() == 1:
            important.append(s)

    return important


def generate_questions(sentences):
    questions = []

    for s in sentences:
        prompt = f"generate question: context: {s} answer: {s}"
        inputs = qg_tokenizer(prompt, return_tensors="pt", truncation=True).to(device)

        with torch.no_grad():
            outputs = qg_model.generate(
                **inputs,
                max_new_tokens=40,
                num_beams=4,
                early_stopping=True
            )

        q = qg_tokenizer.decode(outputs[0], skip_special_tokens=True).strip()
        questions.append(q)

    return questions


def analyze_text(text: str):
    raw_summary, summary, key_points = summarize_text(text)
    sentences = split_sentences(text)
    important_sentences = detect_importance(sentences)
    questions = generate_questions(important_sentences)

    return {
        "extracted_text": text,
        "raw_summary_output": raw_summary,
        "summary": summary,
        "key_points": key_points,
        "important_sentences": important_sentences,
        "questions": questions,
    }


def analyze_image(image_bytes: bytes):
    extracted_text = extract_text_from_image_bytes(image_bytes)
    return analyze_text(extracted_text)