"""
StudyMate AI Pipeline — Fast heuristic-based extraction.
No model loading. Instant results. Quality output.
Set STUDYMATE_USE_MODELS=true to enable LoRA models (slow).

UPDATED: Quiz generation now produces 3-4 questions per topic by default.
"""

import os
import re
import random as _random
from typing import List, Dict, Any, Optional, Tuple
from collections import OrderedDict

USE_MODELS = os.environ.get("STUDYMATE_USE_MODELS", "false").lower() == "true"

try:
    from backend.ocr import extract_text_from_image_bytes
    OCR_AVAILABLE = True
except ImportError:
    OCR_AVAILABLE = False

print(f"[Pipeline] Mode: {'MODEL' if USE_MODELS else 'HEURISTIC (fast)'}", flush=True)


# ═══════════════════════════════════════════════════════
# TEXT CLEANING
# ═══════════════════════════════════════════════════════

def clean_text(text: str) -> str:
    text = (text or "").replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"(?m)^\s*\d{1,3}\s*$", "", text)
    lines = text.split("\n")
    result_lines = []
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if not line:
            result_lines.append("")
            i += 1
            continue
        if _looks_like_heading(line):
            result_lines.append("")
            result_lines.append(line)
            result_lines.append("")
            i += 1
            continue
        combined = line
        while i + 1 < len(lines):
            next_line = lines[i + 1].strip()
            if not next_line:
                break
            if _looks_like_heading(next_line):
                break
            if combined and not combined.endswith((".", "!", "?", ":", ";", '"', "'")):
                combined += " " + next_line
                i += 1
            elif combined and combined[-1] in (".", "!", "?") and next_line[0].isupper():
                combined += " " + next_line
                i += 1
            else:
                combined += " " + next_line
                i += 1
        result_lines.append(combined)
        i += 1
    text = "\n".join(result_lines)
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def _looks_like_heading(line: str) -> bool:
    s = line.strip()
    if not s or len(s) > 80:
        return False
    if s.endswith((".", ",", ";", "!", "?")):
        return False
    if not s[0].isupper():
        return False
    words = s.split()
    if len(words) == 1 and len(s) > 3:
        return True
    if 2 <= len(words) <= 6:
        cap_count = sum(1 for w in words if w[0].isupper() or w.lower() in ("and", "or", "of", "in", "the", "for", "to", "a"))
        if cap_count >= len(words) * 0.6:
            return True
    if s.startswith("#"):
        return True
    if re.match(r"^(?:Chapter|Section|Topic|Unit|Part)\s", s, re.I):
        return True
    return False


# ═══════════════════════════════════════════════════════
# SECTION DETECTION
# ═══════════════════════════════════════════════════════

def _detect_sections(text: str) -> List[Dict[str, str]]:
    paragraphs = [p.strip() for p in text.split("\n\n") if p.strip()]
    sections = []
    current_heading = None
    current_body_parts = []
    for para in paragraphs:
        if _looks_like_heading(para):
            if current_heading is not None and current_body_parts:
                sections.append({"heading": current_heading, "body": " ".join(current_body_parts)})
            elif current_heading is None and current_body_parts:
                sections.append({"heading": "Overview", "body": " ".join(current_body_parts)})
            current_heading = para.strip().rstrip(":.")
            current_body_parts = []
        else:
            current_body_parts.append(para)
    if current_heading and current_body_parts:
        sections.append({"heading": current_heading, "body": " ".join(current_body_parts)})
    elif current_body_parts:
        sections.append({"heading": "General Topic", "body": " ".join(current_body_parts)})
    if not sections:
        sections = [{"heading": "General Topic", "body": text}]
    return sections


# ═══════════════════════════════════════════════════════
# SENTENCE OPERATIONS
# ═══════════════════════════════════════════════════════

def split_sentences(text: str) -> List[str]:
    if not text:
        return []
    sents = re.split(r'(?<=[.!?])\s+(?=[A-Z])', text.strip())
    return [s.strip() for s in sents if s.strip() and len(s.strip()) > 15]


def _score_sentence(s: str) -> float:
    t = s.lower()
    score = 0.0
    if any(p in t for p in ["is defined as", "refers to", "is a form of", "is a branch of", "often called"]):
        score += 5.0
    if re.match(r"^[A-Z].{5,30}\s+is\s+", s):
        score += 3.0
    if any(p in t for p in ["key principle", "important", "essential", "crucial", "major", "fundamental"]):
        score += 3.0
    if any(p in t for p in ["include ", "includes ", "such as", "for example"]):
        score += 2.5
    if any(p in t for p in ["advantage", "disadvantage", "limitation", "challenge", "however", "unlike"]):
        score += 2.0
    if any(p in t for p in ["used in", "can help", "allows", "enables", "supports", "aim to"]):
        score += 1.5
    if 40 < len(s) < 250:
        score += 1.0
    elif len(s) < 25:
        score -= 1.0
    if any(p in t for p in ["in this chapter", "let us", "we will discuss", "this document"]):
        score -= 1.5
    return score


