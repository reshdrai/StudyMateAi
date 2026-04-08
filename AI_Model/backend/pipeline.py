import os
import re
import json
from pathlib import Path
from typing import List, Dict, Any, Optional, Tuple

import torch
from transformers import AutoTokenizer, AutoModelForCausalLM
from peft import PeftModel

from backend.ocr import extract_text_from_image_bytes


# ---------------------------------
# Cache on D drive
# ---------------------------------

os.environ.setdefault("HF_HOME", "D:/hf_cache")
os.environ.setdefault("TRANSFORMERS_CACHE", "D:/hf_cache/transformers")
os.environ.setdefault("HF_DATASETS_CACHE", "D:/hf_cache/datasets")
os.environ.setdefault("TORCH_HOME", "D:/hf_cache/torch")
os.environ.setdefault("TMPDIR", "D:/hf_cache/tmp")
os.environ.setdefault("TEMP", "D:/hf_cache/tmp")
os.environ.setdefault("TMP", "D:/hf_cache/tmp")

for p in [
    Path("D:/hf_cache"),
    Path("D:/hf_cache/transformers"),
    Path("D:/hf_cache/datasets"),
    Path("D:/hf_cache/torch"),
    Path("D:/hf_cache/tmp"),
]:
    p.mkdir(parents=True, exist_ok=True)


# ---------------------------------
# Config
# ---------------------------------

device = "cuda" if torch.cuda.is_available() else "cpu"

BASE_DIR = Path(__file__).resolve().parent
PROJECT_DIR = BASE_DIR.parent

DEFAULT_BASE_MODEL = "HuggingFaceTB/SmolLM2-360M-Instruct"

TOPIC_ADAPTER = PROJECT_DIR / "models" / "topic_extractor"
KEYPOINTS_ADAPTER = PROJECT_DIR / "models" / "keypoints_flashcards"
QUIZ_ADAPTER = PROJECT_DIR / "models" / "quiz_generator"
SUMMARIZER_ADAPTER = PROJECT_DIR / "models" / "summarizer"


# ---------------------------------
# Lazy model state
# ---------------------------------

topic_tokenizer = None
topic_model = None

keypoints_tokenizer = None
keypoints_model = None

quiz_tokenizer = None
quiz_model = None

sum_tokenizer = None
sum_model = None


# ---------------------------------
# Model loading
# ---------------------------------

def _read_adapter_config(adapter_path: Path) -> Dict[str, Any]:
    config_path = adapter_path / "adapter_config.json"
    if not config_path.exists():
        return {}

    try:
        with open(config_path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        print(f"[WARNING] Could not read adapter config from {config_path}: {e}", flush=True)
        return {}


def _resolve_base_model_name(adapter_path: Path) -> str:
    adapter_cfg = _read_adapter_config(adapter_path)
    base_model_name = adapter_cfg.get("base_model_name_or_path")

    if base_model_name and str(base_model_name).strip():
        return str(base_model_name).strip()

    return DEFAULT_BASE_MODEL


def _safe_load_adapter(adapter_path: Path):
    """
    Loads a LoRA adapter safely.
    Returns (tokenizer, model) or (None, None) if not found / failed.
    """
    if not adapter_path.exists():
        print(f"[INFO] Adapter not found, using fallback logic: {adapter_path}", flush=True)
        return None, None

    try:
        base_model_name = _resolve_base_model_name(adapter_path)
        print(f"[INFO] Loading adapter: {adapter_path}", flush=True)
        print(f"[INFO] Resolved base model: {base_model_name}", flush=True)

        try:
            tokenizer = AutoTokenizer.from_pretrained(adapter_path, use_fast=True)
        except Exception:
            tokenizer = AutoTokenizer.from_pretrained(base_model_name, use_fast=True)

        if tokenizer.pad_token is None:
            tokenizer.pad_token = tokenizer.eos_token

        base_model = AutoModelForCausalLM.from_pretrained(
            base_model_name,
            low_cpu_mem_usage=True,
        )

        model = PeftModel.from_pretrained(base_model, adapter_path)
        model.to(device)
        model.eval()

        return tokenizer, model

    except Exception as e:
        print(f"[WARNING] Failed to load adapter {adapter_path}: {e}", flush=True)
        return None, None


def _get_topic_model():
    global topic_tokenizer, topic_model
    if topic_tokenizer is None or topic_model is None:
        topic_tokenizer, topic_model = _safe_load_adapter(TOPIC_ADAPTER)
    return topic_tokenizer, topic_model


def _get_keypoints_model():
    global keypoints_tokenizer, keypoints_model
    if keypoints_tokenizer is None or keypoints_model is None:
        keypoints_tokenizer, keypoints_model = _safe_load_adapter(KEYPOINTS_ADAPTER)
    return keypoints_tokenizer, keypoints_model


def _get_quiz_model():
    global quiz_tokenizer, quiz_model
    if quiz_tokenizer is None or quiz_model is None:
        quiz_tokenizer, quiz_model = _safe_load_adapter(QUIZ_ADAPTER)
    return quiz_tokenizer, quiz_model


def _get_sum_model():
    global sum_tokenizer, sum_model
    if sum_tokenizer is None or sum_model is None:
        sum_tokenizer, sum_model = _safe_load_adapter(SUMMARIZER_ADAPTER)
    return sum_tokenizer, sum_model


# ---------------------------------
# Cleaning / chunking
# ---------------------------------

def clean_text(text: str) -> str:
    text = (text or "").replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"(?m)^\s*\d+\s*$", "", text)
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"(?<![.!?:])\n(?!\n)", " ", text)
    text = re.sub(r"\n{2,}", "\n\n", text)
    return text.strip()


