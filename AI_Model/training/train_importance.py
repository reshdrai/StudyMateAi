import pandas as pd
import torch
from torch.utils.data import DataLoader
from datasets import Dataset
from transformers import AutoTokenizer, AutoModelForSequenceClassification
from pathlib import Path

print("RUNNING NEW IMPORTANCE TRAINING SCRIPT")

MODEL_NAME = "distilbert-base-uncased"

PROJECT_ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = PROJECT_ROOT / "data" / "importance.csv"
MODEL_DIR = PROJECT_ROOT / "models" / "importance"


def main():

    df = pd.read_csv(CSV_PATH).dropna()
    df["label"] = df["label"].astype(int)

    dataset = Dataset.from_pandas(df)

    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)

    def preprocess(batch):
        return tokenizer(
            batch["sentence"],
            padding="max_length",
            truncation=True,
            max_length=128
        )

    dataset = dataset.map(preprocess, batched=True)

    dataset.set_format(
        type="torch",
        columns=["input_ids", "attention_mask", "label"]
    )

    split = dataset.train_test_split(test_size=0.1, seed=42)

    train_loader = DataLoader(split["train"], batch_size=8, shuffle=True)

    model = AutoModelForSequenceClassification.from_pretrained(
        MODEL_NAME,
        num_labels=2
    )

    device = "cuda" if torch.cuda.is_available() else "cpu"
    model.to(device)

    optimizer = torch.optim.AdamW(model.parameters(), lr=2e-5)

    epochs = 5

    for epoch in range(epochs):

        model.train()
        total_loss = 0

        for batch in train_loader:

            optimizer.zero_grad()

            input_ids = batch["input_ids"].to(device)
            attention_mask = batch["attention_mask"].to(device)
            labels = batch["label"].to(device)

            outputs = model(
                input_ids=input_ids,
                attention_mask=attention_mask,
                labels=labels
            )

            loss = outputs.loss
            loss.backward()
            optimizer.step()

            total_loss += loss.item()

        print(f"Epoch {epoch+1} Loss:", total_loss / len(train_loader))

    MODEL_DIR.mkdir(parents=True, exist_ok=True)

    model.save_pretrained(MODEL_DIR)
    tokenizer.save_pretrained(MODEL_DIR)

    print("Model saved to:", MODEL_DIR)


if __name__ == "__main__":
    main()