import os
import json
import sys
from pathlib import Path

# move cache to D drive
os.environ["HF_HOME"] = "D:/hf_cache"
os.environ["TRANSFORMERS_CACHE"] = "D:/hf_cache/transformers"
os.environ["HF_DATASETS_CACHE"] = "D:/hf_cache/datasets"
os.environ["TORCH_HOME"] = "D:/hf_cache/torch"
os.environ["TMPDIR"] = "D:/hf_cache/tmp"
os.environ["TEMP"] = "D:/hf_cache/tmp"
os.environ["TMP"] = "D:/hf_cache/tmp"

for p in [
    Path("D:/hf_cache"),
    Path("D:/hf_cache/transformers"),
    Path("D:/hf_cache/datasets"),
    Path("D:/hf_cache/torch"),
    Path("D:/hf_cache/tmp"),
]:
    p.mkdir(parents=True, exist_ok=True)

sys.path.append(str(Path(__file__).resolve().parents[1]))

from shared.qwen_lora_utils import load_csv_dataframe, train_sft_from_dataframe

MODEL_NAME = "HuggingFaceTB/SmolLM2-360M-Instruct"

PROJECT_ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = PROJECT_ROOT / "data" / "quiz_generation_1000.csv"
SAVE_DIR = PROJECT_ROOT / "models" / "quiz_generator"
OUT_DIR = PROJECT_ROOT / "outputs" / "quiz_generator"


def clean_dataframe(df):
    required_cols = [
        "chunk_text",
        "question",
        "option_a",
        "option_b",
        "option_c",
        "correct_option",
        "explanation",
    ]
    for col in required_cols:
        if col not in df.columns:
            raise ValueError(f"Missing required column: {col}")

    df = df.copy()

    for col in required_cols:
        df[col] = df[col].fillna("").astype(str).str.strip()

    if "quality_label" in df.columns:
        df["quality_label"] = df["quality_label"].fillna("").astype(str).str.strip().str.lower()
        good_df = df[df["quality_label"].isin(["good", "very_good", "excellent", "reviewed"])]
        if len(good_df) > 0:
            df = good_df.reset_index(drop=True)

    df = df[
        (df["chunk_text"].str.len() > 25) &
        (df["question"].str.len() > 8) &
        (df["option_a"].str.len() > 0) &
        (df["option_b"].str.len() > 0) &
        (df["option_c"].str.len() > 0) &
        (df["correct_option"].str.len() > 0) &
        (df["explanation"].str.len() > 5)
    ].reset_index(drop=True)

    return df


def build_prompt(row) -> str:
    return (
        "Create one multiple choice question from the study note chunk.\n"
        "Return only JSON with keys: question, option_a, option_b, option_c, correct_option, explanation.\n"
        f"Text: {str(row['chunk_text']).strip()}"
    )


def build_target(row) -> str:
    data = {
        "question": str(row["question"]).strip(),
        "option_a": str(row["option_a"]).strip(),
        "option_b": str(row["option_b"]).strip(),
        "option_c": str(row["option_c"]).strip(),
        "correct_option": str(row["correct_option"]).strip(),
        "explanation": str(row["explanation"]).strip(),
    }
    return json.dumps(data, ensure_ascii=False)


def main():
    print("Running from:", os.getcwd(), flush=True)
    print("CSV path:", CSV_PATH, flush=True)
    print("Model save path:", SAVE_DIR, flush=True)

    df = load_csv_dataframe(
        CSV_PATH,
        required_cols=[
            "chunk_text",
            "question",
            "option_a",
            "option_b",
            "option_c",
            "correct_option",
            "explanation",
        ],
    )

    print("Original rows:", len(df), flush=True)
    df = clean_dataframe(df)
    print("Usable rows:", len(df), flush=True)

    if len(df) < 50:
        raise ValueError("Too few usable rows after cleaning. Need at least 50.")

    train_sft_from_dataframe(
        df=df,
        prompt_builder=build_prompt,
        target_builder=build_target,
        save_dir=SAVE_DIR,
        output_dir=OUT_DIR,
        model_name=MODEL_NAME,
    )

    print("\nTraining complete.", flush=True)
    print("Adapter saved to:", SAVE_DIR, flush=True)


if __name__ == "__main__":
    main()