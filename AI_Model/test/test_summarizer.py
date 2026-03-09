import torch
from pathlib import Path
from transformers import AutoTokenizer, AutoModelForSeq2SeqLM
from peft import PeftModel

BASE_MODEL = "google/flan-t5-small"
ADAPTER_DIR = Path("models/summarizer")

tokenizer = AutoTokenizer.from_pretrained(ADAPTER_DIR)
base_model = AutoModelForSeq2SeqLM.from_pretrained(BASE_MODEL)
model = PeftModel.from_pretrained(base_model, ADAPTER_DIR)

device = "cuda" if torch.cuda.is_available() else "cpu"
model.to(device).eval()

text = """Today we studied CSS display properties. inline ignores width/height.
inline-block allows width/height while staying inline. block takes full width."""
prompt = f"""
Summarize the following notes.

Return output in this format:

Summary: <one sentence>
Key Points:
- <point>
- <point>
- <point>

Notes:
{text}
"""

inputs = tokenizer(prompt, return_tensors="pt", truncation=True).to(device)

with torch.no_grad():
    out = model.generate(
        **inputs,
        max_new_tokens=150,
        num_beams=4,
        early_stopping=True
    )

result = tokenizer.decode(out[0], skip_special_tokens=True)
print("\nGenerated Output:\n")
print(result)