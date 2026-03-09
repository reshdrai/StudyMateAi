import torch
from pathlib import Path
from transformers import AutoTokenizer, AutoModelForSeq2SeqLM
from peft import PeftModel

BASE_MODEL = "google/flan-t5-small"
ADAPTER_DIR = Path("models/qg")

# load tokenizer
tokenizer = AutoTokenizer.from_pretrained(ADAPTER_DIR)

# load base model
base_model = AutoModelForSeq2SeqLM.from_pretrained(BASE_MODEL)

# load LoRA adapter
model = PeftModel.from_pretrained(base_model, ADAPTER_DIR)

device = "cuda" if torch.cuda.is_available() else "cpu"
model.to(device).eval()

# test example
context = "inline elements ignore width and height."
answer = "inline"

prompt = f"generate question: context: {context} answer: {answer}"

inputs = tokenizer(prompt, return_tensors="pt").to(device)

with torch.no_grad():
    outputs = model.generate(
        **inputs,
        max_new_tokens=64,
        num_beams=4,
        early_stopping=True
    )

question = tokenizer.decode(outputs[0], skip_special_tokens=True)

print("\nGenerated Question:\n")
print(question)