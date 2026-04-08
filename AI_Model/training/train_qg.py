import os
import inspect
from pathlib import Path

import pandas as pd
import torch
from datasets import Dataset
from transformers import (
    AutoTokenizer,
    AutoModelForSeq2SeqLM,
    DataCollatorForSeq2Seq,
    Seq2SeqTrainer,
    Seq2SeqTrainingArguments,
)
from peft import LoraConfig, get_peft_model, TaskType

MODEL_NAME = "google/flan-t5-small"

PROJECT_ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = PROJECT_ROOT / "data" / "qg.csv"
SAVE_DIR = PROJECT_ROOT / "models" / "qg"
OUT_DIR = PROJECT_ROOT / "outputs" / "qg"


def clean_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    required_cols = [
        "topic_title",
        "context_text",
        "question_text",
        "answer_text",
        "importance_label",
    ]
    for col in required_cols:
        if col not in df.columns:
            raise ValueError(f"Missing required column: {col}")

    df = df.copy()

    for col in required_cols:
        df[col] = df[col].fillna("").astype(str).str.strip()

    df = df[
        (df["context_text"].str.len() > 30) &
        (df["question_text"].str.len() > 5) &
        (df["answer_text"].str.len() > 1)
    ].reset_index(drop=True)

    if "quality_label" in df.columns:
        df["quality_label"] = df["quality_label"].fillna("").astype(str).str.strip().str.lower()
        good_df = df[df["quality_label"].isin(["good", "very_good", "excellent", "reviewed"])]
        if len(good_df) > 0:
            df = good_df.reset_index(drop=True)

    return df


def make_training_args():
    common_args = dict(
        output_dir=str(OUT_DIR),
        per_device_train_batch_size=1,
        per_device_eval_batch_size=1,
        gradient_accumulation_steps=4,
        num_train_epochs=6,
        learning_rate=2e-4,
        logging_steps=10,
        save_strategy="epoch",
        predict_with_generate=False,
        fp16=torch.cuda.is_available(),
        report_to="none",
        save_total_limit=2,
        load_best_model_at_end=False,
        dataloader_pin_memory=torch.cuda.is_available(),
        remove_unused_columns=True,
    )

    sig = inspect.signature(Seq2SeqTrainingArguments.__init__)
    if "eval_strategy" in sig.parameters:
        common_args["eval_strategy"] = "epoch"
    elif "evaluation_strategy" in sig.parameters:
        common_args["evaluation_strategy"] = "epoch"

    return Seq2SeqTrainingArguments(**common_args)


def main():
    print("Loading quiz dataset...")
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

    dataset = Dataset.from_pandas(df)
    dataset = dataset.train_test_split(test_size=0.1, seed=42)

    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
    base_model = AutoModelForSeq2SeqLM.from_pretrained(MODEL_NAME)
    base_model.config.tie_word_embeddings = False

    lora = LoraConfig(
        task_type=TaskType.SEQ_2_SEQ_LM,
        inference_mode=False,
        r=8,
        lora_alpha=16,
        lora_dropout=0.1,
        target_modules=["q", "v"]
    )

    model = get_peft_model(base_model, lora)
    model.print_trainable_parameters()

    def preprocess(batch):
        prompts = []
        for topic, context, answer, importance in zip(
            batch["topic_title"],
            batch["context_text"],
            batch["answer_text"],
            batch["importance_label"]
        ):
            prompt = (
                f"generate question: "
                f"topic: {topic} "
                f"importance: {importance} "
                f"context: {context} "
                f"answer: {answer}"
            )
            prompts.append(prompt)

        model_inputs = tokenizer(
            prompts,
            padding=False,
            truncation=True,
            max_length=320
        )

        labels = tokenizer(
            text_target=batch["question_text"],
            padding=False,
            truncation=True,
            max_length=64
        )

        model_inputs["labels"] = labels["input_ids"]
        return model_inputs

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

    data_collator = DataCollatorForSeq2Seq(
        tokenizer=tokenizer,
        model=model,
        padding=True
    )

    args = make_training_args()

    trainer_kwargs = dict(
        model=model,
        args=args,
        train_dataset=train_ds,
        eval_dataset=eval_ds,
        data_collator=data_collator,
    )

    trainer_sig = inspect.signature(Seq2SeqTrainer.__init__)
    if "processing_class" in trainer_sig.parameters:
        trainer_kwargs["processing_class"] = tokenizer
    elif "tokenizer" in trainer_sig.parameters:
        trainer_kwargs["tokenizer"] = tokenizer

    trainer = Seq2SeqTrainer(**trainer_kwargs)

    print("Starting quiz generation training...")
    trainer.train()

    print("Saving quiz generation model...")
    model.save_pretrained(SAVE_DIR)
    tokenizer.save_pretrained(SAVE_DIR)

    print("Quiz generation model saved to:", SAVE_DIR)


if __name__ == "__main__":
    os.makedirs("models", exist_ok=True)
    main()