def split_into_chunks(text: str, max_chars: int = 1200) -> List[str]:
    paragraphs = [p.strip() for p in text.split("\n\n") if p.strip()]
    chunks = []
    current = ""

    for p in paragraphs:
        if len(p) > max_chars:
            if current:
                chunks.append(current)
                current = ""
            for i in range(0, len(p), max_chars):
                sub = p[i:i + max_chars].strip()
                if sub:
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


def split_sentences(text: str) -> List[str]:
    if not text or not text.strip():
        return []
    sentences = re.split(r"(?<=[.!?])\s+", text.strip())
    return [s.strip() for s in sentences if s.strip() and len(s.strip()) > 20]


# ---------------------------------
# Shared helpers
# ---------------------------------

def _extract_json(text: str) -> Dict[str, Any]:
    match = re.search(r"\{.*\}", text, flags=re.DOTALL)
    if not match:
        return {}
    try:
        return json.loads(match.group(0))
    except Exception:
        return {}


def _generate_json(prompt: str, tokenizer, model, max_new_tokens: int = 160) -> Dict[str, Any]:
    if tokenizer is None or model is None:
        return {}

    full_prompt = (
        "<|system|>\n"
        "You are a helpful study-note processing assistant.\n"
        "<|user|>\n"
        f"{prompt}\n"
        "<|assistant|>\n"
    )

    inputs = tokenizer(
        full_prompt,
        return_tensors="pt",
        truncation=True,
        max_length=256,
    ).to(device)

    with torch.no_grad():
        output = model.generate(
            **inputs,
            max_new_tokens=max_new_tokens,
            do_sample=False,
            repetition_penalty=1.1,
            pad_token_id=tokenizer.pad_token_id,
            eos_token_id=tokenizer.eos_token_id,
        )

    text = tokenizer.decode(output[0], skip_special_tokens=True)
    text = text.split("<|assistant|>")[-1].strip()
    return _extract_json(text)


def _normalize_topic_label(text: str) -> str:
    text = re.sub(r"\s+", " ", (text or "").strip())
    return text if text else "General Topic"


def _normalize_subtopic_label(text: str) -> str:
    text = re.sub(r"\s+", " ", (text or "").strip())
    return text if text else "General Subtopic"