def _extract_key_sentences(text: str, n: int = 5) -> List[str]:
    sents = split_sentences(text)
    if not sents:
        return [text[:300].strip()] if text else []
    scored = [(s, _score_sentence(s)) for s in sents]
    scored.sort(key=lambda x: x[1], reverse=True)
    top_set = {s for s, _ in scored[:n]}
    return [s for s in sents if s in top_set][:n]


# ═══════════════════════════════════════════════════════
# PRIORITY / TYPE CLASSIFICATION
# ═══════════════════════════════════════════════════════

def _classify_priority(heading: str, body: str) -> str:
    t = (heading + " " + body).lower()
    hi = ["definition", "principle", "algorithm", "formula", "types", "classification",
          "key ", "important", "advantage", "disadvantage", "characteristic"]
    if any(k in t for k in hi):
        return "high"
    lo = ["conclusion", "summary", "reference", "appendix"]
    if any(k in t for k in lo):
        return "low"
    return "medium"


def _classify_type(heading: str, body: str) -> str:
    c = (heading + " " + body).lower()
    if any(k in c for k in ["defined as", "refers to", "is a form of"]): return "definition"
    if any(k in c for k in ["type", "classification", "categor"]): return "classification"
    if any(k in c for k in ["step", "algorithm", "process", "procedure"]): return "steps"
    if any(k in c for k in ["advantage", "disadvantage", "limitation", "challenge"]): return "comparison"
    if any(k in c for k in ["introduction", "overview"]): return "introduction"
    if any(k in c for k in ["conclusion", "summary"]): return "conclusion"
    return "concept"


def _score_chunk(chunk: Dict[str, Any]) -> float:
    score = {"high": 3, "medium": 2, "low": 1}.get(chunk.get("topic_priority", "medium"), 2)
    score += {"definition": 3, "classification": 2.5, "steps": 2.5, "comparison": 2,
              "concept": 1.5, "introduction": 1, "conclusion": 0.5}.get(chunk.get("section_type", ""), 1)
    t = chunk["chunk_text"].lower()
    for k in ["definition", "important", "types", "advantage", "key", "process", "principle", "include"]:
        if k in t:
            score += 0.5
    if len(chunk["chunk_text"]) > 200:
        score += 0.5
    return round(score, 2)


# ═══════════════════════════════════════════════════════
# MAIN: process_text_structure
# ═══════════════════════════════════════════════════════

def process_text_structure(text: str) -> Dict[str, Any]:
    cleaned = clean_text(text)
    if not cleaned:
        return {"extracted_text": "", "chunks": [], "topics": []}
    sections = _detect_sections(cleaned)
    print(f"[Pipeline] Detected {len(sections)} sections: {[s['heading'] for s in sections]}", flush=True)
    structured_chunks = []
    idx = 1
    for sec in sections:
        h, b = sec["heading"], sec["body"]
        if not b.strip():
            continue
        item = {
            "chunk_index": idx,
            "chunk_text": b,
            "topic_label": h,
            "subtopic_label": h,
            "section_type": _classify_type(h, b),
            "topic_priority": _classify_priority(h, b),
        }
        item["importance_score"] = _score_chunk(item)
        structured_chunks.append(item)
        idx += 1
    grouped = OrderedDict()
    for item in structured_chunks:
        t = item["topic_label"]
        if t not in grouped:
            grouped[t] = {"topic_label": t, "subtopics": [], "chunk_indexes": []}
        if item["subtopic_label"] not in grouped[t]["subtopics"]:
            grouped[t]["subtopics"].append(item["subtopic_label"])
        grouped[t]["chunk_indexes"].append(item["chunk_index"])
    topics = list(grouped.values())
    topics.sort(key=lambda x: (-len(x["chunk_indexes"]), x["topic_label"]))
    return {"extracted_text": cleaned, "chunks": structured_chunks, "topics": topics}


# ═══════════════════════════════════════════════════════
# KEY POINTS + FLASHCARDS
# ═══════════════════════════════════════════════════════

