import os
import inspect
from pathlib import Path
from typing import Callable

import pandas as pd
import torch
from datasets import Dataset
from transformers import (
    AutoTokenizer,
    AutoModelForCausalLM,
    DataCollatorForLanguageModeling,
    Trainer,
    TrainingArguments,
)

from peft import LoraConfig, get_peft_model


def load_csv_dataframe(csv_path: Path, required_cols=None) -> pd.DataFrame:
    if not csv_path.exists():
        raise FileNotFoundError(f"CSV not found at: {csv_path}")

    df = pd.read_csv(csv_path)

    if required_cols:
        for col in required_cols:
            if col not in df.columns:
                raise ValueError(f"Missing required column: {col}")

    return df


def build_sft_text(prompt: str, target: str) -> str:
    prompt = str(prompt).strip()
    target = str(target).strip()

    return (
        "<|system|>\n"
        "You are a helpful study-note processing assistant.\n"
        "<|user|>\n"
        f"{prompt}\n"
        "<|assistant|>\n"
        f"{target}"
    )


def make_training_args(output_dir: Path):
    common_args = dict(
        output_dir=str(output_dir),
        per_device_train_batch_size=1,
        per_device_eval_batch_size=1,
        gradient_accumulation_steps=4,
        num_train_epochs=3,
        learning_rate=2e-4,
        logging_steps=10,
        save_steps=100,
        eval_steps=100,
        save_strategy="steps",
        eval_strategy="steps",
        save_total_limit=2,
        fp16=torch.cuda.is_available(),
        bf16=False,
        report_to="none",
        remove_unused_columns=True,
        dataloader_pin_memory=torch.cuda.is_available(),
        load_best_model_at_end=False,
    )

    sig = inspect.signature(TrainingArguments.__init__)
    if "evaluation_strategy" in sig.parameters:
        common_args["evaluation_strategy"] = common_args.pop("eval_strategy")

    return TrainingArguments(**common_args)


def train_sft_from_dataframe(
    df: pd.DataFrame,
    prompt_builder: Callable,
    target_builder: Callable,
    save_dir: Path,
    output_dir: Path,
    model_name: str,
):
    output_dir.mkdir(parents=True, exist_ok=True)
    save_dir.mkdir(parents=True, exist_ok=True)

    dataset = Dataset.from_pandas(df.reset_index(drop=True))

    print("Loading tokenizer:", model_name, flush=True)
    tokenizer = AutoTokenizer.from_pretrained(model_name, use_fast=True)

    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token

    print("Loading base model:", model_name, flush=True)
    model = AutoModelForCausalLM.from_pretrained(
        model_name,
        low_cpu_mem_usage=True,
    )

    model.config.use_cache = False

    peft_config = LoraConfig(
        r=4,
        lora_alpha=8,
        lora_dropout=0.1,
        bias="none",
        task_type="CAUSAL_LM",
        target_modules=[
            "q_proj",
            "v_proj",
            "k_proj",
            "o_proj",
        ],
    )

    print("Applying LoRA...", flush=True)
    model = get_peft_model(model, peft_config)
    model.print_trainable_parameters()

    max_length = 256

    def preprocess(example):
        prompt = prompt_builder(example)
        target = target_builder(example)
        full_text = build_sft_text(prompt, target)

        tokenized = tokenizer(
            full_text,
            truncation=True,
            max_length=max_length,
            padding=False,
        )

        tokenized["labels"] = tokenized["input_ids"].copy()
        return tokenized

    print("Tokenizing dataset...", flush=True)
    tokenized_dataset = dataset.map(
        preprocess,
        remove_columns=dataset.column_names,
    )

    split_dataset = tokenized_dataset.train_test_split(test_size=0.1, seed=42)
    train_dataset = split_dataset["train"]
    eval_dataset = split_dataset["test"]

    data_collator = DataCollatorForLanguageModeling(
        tokenizer=tokenizer,
        mlm=False,
    )

    training_args = make_training_args(output_dir)

    trainer_kwargs = dict(
        model=model,
        args=training_args,
        train_dataset=train_dataset,
        eval_dataset=eval_dataset,
        data_collator=data_collator,
    )

    trainer_sig = inspect.signature(Trainer.__init__)
    if "tokenizer" in trainer_sig.parameters:
        trainer_kwargs["tokenizer"] = tokenizer
    elif "processing_class" in trainer_sig.parameters:
        trainer_kwargs["processing_class"] = tokenizer

    trainer = Trainer(**trainer_kwargs)

    print("Starting training...", flush=True)
    trainer.train()

    print("Saving adapter + tokenizer...", flush=True)
    model.save_pretrained(save_dir)
    tokenizer.save_pretrained(save_dir)