def _heuristic_topic_structure(chunk_text: str) -> Dict[str, str]:
    lines = [x.strip() for x in chunk_text.split("\n") if x.strip()]
    first_line = lines[0] if lines else ""
    text = chunk_text.lower()

    topic_label = "General Topic"
    subtopic_label = "General Subtopic"
    section_type = "concept"
    topic_priority = "medium"

    if re.search(r"\bintroduction\b", text):
        topic_label = "Introduction"
        subtopic_label = "Overview"
        section_type = "introduction"
        topic_priority = "medium"
    elif re.search(r"\bcharacteristics\b", text):
        topic_label = "Computer Fundamentals"
        subtopic_label = "Characteristics"
        section_type = "definition_features"
        topic_priority = "high"
    elif re.search(r"\bgeneration\b", text):
        topic_label = "Computer Fundamentals"
        subtopic_label = "Computer Generations"
        section_type = "classification"
        topic_priority = "high"
    elif re.search(r"\balgorithm\b", text):
        topic_label = "Problem Solving"
        subtopic_label = "Algorithms"
        section_type = "steps_definition"
        topic_priority = "high"
    elif re.search(r"\bflowchart\b", text):
        topic_label = "Problem Solving"
        subtopic_label = "Flowcharts"
        section_type = "symbols_steps"
        topic_priority = "high"
    elif re.search(r"\bpseudocode\b", text):
        topic_label = "Problem Solving"
        subtopic_label = "Pseudocode"
        section_type = "steps_definition"
        topic_priority = "high"
    elif re.search(r"\bcompiler\b|\binterpreter\b|\bassembler\b", text):
        topic_label = "Computer Software"
        subtopic_label = "Language Translators"
        section_type = "types_comparison"
        topic_priority = "high"
    elif re.search(r"\barray\b", text):
        topic_label = "C Programming"
        subtopic_label = "Arrays"
        section_type = "syntax_example"
        topic_priority = "high"
    elif re.search(r"\bpointer\b", text):
        topic_label = "C Programming"
        subtopic_label = "Pointers"
        section_type = "syntax_example"
        topic_priority = "high"
    elif re.search(r"\bstructure\b|\bunion\b", text):
        topic_label = "C Programming"
        subtopic_label = "Structures and Unions"
        section_type = "syntax_example"
        topic_priority = "high"
    elif re.search(r"\bclass\b|\boop\b|\binheritance\b|\bpolymorphism\b", text):
        topic_label = "C++"
        subtopic_label = "Object Oriented Programming"
        section_type = "definition_concepts"
        topic_priority = "high"

    if first_line and len(first_line) < 80 and first_line.isupper():
        topic_label = _normalize_topic_label(first_line.title())

    return {
        "topic_label": topic_label,
        "subtopic_label": subtopic_label,
        "section_type": section_type,
        "topic_priority": topic_priority,
    }


def _predict_topic_structure(chunk_text: str) -> Dict[str, str]:
    prompt = (
        "Extract topic structure from the study note chunk.\n"
        "Return only JSON with keys: topic_label, subtopic_label, section_type, topic_priority.\n"
        f"Text: {chunk_text}"
    )

    tokenizer, model = _get_topic_model()
    result = _generate_json(prompt, tokenizer, model, max_new_tokens=80)

    if not result:
        return _heuristic_topic_structure(chunk_text)

    return {
        "topic_label": _normalize_topic_label(result.get("topic_label", "")),
        "subtopic_label": _normalize_subtopic_label(result.get("subtopic_label", "")),
        "section_type": str(result.get("section_type", "concept")).strip() or "concept",
        "topic_priority": str(result.get("topic_priority", "medium")).strip() or "medium",
    }


def _score_chunk_importance(chunk: Dict[str, Any]) -> float:
    score = 0.0
    text = chunk["chunk_text"].lower()

    priority_map = {"high": 3.0, "medium": 2.0, "low": 1.0}
    score += priority_map.get(chunk.get("topic_priority", "medium").lower(), 2.0)

    if chunk.get("section_type", "") in {
        "definition_features",
        "steps_definition",
        "symbols_steps",
        "types_comparison",
        "syntax_example",
        "definition_concepts",
    }:
        score += 2.0

    keywords = [
        "definition", "characteristics", "types", "steps", "algorithm",
        "flowchart", "formula", "example", "syntax", "function",
        "important", "advantages", "classification", "operator",
    ]
    score += sum(0.5 for k in keywords if k in text)

    if len(chunk["chunk_text"]) > 300:
        score += 0.5

    return round(score, 2)


