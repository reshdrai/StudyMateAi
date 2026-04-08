import torch
from transformers import AutoTokenizer, AutoModelForSequenceClassification

MODEL_PATH = "models/importance"

tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH)
model = AutoModelForSequenceClassification.from_pretrained(MODEL_PATH)

device = "cuda" if torch.cuda.is_available() else "cpu"
model.to(device).eval()


def predict_importance(topic, subtopic, content):
    text = f"topic: {topic} subtopic: {subtopic} content: {content}"

    inputs = tokenizer(
        text,
        return_tensors="pt",
        padding=True,
        truncation=True,
        max_length=256
    ).to(device)

    with torch.no_grad():
        outputs = model(**inputs)

    pred_id = outputs.logits.argmax(dim=1).item()
    label = model.config.id2label[pred_id]
    return label


samples = [
    {
        "topic": "Characteristics of Computers",
        "subtopic": "Speed",
        "content": "Speed is a major characteristic of computers and is often asked in exams."
    },
    {
        "topic": "Characteristics of Computers",
        "subtopic": "Reliability",
        "content": "Reliability helps computers produce dependable results over repeated tasks."
    },
    {
        "topic": "Applications of Computers",
        "subtopic": "Music",
        "content": "Computers can also be used in music production and editing."
    }
]

for s in samples:
    pred = predict_importance(s["topic"], s["subtopic"], s["content"])
    print(f"{s['topic']} | {s['subtopic']} -> {pred}")