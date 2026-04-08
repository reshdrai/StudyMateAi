import os
import inspect
from pathlib import Path

import pandas as pd
import torch
from datasets import Dataset
from transformers import (
    AutoTokenizer,
    AutoModelForSequenceClassification,
    DataCollatorWithPadding,
    TrainingArguments,
    Trainer,
)

MODEL_NAME = "distilbert-base-uncased"

PROJECT_ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = PROJECT_ROOT / "data" / "importance.csv"
SAVE_DIR = PROJECT_ROOT / "models" / "importance"
OUT_DIR = PROJECT_ROOT / "outputs" / "importance"

LABEL2ID = {"LOW": 0, "MEDIUM": 1, "HIGH": 2}
ID2LABEL = {0: "LOW", 1: "MEDIUM", 2: "HIGH"}


def clean_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    required_cols = ["topic_title", "subtopic", "content_text", "importance_target_label"]
    for col in required_cols:
        if col not in df.columns:
            raise ValueError(f"Missing required column: {col}")

    df = df.copy()

    for col in required_cols:
        df[col] = df[col].fillna("").astype(str).str.strip()

    df["importance_target_label"] = df["importance_target_label"].str.upper()
    df = df[df["importance_target_label"].isin(LABEL2ID.keys())]

    df = df[df["content_text"].str.len() > 10].reset_index(drop=True)
    return df


def build_input_text(row) -> str:
    topic = row["topic_title"]
    subtopic = row["subtopic"]
    content = row["content_text"]
    return f"topic: {topic} subtopic: {subtopic} content: {content}"


def make_training_args():
    common_args = dict(
        output_dir=str(OUT_DIR),
        per_device_train_batch_size=8,
        per_device_eval_batch_size=8,
        num_train_epochs=5,
        learning_rate=2e-5,
        weight_decay=0.01,
        logging_steps=10,
        save_strategy="epoch",
        fp16=torch.cuda.is_available(),
        report_to="none",
        save_total_limit=2,
        dataloader_pin_memory=torch.cuda.is_available(),
    )

    sig = inspect.signature(TrainingArguments.__init__)

    if "eval_strategy" in sig.parameters:
        common_args["eval_strategy"] = "epoch"
    elif "evaluation_strategy" in sig.parameters:
        common_args["evaluation_strategy"] = "epoch"

    return TrainingArguments(**common_args)


def main():
    print("Loading importance dataset...")
    print("CSV:", CSV_PATH)

    if not CSV_PATH.exists():
        raise FileNotFoundError(f"CSV not found: {CSV_PATH}")

    SAVE_DIR.mkdir(parents=True, exist_ok=True)
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    df = pd.read_csv(CSV_PATH)
    print("Original rows:", len(df))

    df = clean_dataframe(df)
    print("Usable rows:", len(df))

    if len(df) < 20:
        raise ValueError("Too few usable rows for training.")

    df["label"] = df["importance_target_label"].map(LABEL2ID)

    dataset = Dataset.from_pandas(df)
    dataset = dataset.train_test_split(test_size=0.1, seed=42)

    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)

    model = AutoModelForSequenceClassification.from_pretrained(
        MODEL_NAME,
        num_labels=3,
        id2label=ID2LABEL,
        label2id=LABEL2ID
    )

    def preprocess(batch):
        texts = []
        for topic, subtopic, content in zip(
            batch["topic_title"],
            batch["subtopic"],
            batch["content_text"]
        ):
            texts.append(f"topic: {topic} subtopic: {subtopic} content: {content}")

        encodings = tokenizer(
            texts,
            truncation=True,
            padding=False,
            max_length=256
        )
        encodings["labels"] = batch["label"]
        return encodings

    train_ds = dataset["train"].map(
        preprocess,
        batched=True,
        remove_columns=dataset["train"].column_names
    )

    eval_ds = dataset["test"].map(
        preprocess,
        batched=True,
        remove_columns=dataset["test"].column_names
    )

    data_collator = DataCollatorWithPadding(tokenizer=tokenizer)
    args = make_training_args()

    trainer_kwargs = dict(
        model=model,
        args=args,
        train_dataset=train_ds,
        eval_dataset=eval_ds,
        data_collator=data_collator,
    )

    trainer_sig = inspect.signature(Trainer.__init__)
    if "processing_class" in trainer_sig.parameters:
        trainer_kwargs["processing_class"] = tokenizer
    elif "tokenizer" in trainer_sig.parameters:
        trainer_kwargs["tokenizer"] = tokenizer

    trainer = Trainer(**trainer_kwargs)

    print("Starting importance training...")
    trainer.train()

    print("Saving importance model...")
    trainer.save_model(SAVE_DIR)
    tokenizer.save_pretrained(SAVE_DIR)

    print("Importance model saved to:", SAVE_DIR)


if __name__ == "__main__":
    os.makedirs("models", exist_ok=True)
    main()