def _dedupe_keep_order(items: List[str]) -> List[str]:
    seen = set()
    out = []
    for item in items:
        key = item.strip().lower()
        if key and key not in seen:
            seen.add(key)
            out.append(item.strip())
    return out


# ---------------------------------
# Structure processing
# ---------------------------------

def process_text_structure(text: str) -> Dict[str, Any]:
    cleaned = clean_text(text)

    if not cleaned:
        return {
            "extracted_text": "",
            "chunks": [],
            "topics": [],
        }

    raw_chunks = split_into_chunks(cleaned, max_chars=1200)

    structured_chunks = []
    for idx, chunk_text in enumerate(raw_chunks, start=1):
        topic_data = _predict_topic_structure(chunk_text)
        item = {
            "chunk_index": idx,
            "chunk_text": chunk_text,
            "topic_label": topic_data["topic_label"],
            "subtopic_label": topic_data["subtopic_label"],
            "section_type": topic_data["section_type"],
            "topic_priority": topic_data["topic_priority"],
        }
        item["importance_score"] = _score_chunk_importance(item)
        structured_chunks.append(item)

    grouped: Dict[str, Dict[str, Any]] = {}
    for item in structured_chunks:
        topic = item["topic_label"]
        if topic not in grouped:
            grouped[topic] = {
                "topic_label": topic,
                "subtopics": [],
                "chunk_indexes": [],
            }
        grouped[topic]["subtopics"].append(item["subtopic_label"])
        grouped[topic]["chunk_indexes"].append(item["chunk_index"])

    topics = []
    for v in grouped.values():
        topics.append({
            "topic_label": v["topic_label"],
            "subtopics": _dedupe_keep_order(v["subtopics"]),
            "chunk_indexes": v["chunk_indexes"],
        })

    topics.sort(key=lambda x: (len(x["chunk_indexes"]) * -1, x["topic_label"]))

    return {
        "extracted_text": cleaned,
        "chunks": structured_chunks,
        "topics": topics,
    }


# ---------------------------------
# Key points + flashcards
# ---------------------------------

def _fallback_keypoints_and_flashcards(chunk_text: str) -> Dict[str, Any]:
    sentences = split_sentences(chunk_text)
    points = sentences[:3] if sentences else [chunk_text[:140].strip()]

    flashcards = []
    for point in points[:3]:
        flashcards.append({
            "front": "What should you remember about this point?",
            "back": point,
        })

    return {
        "key_points": " | ".join(points[:3]),
        "flashcards": flashcards,
    }


def _generate_keypoints_for_chunk(chunk_text: str) -> Dict[str, Any]:
    prompt = (
        "Create study key points and flashcards from the note chunk.\n"
        "Return only JSON with keys: key_points, flashcards.\n"
        f"Text: {chunk_text}"
    )

    tokenizer, model = _get_keypoints_model()
    result = _generate_json(prompt, tokenizer, model, max_new_tokens=180)

    if not result:
        return _fallback_keypoints_and_flashcards(chunk_text)

    key_points = str(result.get("key_points", "")).strip()
    flashcards = result.get("flashcards", [])

    if not isinstance(flashcards, list):
        flashcards = []

    cleaned_cards = []
    for item in flashcards[:4]:
        if isinstance(item, dict):
            front = str(item.get("front", "")).strip()
            back = str(item.get("back", "")).strip()
            if front and back:
                cleaned_cards.append({"front": front, "back": back})

    if not key_points and not cleaned_cards:
        return _fallback_keypoints_and_flashcards(chunk_text)

    return {
        "key_points": key_points,
        "flashcards": cleaned_cards,
    }


def _importance_label_from_score(score: float) -> str:
    if score >= 7:
        return "HIGH"
    if score >= 4:
        return "MEDIUM"
    return "LOW"


