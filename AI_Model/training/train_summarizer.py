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
CSV_PATH = PROJECT_ROOT / "data" / "summarizer_training.csv"
SAVE_DIR = PROJECT_ROOT / "models" / "summarizer"
OUT_DIR = PROJECT_ROOT / "outputs" / "summarizer"


def clean_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    required_cols = ["chunk_text", "target_summary"]
    for col in required_cols:
        if col not in df.columns:
            raise ValueError(f"Missing required column: {col}")

    df = df.copy()

    df["chunk_text"] = df["chunk_text"].fillna("").astype(str).str.strip()
    df["target_summary"] = df["target_summary"].fillna("").astype(str).str.strip()

    # remove empty / very small rows
    df = df[
        (df["chunk_text"].str.len() > 40) &
        (df["target_summary"].str.len() > 15)
    ].reset_index(drop=True)

    # optional quality filter
    if "quality_label" in df.columns:
        df["quality_label"] = (
            df["quality_label"]
            .fillna("")
            .astype(str)
            .str.strip()
            .str.lower()
        )

        good_df = df[df["quality_label"].isin(["good", "very_good", "excellent", "reviewed"])]
        if len(good_df) > 0:
            df = good_df.reset_index(drop=True)

    return df


def build_prompt(row) -> str:
    chunk_text = str(row["chunk_text"]).strip()
    return f"summary: {chunk_text}"


def make_training_args():
    """
    Build Seq2SeqTrainingArguments safely across transformers versions.
    Some versions use eval_strategy, older ones use evaluation_strategy.
    """
    common_args = dict(
        output_dir=str(OUT_DIR),
        per_device_train_batch_size=1,
        per_device_eval_batch_size=1,
        gradient_accumulation_steps=4,
        num_train_epochs=8,
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
    print("Running from:", os.getcwd())
    print("CSV path:", CSV_PATH)
    print("Model save path:", SAVE_DIR)

    if not CSV_PATH.exists():
        raise FileNotFoundError(
            f"CSV not found at: {CSV_PATH}\n"
            f"Put summarizer_dataset_200_rows.csv inside the data folder."
        )

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    SAVE_DIR.mkdir(parents=True, exist_ok=True)

    df = pd.read_csv(CSV_PATH)
    print("Original rows:", len(df))

    df = clean_dataframe(df)
    print("Usable rows:", len(df))

    if len(df) < 20:
        raise ValueError("Too few usable rows. Add more training data before training.")

    dataset = Dataset.from_pandas(df)

    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
    base_model = AutoModelForSeq2SeqLM.from_pretrained(MODEL_NAME)

    # avoids tied-weight warning
    base_model.config.tie_word_embeddings = False

    peft_config = LoraConfig(
        task_type=TaskType.SEQ_2_SEQ_LM,
        inference_mode=False,
        r=8,
        lora_alpha=16,
        lora_dropout=0.1,
        target_modules=["q", "v"],
    )

    model = get_peft_model(base_model, peft_config)
    model.print_trainable_parameters()

    def preprocess(example):
        prompt = build_prompt(example)

        model_inputs = tokenizer(
            prompt,
            max_length=320,
            truncation=True,
            padding=False,
        )

        labels = tokenizer(
            text_target=str(example["target_summary"]),
            max_length=80,
            truncation=True,
            padding=False,
        )

        label_ids = labels["input_ids"]
        model_inputs["labels"] = label_ids
        return model_inputs

    tokenized_dataset = dataset.map(
        preprocess,
        remove_columns=dataset.column_names
    )

    split_dataset = tokenized_dataset.train_test_split(test_size=0.1, seed=42)
    train_dataset = split_dataset["train"]
    eval_dataset = split_dataset["test"]

    data_collator = DataCollatorForSeq2Seq(
        tokenizer=tokenizer,
        model=model,
        padding=True,
    )

    training_args = make_training_args()

    trainer_kwargs = dict(
        model=model,
        args=training_args,
        train_dataset=train_dataset,
        eval_dataset=eval_dataset,
        data_collator=data_collator,
    )

    trainer_sig = inspect.signature(Seq2SeqTrainer.__init__)
    if "processing_class" in trainer_sig.parameters:
        trainer_kwargs["processing_class"] = tokenizer
    elif "tokenizer" in trainer_sig.parameters:
        trainer_kwargs["tokenizer"] = tokenizer

    trainer = Seq2SeqTrainer(**trainer_kwargs)

    trainer.train()

    model.save_pretrained(SAVE_DIR)
    tokenizer.save_pretrained(SAVE_DIR)

    print("\nTraining complete.")
    print("Adapter saved to:", SAVE_DIR)


if __name__ == "__main__":
    main()