import os
import pandas as pd
import torch
from datasets import Dataset
from transformers import (
    AutoTokenizer, AutoModelForSeq2SeqLM,
    DataCollatorForSeq2Seq, TrainingArguments, Trainer
)
from peft import LoraConfig, get_peft_model, TaskType
from pathlib import Path

MODEL_NAME = "google/flan-t5-small"

PROJECT_ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = PROJECT_ROOT / "data" / "summarization.csv"
SAVE_DIR = PROJECT_ROOT / "models" / "summarizer"
OUT_DIR  = PROJECT_ROOT / "outputs" / "summarizer"


def main():
    print("✅ Running from:", os.getcwd())
    print("✅ CSV:", CSV_PATH)
    print("✅ Will save to:", SAVE_DIR)

    df = pd.read_csv(CSV_PATH)

    required_cols = {"text", "summary", "key_points"}
    if not required_cols.issubset(df.columns):
        raise ValueError(
            f"CSV must contain columns: {required_cols}. Found: {list(df.columns)}"
        )

    df = df.dropna(subset=["text", "summary", "key_points"]).reset_index(drop=True)

    if len(df) < 2:
        raise ValueError(
            f"Need at least 2 rows. Found {len(df)}. Add more data to summarization.csv"
        )

    dataset = Dataset.from_pandas(df)

    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
    model = AutoModelForSeq2SeqLM.from_pretrained(MODEL_NAME)

    lora = LoraConfig(
        task_type=TaskType.SEQ_2_SEQ_LM,
        r=8,
        lora_alpha=16,
        lora_dropout=0.1,
        target_modules=["q", "k", "v", "o"]
    )
    model = get_peft_model(model, lora)

    def preprocess(batch):
        inputs = ["summarize: " + str(t) for t in batch["text"]]

        # Combine summary + key points into ONE target output
        targets = []
        for s, kp in zip(batch["summary"], batch["key_points"]):
            s = str(s).strip()
            kp = str(kp).strip()
            target = f"Summary: {s}\nKey Points:\n{kp}"
            targets.append(target)

        model_inputs = tokenizer(inputs, truncation=True, max_length=512)

        # Tokenize targets (compatible with old/new transformers)
        try:
            labels = tokenizer(text_target=targets, truncation=True, max_length=256)
            model_inputs["labels"] = labels["input_ids"]
        except TypeError:
            labels = tokenizer(targets, truncation=True, max_length=256)
            model_inputs["labels"] = labels["input_ids"]

        return model_inputs

    n = len(dataset)
    test_size = max(1, int(0.1 * n))
    split = dataset.train_test_split(test_size=test_size, seed=42)

    train_ds = split["train"].map(preprocess, batched=True, remove_columns=split["train"].column_names)
    eval_ds  = split["test"].map(preprocess, batched=True, remove_columns=split["test"].column_names)

    data_collator = DataCollatorForSeq2Seq(tokenizer=tokenizer, model=model)

    args = TrainingArguments(
        output_dir=str(OUT_DIR),
        per_device_train_batch_size=2,
        per_device_eval_batch_size=2,
        num_train_epochs=3,
        learning_rate=2e-4,
        fp16=torch.cuda.is_available(),
        logging_steps=10,
        report_to="none",
        save_strategy="no",
        remove_unused_columns=False
    )

    trainer = Trainer(
        model=model,
        args=args,
        train_dataset=train_ds,
        eval_dataset=eval_ds,
        data_collator=data_collator,
    )

    trainer.train()

    SAVE_DIR.mkdir(parents=True, exist_ok=True)
    print("💾 Saving adapter + tokenizer to:", SAVE_DIR)
    model.save_pretrained(str(SAVE_DIR))
    tokenizer.save_pretrained(str(SAVE_DIR))

    print("✅ Saved successfully to:", SAVE_DIR)


if __name__ == "__main__":
    main()