def generate_keypoints_and_flashcards(text: str) -> Dict[str, Any]:
    structured = process_text_structure(text)
    chunks = structured["chunks"]

    if not chunks:
        return {"key_points": [], "flashcards": []}

    chunks_sorted = sorted(chunks, key=lambda x: x.get("importance_score", 0), reverse=True)

    key_points = []
    flashcards = []

    for chunk in chunks_sorted[:8]:
        generated = _generate_keypoints_for_chunk(chunk["chunk_text"])
        raw_key_points = str(generated.get("key_points", "")).strip()

        extracted_points = []
        if " | " in raw_key_points:
            extracted_points = [p.strip() for p in raw_key_points.split(" | ") if p.strip()]
        else:
            extracted_points = split_sentences(raw_key_points)[:3] if raw_key_points else []

        label = _importance_label_from_score(chunk["importance_score"])

        for point in extracted_points[:3]:
            key_points.append({
                "text": point,
                "importance": label,
                "score": float(chunk["importance_score"]),
                "topic_label": chunk["topic_label"],
                "subtopic_label": chunk["subtopic_label"],
            })

        for card in generated.get("flashcards", [])[:3]:
            flashcards.append(card)

    seen = set()
    deduped_points = []
    for item in key_points:
        k = item["text"].strip().lower()
        if k and k not in seen:
            seen.add(k)
            deduped_points.append(item)

    seen_cards = set()
    deduped_cards = []
    for card in flashcards:
        k = (card["front"].strip().lower(), card["back"].strip().lower())
        if k not in seen_cards:
            seen_cards.add(k)
            deduped_cards.append(card)

    return {
        "key_points": deduped_points[:20],
        "flashcards": deduped_cards[:20],
    }


# ---------------------------------
# Importance ranking
# ---------------------------------

def rank_topics_and_subtopics(text: str) -> Dict[str, Any]:
    structured = process_text_structure(text)
    chunks = structured["chunks"]

    if not chunks:
        return {
            "important_topics": [],
            "important_subtopics": [],
        }

    topic_scores: Dict[str, float] = {}
    subtopic_scores: Dict[Tuple[str, str], float] = {}

    for chunk in chunks:
        topic = chunk["topic_label"]
        subtopic = chunk["subtopic_label"]
        score = float(chunk.get("importance_score", 0))

        topic_scores[topic] = topic_scores.get(topic, 0.0) + score
        subtopic_scores[(topic, subtopic)] = subtopic_scores.get((topic, subtopic), 0.0) + score

    important_topics = [
        t for t, _ in sorted(topic_scores.items(), key=lambda x: x[1], reverse=True)
    ][:8]

    important_subtopics = [
        sub for (_, sub), _ in sorted(subtopic_scores.items(), key=lambda x: x[1], reverse=True)
    ][:12]

    return {
        "important_topics": important_topics,
        "important_subtopics": important_subtopics,
    }


# ---------------------------------
# Summarization
# ---------------------------------

def _fallback_summary(text: str) -> str:
    sents = split_sentences(text)
    if not sents:
        return text[:300].strip()
    return " ".join(sents[:4]).strip()


def _generate_summary(text: str) -> str:
    tokenizer, model = _get_sum_model()
    if tokenizer is None or model is None:
        return _fallback_summary(text)

    prompt = (
        "Write a short study summary for this topic or subtopic.\n"
        "Return only plain text.\n"
        f"Text: {text}"
    )

    full_prompt = (
        "<|system|>\n"
        "You are a helpful study-note processing assistant.\n"
        "<|user|>\n"
        f"{prompt}\n"
        "<|assistant|>\n"
    )

    inputs = tokenizer(
        full_prompt,
        return_tensors="pt",
        truncation=True,
        max_length=256,
    ).to(device)

    with torch.no_grad():
        output = model.generate(
            **inputs,
            max_new_tokens=120,
            do_sample=False,
            repetition_penalty=1.1,
            pad_token_id=tokenizer.pad_token_id,
            eos_token_id=tokenizer.eos_token_id,
        )

    text_out = tokenizer.decode(output[0], skip_special_tokens=True)
    text_out = text_out.split("<|assistant|>")[-1].strip()
    return text_out or _fallback_summary(text)


def summarize_selected_topic(
    extracted_text: str,
    chunks: List[Dict[str, Any]],
    topic_label: str,
    subtopic_label: Optional[str] = None,
) -> Dict[str, Any]:
    selected = []
    for chunk in chunks:
        if chunk.get("topic_label") != topic_label:
            continue
        if subtopic_label and chunk.get("subtopic_label") != subtopic_label:
            continue
        selected.append(chunk)

    if not selected:
        return {
            "topic_label": topic_label,
            "subtopic_label": subtopic_label,
            "summary": "No matching content found for the selected topic or subtopic.",
        }

    selected.sort(key=lambda x: x.get("chunk_index", 0))
    combined = "\n\n".join(c["chunk_text"] for c in selected)
    combined = combined[:3000]

    summary = _generate_summary(combined)

    return {
        "topic_label": topic_label,
        "subtopic_label": subtopic_label,
        "summary": summary,
    }


