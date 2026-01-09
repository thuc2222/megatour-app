import os
import re
import json
from pathlib import Path

# =========================
# CONFIG
# =========================
PROJECT_PATH = "."
OUTPUT_ARB = "lib/l10n/app_en.arb"

# =========================
# RULES
# =========================
BLACKLIST_SUBSTRINGS = [
    '${', 'widget.', '.toString', 'assets/', 'lib/', 'package:', 'http://', 'https://'
]

def is_valid_text(text: str) -> bool:
    t = text.strip()
    if len(t) < 2: return False
    if re.fullmatch(r'[\W\d_]+', t): return False
    for bad in BLACKLIST_SUBSTRINGS:
        if bad in t: return False
    if t.lower().endswith(('.png', '.jpg', '.jpeg', '.svg', '.json')): return False
    return True

# =========================
# EXTRACT
# =========================
def extract_text_widgets(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    patterns = [
        r'Text\s*\(\s*r?([\'"])(.*?)\1', 
        r'\b(?:text|label|labelText|hintText|errorText|helperText|title|subtitle|message|tooltip)\s*:\s*r?([\'"])(.*?)\1',
    ]

    results = []
    for pattern in patterns:
        matches = re.findall(pattern, content, re.DOTALL)
        for quote_type, text_content in matches:
            clean_text = text_content.replace(f"\\{quote_type}", quote_type)
            if is_valid_text(clean_text):
                results.append(clean_text.strip())
    return results

def generate_key(text):
    clean_text = re.sub(r'[^a-zA-Z0-9 ]', '', text)
    words = clean_text.split()
    if not words: return "textKey"
    key = words[0].lower() + ''.join(w.capitalize() for w in words[1:])
    return key[:40]

# =========================
# MERGE LOGIC (NEW)
# =========================
def update_arb(strings, output_path):
    existing_arb = {}
    if os.path.exists(output_path):
        try:
            with open(output_path, "r", encoding="utf-8") as f:
                existing_arb = json.load(f)
            print(f"📥 Loaded {len(existing_arb)} existing keys.")
        except:
            print("⚠️ Could not load existing ARB, creating new.")

    new_arb = {k: v for k, v in existing_arb.items() if k.startswith("@@")}
    if "@@locale" not in new_arb:
        new_arb["@@locale"] = "en"

    value_to_key_map = {v: k for k, v in existing_arb.items() if not k.startswith("@")}

    added_count = 0
    for text in strings:
        if text in value_to_key_map:
            key = value_to_key_map[text]
            new_arb[key] = text
        else:
            base_key = generate_key(text)
            key = base_key
            i = 1
            while key in new_arb:
                key = f"{base_key}{i}"
                i += 1
            new_arb[key] = text
            added_count += 1

    for k, v in existing_arb.items():
        if k not in new_arb:
            new_arb[k] = v

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(new_arb, f, indent=2, ensure_ascii=False)

    print(f"\n✅ Merged successfully: {output_path}")
    print(f"Total keys: {len(new_arb)} (Added {added_count} new strings)")

# =========================
# MAIN
# =========================
if __name__ == "__main__":
    print("-" * 30)
    print(" FLUTTER L10N MERGER V3")
    print("-" * 30)
    
    lib_path = Path(PROJECT_PATH) / "lib"
    all_strings = []
    dart_files = list(lib_path.rglob("*.dart"))
    
    print(f"Scanning {len(dart_files)} files...")
    for dart_file in dart_files:
        if dart_file.name.endswith(('.g.dart', '.freezed.dart', 'app_localizations.dart')): continue
        all_strings.extend(extract_text_widgets(dart_file))

    unique_strings = sorted(list(set(all_strings)))
    
    if unique_strings:
        update_arb(unique_strings, OUTPUT_ARB)
    else:
        print("No strings found to extract.")