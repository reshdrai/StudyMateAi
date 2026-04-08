import re
from pathlib import Path

import torch
from transformers import AutoTokenizer, AutoModelForSeq2SeqLM
from peft import PeftModel

BASE_MODEL = "google/flan-t5-small"

# safer path: based on project root, not current working directory
PROJECT_ROOT = Path(__file__).resolve().parents[1]
ADAPTER_DIR = PROJECT_ROOT / "models" / "summarizer"


def load_model():
    print("Step 1: checking adapter path...", flush=True)
    print("Adapter path:", ADAPTER_DIR, flush=True)

    if not ADAPTER_DIR.exists():
        raise FileNotFoundError(f"Adapter directory not found: {ADAPTER_DIR}")

    print("Step 2: loading tokenizer...", flush=True)
    tokenizer = AutoTokenizer.from_pretrained(ADAPTER_DIR)

    print("Step 3: loading base model...", flush=True)
    base_model = AutoModelForSeq2SeqLM.from_pretrained(BASE_MODEL)

    # avoid tied-weights warning
    base_model.config.tie_word_embeddings = False

    print("Step 4: loading LoRA adapter...", flush=True)
    model = PeftModel.from_pretrained(base_model, ADAPTER_DIR)

    device = "cuda" if torch.cuda.is_available() else "cpu"
    print("Step 5: moving model to device:", device, flush=True)
    model.to(device)
    model.eval()

    print("Model loaded successfully.", flush=True)
    return tokenizer, model, device


def clean_text(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r'(?m)^\s*\d+\s*$', '', text)
    text = re.sub(r'[ \t]+', ' ', text)
    text = re.sub(r'(?<![.!?:])\n(?!\n)', ' ', text)
    text = re.sub(r'\n{2,}', '\n\n', text)
    return text.strip()


def split_into_chunks(text: str, max_chars: int = 1600):
    paragraphs = [p.strip() for p in text.split("\n\n") if p.strip()]
    chunks = []
    current = ""

    for p in paragraphs:
        if len(current) + len(p) + 2 <= max_chars:
            current = f"{current}\n\n{p}".strip()
        else:
            if current:
                chunks.append(current)
            current = p

    if current:
        chunks.append(current)

    return chunks


def summarize_chunk(text: str, tokenizer, model, device) -> str:
    prompt = f"summary: {text}"

    print("Generating summary for chunk...", flush=True)

    inputs = tokenizer(
        prompt,
        return_tensors="pt",
        truncation=True,
        max_length=320
    ).to(device)

    with torch.no_grad():
        out = model.generate(
            **inputs,
            max_new_tokens=90,
            num_beams=6,
            repetition_penalty=1.5,
            no_repeat_ngram_size=4,
            length_penalty=0.9,
            early_stopping=True,
        )

    result = tokenizer.decode(out[0], skip_special_tokens=True).strip()
    return result


def summarize_big_text(text: str, tokenizer, model, device) -> str:
    cleaned = clean_text(text)
    chunks = split_into_chunks(cleaned, max_chars=1600)

    print("Total chunks:", len(chunks), flush=True)

    if not chunks:
        return "No summary could be generated."

    chunk_summaries = []
    for i, chunk in enumerate(chunks[:8], start=1):
        print(f"Summarizing chunk {i}...", flush=True)
        s = summarize_chunk(chunk, tokenizer, model, device)
        if s:
            chunk_summaries.append(s)

    if not chunk_summaries:
        return "No summary could be generated."

    if len(chunk_summaries) == 1:
        return chunk_summaries[0]

    combined = " ".join(chunk_summaries)
    final_prompt = f"summary: {combined}"

    print("Generating final combined summary...", flush=True)

    inputs = tokenizer(
        final_prompt,
        return_tensors="pt",
        truncation=True,
        max_length=320
    ).to(device)

    with torch.no_grad():
        out = model.generate(
            **inputs,
            max_new_tokens=120,
            min_new_tokens=35,
            num_beams=4,
            length_penalty=1.1,
            repetition_penalty=1.2,
            no_repeat_ngram_size=3,
            early_stopping=True,
        )

    result = tokenizer.decode(out[0], skip_special_tokens=True).strip()
    return result


if __name__ == "__main__":
    print("Script started.", flush=True)

    tokenizer, model, device = load_model()

    text = """
    Overview: Operating Systems

    Operating systems manage hardware and software resources. They provide process
    management, memory management, file handling, and device control. Beginners often
    confuse multitasking with multiprocessing. Operating systems also involve tradeoffs
    between speed, memory use, and stability.

    One lecture example compared how scheduling decisions affect performance.
    """

    print("\nGenerated Summary:\n", flush=True)
    result = summarize_big_text(text, tokenizer, model, device)
    print(result, flush=True)

    print("\nScript finished.", flush=True)