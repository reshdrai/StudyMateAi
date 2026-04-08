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
ADAPTER_DIR = PROJECT_ROOT / "models" / "quiz_generator"


def load_model():
    if not ADAPTER_DIR.exists():
        raise FileNotFoundError(f"Adapter directory not found: {ADAPTER_DIR}")

    tokenizer = AutoTokenizer.from_pretrained(ADAPTER_DIR, use_fast=True)
    base_model = AutoModelForCausalLM.from_pretrained(
        BASE_MODEL,
        low_cpu_mem_usage=True,
    )
    model = PeftModel.from_pretrained(base_model, ADAPTER_DIR)

    device = "cuda" if torch.cuda.is_available() else "cpu"
    model.to(device)
    model.eval()

    return tokenizer, model, device


def extract_json(text: str):
    match = re.search(r"\{.*\}", text, flags=re.DOTALL)
    if not match:
        return {
            "question": "",
            "option_a": "",
            "option_b": "",
            "option_c": "",
            "correct_option": "",
            "explanation": "",
            "raw_output": text.strip(),
        }

    try:
        return json.loads(match.group(0))
    except Exception:
        return {
            "question": "",
            "option_a": "",
            "option_b": "",
            "option_c": "",
            "correct_option": "",
            "explanation": "",
            "raw_output": text.strip(),
        }


def generate_quiz(text: str, tokenizer, model, device):
    prompt = (
        "<|system|>\n"
        "You are a helpful study-note processing assistant.\n"
        "<|user|>\n"
        "Create one multiple choice question from the study note chunk.\n"
        "Return only JSON with keys: question, option_a, option_b, option_c, correct_option, explanation.\n"
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
            max_new_tokens=140,
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
    A compiler converts a high-level language program into machine language.
    An interpreter executes the source code line by line.
    An assembler converts assembly language into machine code.
    """

    result = generate_quiz(sample_text, tokenizer, model, device)
    print(json.dumps(result, indent=2), flush=True)