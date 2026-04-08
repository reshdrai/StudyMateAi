import os
import re
import json
from pathlib import Path

import torch
from transformers import AutoTokenizer, AutoModelForCausalLM
from peft import PeftModel

# move cache to D drive
os.environ["HF_HOME"] = "D:/hf_cache"
os.environ["TRANSFORMERS_CACHE"] = "D:/hf_cache/transformers"
os.environ["HF_DATASETS_CACHE"] = "D:/hf_cache/datasets"
os.environ["TORCH_HOME"] = "D:/hf_cache/torch"
os.environ["TMPDIR"] = "D:/hf_cache/tmp"
os.environ["TEMP"] = "D:/hf_cache/tmp"
os.environ["TMP"] = "D:/hf_cache/tmp"

for p in [
    Path("D:/hf_cache"),
    Path("D:/hf_cache/transformers"),
    Path("D:/hf_cache/datasets"),
    Path("D:/hf_cache/torch"),
    Path("D:/hf_cache/tmp"),
]:
    p.mkdir(parents=True, exist_ok=True)

BASE_MODEL = "HuggingFaceTB/SmolLM2-360M-Instruct"

PROJECT_ROOT = Path(__file__).resolve().parents[1]
ADAPTER_DIR = PROJECT_ROOT / "models" / "topic_extractor"


def load_model():
    print("Checking adapter path...", flush=True)
    print("Adapter path:", ADAPTER_DIR, flush=True)

    if not ADAPTER_DIR.exists():
        raise FileNotFoundError(f"Adapter directory not found: {ADAPTER_DIR}")

    print("Loading tokenizer...", flush=True)
    tokenizer = AutoTokenizer.from_pretrained(ADAPTER_DIR, use_fast=True)

    print("Loading base model...", flush=True)
    base_model = AutoModelForCausalLM.from_pretrained(
        BASE_MODEL,
        low_cpu_mem_usage=True,
    )

    print("Loading LoRA adapter...", flush=True)
    model = PeftModel.from_pretrained(base_model, ADAPTER_DIR)

    device = "cuda" if torch.cuda.is_available() else "cpu"
    print("Moving model to device:", device, flush=True)
    model.to(device)
    model.eval()

    return tokenizer, model, device


def extract_json(text: str):
    match = re.search(r"\{.*\}", text, flags=re.DOTALL)
    if not match:
        return {
            "topic_label": "",
            "subtopic_label": "",
            "section_type": "",
            "topic_priority": "",
            "raw_output": text.strip(),
        }

    try:
        data = json.loads(match.group(0))
        return data
    except Exception:
        return {
            "topic_label": "",
            "subtopic_label": "",
            "section_type": "",
            "topic_priority": "",
            "raw_output": text.strip(),
        }


def predict_topic_structure(text: str, tokenizer, model, device,
                            subject: str = "", chapter: str = "", heading: str = ""):
    prompt = (
        "<|system|>\n"
        "You are a helpful study-note processing assistant.\n"
        "<|user|>\n"
        "Extract topic structure from the study note chunk.\n"
        "Return only JSON with keys: topic_label, subtopic_label, section_type, topic_priority.\n"
        f"Subject: {subject}\n"
        f"Chapter: {chapter}\n"
        f"Heading: {heading}\n"
        f"Text: {text}\n"
        "<|assistant|>\n"
    )

    inputs = tokenizer(
        prompt,
        return_tensors="pt",
        truncation=True,
        max_length=256,
    ).to(device)

    with torch.no_grad():
        out = model.generate(
            **inputs,
            max_new_tokens=80,
            do_sample=False,
            repetition_penalty=1.1,
            pad_token_id=tokenizer.pad_token_id,
            eos_token_id=tokenizer.eos_token_id,
        )

    result = tokenizer.decode(out[0], skip_special_tokens=True)
    result = result.split("<|assistant|>")[-1].strip()
    return extract_json(result)


if __name__ == "__main__":
    tokenizer, model, device = load_model()

    sample_text = """
    The control unit instructs the computer how to carry out program instructions.
    It directs the flow of data between memory and arithmetic logical unit.
    It fetches instructions from memory, decodes them, and sets up execution.
    """

    result = predict_topic_structure(
        text=sample_text,
        tokenizer=tokenizer,
        model=model,
        device=device,
        subject="Computer Science",
        chapter="Basic Computer Organization",
        heading="Control Unit"
    )

    print("\nPrediction:\n", json.dumps(result, indent=2), flush=True) 