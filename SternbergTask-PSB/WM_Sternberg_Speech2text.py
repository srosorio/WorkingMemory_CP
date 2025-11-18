import whisper
import json
import re
import numpy as np
from pathlib import Path

# --------------------------
# --- Configuration ---
# --------------------------
participant_id = "S01"

audio_folder = Path(
    f"C:/Users/saosorio/Projects/WorkingMemory_CP/SternbergTask-PSB/output/test/{participant_id}/OFFmed_OFFstim/AudioFiles"
)

block = "all"  # optional filter by block number

# --------------------------
# --- Load Whisper model ---
# --------------------------
model = whisper.load_model("base")

digit_map = {
    "zero": 0, "0": 0,
    "one": 1, "1": 1,
    "two": 2, "2": 2, "tool": 2, "too": 2, "june": 2, "do": 2, "doo": 2,
    "three": 3, "3": 3, "free": 3,
    "four": 4, "4": 4,
    "five": 5, "5": 5,
    "six": 6, "6": 6,
    "seven": 7, "7": 7,
    "eight": 8, "8": 8,
    "nine": 9, "9": 9
}

true_words = {"true", "yes", "correct", "1", "troll", "straw", "tron", "truly"}
false_words = {"false", "no", "incorrect", "0", "faults", "falls", "falt", "all", "fold", "pulse"}

# --------------------------
# --- Collect WAV files ---
# --------------------------
all_wavs = sorted([f for f in audio_folder.glob("*.wav")
                   if f.name.startswith(participant_id)])

# Optional: filter by block
if block != "all":
    block_num = int(block)
    pattern = f"Block{block_num:02d}"
    wavs_to_process = [f for f in all_wavs if pattern in f.name]
else:
    wavs_to_process = all_wavs

print(f"Found {len(wavs_to_process)} audio files")

# --------------------------
# --- Transcribe files ---
# --------------------------
raw_transcriptions = {}
clean_transcriptions = {}

for wav in wavs_to_process:
    print(f"Processing {wav.name}...")

    # --- Transcribe ---
    result = model.transcribe(
        str(wav),
        language="en",
        task="transcribe",
        prompt="Expected words: digits zero to nine and the words true and false only."
    )

    raw_text = result["text"].strip()
    raw_transcriptions[wav.name] = raw_text

    # --- Robust cleaning: handle repetitions ---
    words = re.findall(r"\w+", raw_text.lower())
    clean_vals = []

    for w in words:
        if w in digit_map:
            clean_vals.append(digit_map[w])
        elif w in true_words:
            clean_vals.append(True)
        elif w in false_words:
            clean_vals.append(False)

    # --- Remove duplicates while preserving order ---
    seen = []
    for val in clean_vals:
        if val not in seen:
            seen.append(val)

    # Store final clean value
    if len(seen) == 0:
        clean_val = np.nan
    elif len(seen) == 1:
        clean_val = seen[0]
    else:
        clean_val = seen  # list if multiple different values spoken

    clean_transcriptions[wav.name] = clean_val

    print(f"  raw: {raw_text} -> clean: {clean_val}")

# --------------------------
# --- Save outputs ---
# --------------------------
raw_file = audio_folder / "transcriptions_raw.json"
clean_file = audio_folder / "transcriptions_clean.json"

raw_file.write_text(json.dumps(raw_transcriptions, indent=2, ensure_ascii=False), encoding="utf-8")
clean_file.write_text(json.dumps(clean_transcriptions, indent=2, ensure_ascii=False), encoding="utf-8")

print("\n✅ Finished. Saved:")
print(f"  - {raw_file}")
print(f"  - {clean_file}")
