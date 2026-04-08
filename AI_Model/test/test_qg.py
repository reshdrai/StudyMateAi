from pathlib import Path

import torch
from transformers import AutoTokenizer, AutoModelForSeq2SeqLM
from peft import PeftModel

BASE_MODEL = "google/flan-t5-small"
MODEL_PATH = Path("models/qg")


def load_model():
    if not MODEL_PATH.exists():
        raise FileNotFoundError(f"Model path not found: {MODEL_PATH}")

    tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH)
    base_model = AutoModelForSeq2SeqLM.from_pretrained(BASE_MODEL)
    base_model.config.tie_word_embeddings = False
    model = PeftModel.from_pretrained(base_model, MODEL_PATH)

    device = "cuda" if torch.cuda.is_available() else "cpu"
    model.to(device).eval()
    return tokenizer, model, device


def generate_question(topic, context, answer, importance, tokenizer, model, device):
    prompt = (
        f"generate question: "
        f"topic: {topic} "
        f"importance: {importance} "
        f"context: {context} "
        f"answer: {answer}"
    )

    inputs = tokenizer(
        prompt,
        return_tensors="pt",
        truncation=True,
        max_length=320
    ).to(device)

    with torch.no_grad():
        output = model.generate(
            **inputs,
            max_new_tokens=64,
            min_new_tokens=8,
            num_beams=4,
            repetition_penalty=1.2,
            no_repeat_ngram_size=3,
            early_stopping=True,
        )

    return tokenizer.decode(output[0], skip_special_tokens=True).strip()


if __name__ == "__main__":
    tokenizer, model, device = load_model()

    topic = "Operating Systems"
    context = (
        "Operating systems manage hardware and software resources. "
        "They handle process management, memory management, file handling, and device control. "
        "Students often confuse multitasking with multiprocessing."
    )
    answer = "process management"
    importance = "HIGH"

    question = generate_question(topic, context, answer, importance, tokenizer, model, device)

    print("\nGenerated Question:\n")
    print(question)