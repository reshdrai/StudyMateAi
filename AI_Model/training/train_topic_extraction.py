import os

# MOVE ALL CACHE + TEMP TO D DRIVE
os.environ["HF_HOME"] = "D:/hf_cache"
os.environ["TRANSFORMERS_CACHE"] = "D:/hf_cache/transformers"
os.environ["HF_DATASETS_CACHE"] = "D:/hf_cache/datasets"
os.environ["TORCH_HOME"] = "D:/hf_cache/torch"
os.environ["TMPDIR"] = "D:/hf_cache/tmp"
os.environ["TEMP"] = "D:/hf_cache/tmp"
os.environ["TMP"] = "D:/hf_cache/tmp"

import json
import sys
from pathlib import Path

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
CSV_PATH = PROJECT_ROOT / "data" / "topic_subtopic_extraction_1000.csv"
SAVE_DIR = PROJECT_ROOT / "models" / "topic_extractor"
OUT_DIR = PROJECT_ROOT / "outputs" / "topic_extractor"


def clean_dataframe(df):
    required_cols = [
        "chunk_text",
        "topic_label",
        "subtopic_label",
        "section_type",
        "topic_priority",
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
        (df["topic_label"].str.len() > 1) &
        (df["subtopic_label"].str.len() > 1) &
        (df["section_type"].str.len() > 1) &
        (df["topic_priority"].str.len() > 1)
    ].reset_index(drop=True)

    return df


def build_prompt(row) -> str:
    chunk_text = str(row["chunk_text"]).strip()
    subject = str(row.get("subject", "")).strip()
    chapter_title = str(row.get("chapter_title", "")).strip()
    section_heading = str(row.get("section_heading", "")).strip()

    return (
        "Extract topic structure from the study note chunk.\n"
        "Return only JSON with keys: topic_label, subtopic_label, section_type, topic_priority.\n"
        f"Subject: {subject}\n"
        f"Chapter: {chapter_title}\n"
        f"Heading: {section_heading}\n"
        f"Text: {chunk_text}"
    )


def build_target(row) -> str:
    data = {
        "topic_label": str(row["topic_label"]).strip(),
        "subtopic_label": str(row["subtopic_label"]).strip(),
        "section_type": str(row["section_type"]).strip(),
        "topic_priority": str(row["topic_priority"]).strip(),
    }
    return json.dumps(data, ensure_ascii=False)


def main():
    print("Running from:", os.getcwd())
    print("CSV path:", CSV_PATH)
    print("Model save path:", SAVE_DIR)

    df = load_csv_dataframe(CSV_PATH, required_cols=["chunk_text", "topic_label", "subtopic_label"])
    print("Original rows:", len(df))

    df = clean_dataframe(df)
    print("Usable rows:", len(df))

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

    print("\nTraining complete.")
    print("Adapter saved to:", SAVE_DIR)


if __name__ == "__main__":
    main()