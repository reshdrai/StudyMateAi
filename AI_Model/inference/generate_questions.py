from transformers import AutoTokenizer, AutoModelForSeq2SeqLM

MODEL_DIR = "models/qg"
tokenizer = AutoTokenizer.from_pretrained(MODEL_DIR)
model = AutoModelForSeq2SeqLM.from_pretrained(MODEL_DIR)

def generate_question(context, answer):
    prompt = f"generate question: context: {context} answer: {answer}"
    inputs = tokenizer(prompt, return_tensors="pt", truncation=True)
    outputs = model.generate(**inputs, max_new_tokens=64)
    return tokenizer.decode(outputs[0], skip_special_tokens=True)