def _make_question(sent: str, topic: str) -> str:
    s = sent.lower()
    if any(p in s for p in ["is defined as", "refers to", "is a form of", "is a branch of"]):
        m = re.match(r"^(.+?)\s+(?:is defined as|refers to|is a form of|is a branch of)\b", sent, re.I)
        if m:
            return f"What is {m.group(1).strip()}?"
    if "include" in s:
        return f"What does {topic} include?"
    if "advantage" in s or "benefit" in s:
        return f"What are the advantages of {topic}?"
    if "limitation" in s or "challenge" in s or "disadvantage" in s:
        return f"What are the challenges of {topic}?"
    if "aim to" in s or "promote" in s:
        return f"What is the goal of {topic}?"
    if any(p in s for p in ["can ", "help", "support", "allow", "enable"]):
        return f"How does {topic} help?"
    if "key principle" in s or "essential" in s:
        return f"What are the key principles of {topic}?"
    return f"What is important about {topic}?"


def generate_keypoints_and_flashcards(text: str) -> Dict[str, Any]:
    structured = process_text_structure(text)
    chunks = sorted(structured["chunks"], key=lambda x: x.get("importance_score", 0), reverse=True)
    if not chunks:
        return {"key_points": [], "flashcards": []}
    kps, fcs = [], []
    seen_kp, seen_fc = set(), set()
    for chunk in chunks:
        topic = chunk["topic_label"]
        imp = chunk.get("importance_score", 0)
        label = "HIGH" if imp >= 5.5 else "MEDIUM" if imp >= 3.5 else "LOW"
        sents = split_sentences(chunk["chunk_text"])
        scored = sorted([(s, _score_sentence(s)) for s in sents], key=lambda x: -x[1])
        for sent, sc in scored:
            if sc < 0:
                continue
            k = sent.lower().strip()
            if k in seen_kp or len(sent) < 20:
                continue
            seen_kp.add(k)
            kps.append({
                "text": sent,
                "importance": label,
                "score": float(imp),
                "topic_label": topic,
                "subtopic_label": chunk["subtopic_label"],
            })
            q = _make_question(sent, topic)
            qk = q.lower()
            if qk not in seen_fc:
                seen_fc.add(qk)
                fcs.append({"front": q, "back": sent})
    return {"key_points": kps[:25], "flashcards": fcs[:20]}


# ═══════════════════════════════════════════════════════
# IMPORTANCE RANKING
# ═══════════════════════════════════════════════════════

def rank_topics_and_subtopics(text: str) -> Dict[str, Any]:
    structured = process_text_structure(text)
    chunks = structured["chunks"]
    if not chunks:
        return {"important_topics": [], "important_subtopics": []}
    ts: Dict[str, float] = {}
    ss: Dict[str, float] = {}
    for c in chunks:
        t, s, sc = c["topic_label"], c["subtopic_label"], c.get("importance_score", 0)
        ts[t] = ts.get(t, 0) + sc
        ss[s] = ss.get(s, 0) + sc
    return {
        "important_topics": [t for t, _ in sorted(ts.items(), key=lambda x: -x[1])][:10],
        "important_subtopics": [s for s, _ in sorted(ss.items(), key=lambda x: -x[1])][:15],
    }


# ═══════════════════════════════════════════════════════
# SUMMARIZATION
# ═══════════════════════════════════════════════════════

def summarize_selected_topic(extracted_text, chunks, topic_label, subtopic_label=None):
    sel = [c for c in chunks if c.get("topic_label") == topic_label
           and (not subtopic_label or c.get("subtopic_label") == subtopic_label)]
    if not sel:
        return {"topic_label": topic_label, "subtopic_label": subtopic_label, "summary": "No content found."}
    combined = " ".join(c["chunk_text"] for c in sorted(sel, key=lambda x: x.get("chunk_index", 0)))
    sents = _extract_key_sentences(combined, 6)
    return {"topic_label": topic_label, "subtopic_label": subtopic_label, "summary": " ".join(sents)}


# ═══════════════════════════════════════════════════════
# QUIZ GENERATION — UPDATED: 3-4 questions per topic
# ═══════════════════════════════════════════════════════

