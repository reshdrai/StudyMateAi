import os
import pandas as pd
import torch
from datasets import Dataset
from transformers import (
    AutoTokenizer,
    AutoModelForSeq2SeqLM,
    TrainingArguments,
    Trainer
)
from peft import LoraConfig, get_peft_model, TaskType

MODEL_NAME = "google/flan-t5-small"
CSV_PATH = "data/qg.csv"


def main():

    print("Loading dataset...")

    df = pd.read_csv(CSV_PATH).dropna()

    dataset = Dataset.from_pandas(df)

    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)

    model = AutoModelForSeq2SeqLM.from_pretrained(MODEL_NAME)

    # LoRA adapter (small memory)
    lora = LoraConfig(
        task_type=TaskType.SEQ_2_SEQ_LM,
        r=8,
        lora_alpha=16,
        lora_dropout=0.1,
        target_modules=["q", "v"]
    )

    model = get_peft_model(model, lora)

    def preprocess(batch):

        prompts = [
            f"generate question: context: {c} answer: {a}"
            for c, a in zip(batch["context"], batch["answer"])
        ]

        model_inputs = tokenizer(
            prompts,
            padding="max_length",
            truncation=True,
            max_length=256
        )

        labels = tokenizer(
            batch["question"],
            padding="max_length",
            truncation=True,
            max_length=64
        )

        # ignore padding tokens
        label_ids = labels["input_ids"]
        label_ids = [
            [(tok if tok != tokenizer.pad_token_id else -100) for tok in seq]
            for seq in label_ids
        ]

        model_inputs["labels"] = label_ids

        return model_inputs

    dataset = dataset.train_test_split(test_size=0.1, seed=42)

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

    args = TrainingArguments(
        output_dir="outputs/qg",
        per_device_train_batch_size=2,
        num_train_epochs=5,
        fp16=torch.cuda.is_available(),
        logging_steps=10,
        report_to="none",
        save_strategy="epoch",
    )

    trainer = Trainer(
        model=model,
        args=args,
        train_dataset=train_ds,
        eval_dataset=eval_ds,
    )

    print("Starting training...")

    trainer.train()

    print("Saving model...")

    trainer.save_model("models/qg")
    tokenizer.save_pretrained("models/qg")

    print("Question generation model saved!")


if __name__ == "__main__":
    os.makedirs("models", exist_ok=True)
    main()