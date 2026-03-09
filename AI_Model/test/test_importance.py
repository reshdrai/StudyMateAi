import torch
from transformers import AutoTokenizer, AutoModelForSequenceClassification

MODEL_PATH = "models/importance"

tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH)
model = AutoModelForSequenceClassification.from_pretrained(MODEL_PATH)

device = "cuda" if torch.cuda.is_available() else "cpu"
model.to(device).eval()

sentences = [
    "inline elements ignore width and height.",
    "I will practice tomorrow.",
    "block elements take full width."
]

inputs = tokenizer(sentences, return_tensors="pt", padding=True).to(device)

with torch.no_grad():
    outputs = model(**inputs)

preds = outputs.logits.argmax(dim=1)

for s, p in zip(sentences, preds):
    print(s, "->", "Important" if p.item() == 1 else "Not Important")