def generate_quiz_for_topic(extracted_text, chunks, topic_label, subtopic_label=None, max_questions=5):
    """Generate quiz questions. If topic_label is 'ALL', generate from all topics.
    
    UPDATED: Now generates 3-4 questions per topic by using multiple question
    templates and extracting more sentences from each chunk.
    """

    if topic_label.upper() == "ALL":
        selected = chunks
    else:
        selected = [c for c in chunks if c.get("topic_label") == topic_label]
        if subtopic_label:
            sub = [c for c in selected if c.get("subtopic_label") == subtopic_label]
            if sub:
                selected = sub

    if not selected:
        selected = chunks[:8]

    if not selected:
        return {"topic_label": topic_label, "subtopic_label": subtopic_label, "questions": []}

    # Collect all sentences across the document for wrong answers
    all_sents = split_sentences(" ".join(c["chunk_text"] for c in chunks))

    # More diverse question templates
    templates = [
        "Which of the following is true about {topic}?",
        "According to the notes, what is correct about {topic}?",
        "What is an important point about {topic}?",
        "Which statement best describes {topic}?",
        "Regarding {topic}, which is accurate?",
        "What can be concluded about {topic}?",
        "Which of these is a key aspect of {topic}?",
        "What is a fundamental concept of {topic}?",
    ]

    questions = []
    used_sents = set()  # Track used sentences to avoid duplicates

    # For each selected chunk, try to generate MULTIPLE questions (up to 2 per chunk)
    for chunk in sorted(selected, key=lambda x: x.get("importance_score", 0), reverse=True):
        if len(questions) >= max_questions:
            break

        topic = chunk["topic_label"]
        sub = chunk.get("subtopic_label", topic)
        sents = split_sentences(chunk["chunk_text"])
        key = sorted([(s, _score_sentence(s)) for s in sents], key=lambda x: -x[1])

        questions_from_chunk = 0
        for sent, sc in key:
            if len(questions) >= max_questions:
                break
            if questions_from_chunk >= 2:  # Max 2 questions per chunk
                break
            if len(sent) < 30 or sc < 0:
                continue
            if sent.lower().strip() in used_sents:
                continue

            correct = sent.strip()
            if len(correct) > 160:
                correct = correct[:157] + "..."

            used_sents.add(sent.lower().strip())

            q_text = templates[len(questions) % len(templates)].format(topic=sub)

            # Wrong answers from OTHER topics/chunks
            others = [s.strip() for s in all_sents
                      if s.strip().lower() != correct.lower()
                      and s.strip().lower() not in used_sents
                      and len(s.strip()) > 25]
            _random.shuffle(others)
            wrong_b = others[0][:160] if others else f"This is unrelated to {sub}."
            wrong_c = others[1][:160] if len(others) > 1 else f"This describes a different concept."

            # Randomize option positions
            options = [
                ("A", correct),
                ("B", wrong_b),
                ("C", wrong_c),
            ]
            _random.shuffle(options)

            # Find which letter has the correct answer
            correct_letter = "A"
            for letter, text in options:
                if text == correct:
                    correct_letter = letter
                    break

            questions.append({
                "question": q_text,
                "option_a": options[0][1],
                "option_b": options[1][1],
                "option_c": options[2][1],
                "correct_option": correct_letter,
                "explanation": f"This is from the {topic} section of the notes.",
                "topic_label": topic,
                "subtopic_label": sub,
            })
            questions_from_chunk += 1

    # If we have fewer than 3 questions for a single topic, try harder
    if topic_label.upper() != "ALL" and len(questions) < 3 and selected:
        # Try to get more questions from remaining sentences
        for chunk in selected:
            if len(questions) >= max_questions:
                break
            sents = split_sentences(chunk["chunk_text"])
            for sent in sents:
                if len(questions) >= max_questions:
                    break
                if len(sent) < 25:
                    continue
                if sent.lower().strip() in used_sents:
                    continue

                used_sents.add(sent.lower().strip())
                correct = sent.strip()[:160]
                sub = chunk.get("subtopic_label", topic_label)
                q_text = templates[len(questions) % len(templates)].format(topic=sub)

                others = [s.strip() for s in all_sents
                          if s.strip().lower() != correct.lower() and len(s.strip()) > 20]
                _random.shuffle(others)

                questions.append({
                    "question": q_text,
                    "option_a": correct,
                    "option_b": others[0][:160] if others else f"Not related to {sub}.",
                    "option_c": others[1][:160] if len(others) > 1 else "A different concept entirely.",
                    "correct_option": "A",
                    "explanation": f"From the {chunk['topic_label']} section.",
                    "topic_label": chunk["topic_label"],
                    "subtopic_label": sub,
                })

    return {"topic_label": topic_label, "subtopic_label": subtopic_label, "questions": questions}


# ═══════════════════════════════════════════════════════
# OCR
# ═══════════════════════════════════════════════════════

def analyze_image_text(image_bytes: bytes) -> str:
    if OCR_AVAILABLE:
        return clean_text(extract_text_from_image_bytes(image_bytes))
    return "[OCR not available]"