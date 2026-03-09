from pathlib import Path
import torch
from transformers import AutoTokenizer, AutoModelForSeq2SeqLM
from peft import PeftModel

BASE_MODEL = "google/flan-t5-base"

# ✅ always correct, no matter where you run uvicorn from
PROJECT_ROOT = Path(__file__).resolve().parents[1]   # inference/ -> project root
ADAPTER_DIR = PROJECT_ROOT / "models" / "summarizer"

tokenizer = AutoTokenizer.from_pretrained(str(ADAPTER_DIR))
base_model = AutoModelForSeq2SeqLM.from_pretrained(BASE_MODEL)
model = PeftModel.from_pretrained(base_model, str(ADAPTER_DIR))
model.eval()

def summarize(text: str) -> str:
    inputs = tokenizer("summarize: " + text, return_tensors="pt", truncation=True, max_length=512)
    with torch.no_grad():
        out = model.generate(**inputs, max_length=160, min_length=40, num_beams=4)
    return tokenizer.decode(out[0], skip_special_tokens=True)