# ---------------------------------
# Quiz generation
# ---------------------------------

def _fallback_quiz_from_text(
    text: str,
    topic_label: str,
    subtopic_label: str,
    max_questions: int = 5,
) -> List[Dict[str, str]]:
    sentences = split_sentences(text)[:max_questions]
    questions = []

    for sent in sentences:
        answer = sent[:120].strip()
        questions.append({
            "question": f"Which statement is correct about {subtopic_label}?",
            "option_a": answer,
            "option_b": "It is not related to this topic.",
            "option_c": "It refers only to hardware repair.",
            "correct_option": "A",
            "explanation": answer,
            "topic_label": topic_label,
            "subtopic_label": subtopic_label,
        })

    return questions


def _generate_quiz_items(
    text: str,
    topic_label: str,
    subtopic_label: str,
    max_questions: int,
) -> List[Dict[str, str]]:
    tokenizer, model = _get_quiz_model()
    if tokenizer is None or model is None:
        return _fallback_quiz_from_text(text, topic_label, subtopic_label, max_questions)

    questions = []
    working_texts = split_sentences(text)[:max_questions]

    for sent in working_texts:
        prompt = (
            "Create one multiple choice question from the study note chunk.\n"
            "Return only JSON with keys: question, option_a, option_b, option_c, correct_option, explanation.\n"
            f"Text: {sent}"
        )

        result = _generate_json(prompt, tokenizer, model, max_new_tokens=140)
        if not result:
            continue

        q = {
            "question": str(result.get("question", "")).strip(),
            "option_a": str(result.get("option_a", "")).strip(),
            "option_b": str(result.get("option_b", "")).strip(),
            "option_c": str(result.get("option_c", "")).strip(),
            "correct_option": str(result.get("correct_option", "")).strip(),
            "explanation": str(result.get("explanation", "")).strip(),
            "topic_label": topic_label,
            "subtopic_label": subtopic_label,
        }

        if all([q["question"], q["option_a"], q["option_b"], q["option_c"], q["correct_option"]]):
            questions.append(q)

        if len(questions) >= max_questions:
            break

    if not questions:
        return _fallback_quiz_from_text(text, topic_label, subtopic_label, max_questions)

    cleaned = []
    for q in questions:
        correct = q["correct_option"].upper()
        if correct not in {"A", "B", "C"}:
            correct = "A"
        q["correct_option"] = correct
        cleaned.append(q)

    return cleaned[:max_questions]


def generate_quiz_for_topic(
    extracted_text: str,
    chunks: List[Dict[str, Any]],
    topic_label: str,
    subtopic_label: Optional[str] = None,
    max_questions: int = 5,
) -> Dict[str, Any]:
    selected = []
    for chunk in chunks:
        if chunk.get("topic_label") != topic_label:
            continue
        if subtopic_label and chunk.get("subtopic_label") != subtopic_label:
            continue
        selected.append(chunk)

    if not selected:
        return {
            "topic_label": topic_label,
            "subtopic_label": subtopic_label,
            "questions": [],
        }

    selected.sort(key=lambda x: x.get("importance_score", 0), reverse=True)
    combined = "\n\n".join(c["chunk_text"] for c in selected[:6])
    combined = combined[:2500]

    final_subtopic = subtopic_label or selected[0].get("subtopic_label", "General Subtopic")
    questions = _generate_quiz_items(combined, topic_label, final_subtopic, max_questions)

    return {
        "topic_label": topic_label,
        "subtopic_label": subtopic_label,
        "questions": questions,
    }


# ---------------------------------
# OCR / image
# ---------------------------------

def analyze_image_text(image_bytes: bytes) -> str:
    extracted_text = extract_text_from_image_bytes(image_bytes)
    return clean_text(extracted_text)