import json
import os
import requests

# =====================
# CONFIG
# =====================
API_KEY = "AIzaSyBifJGdDSsvVsiu04kOvo4JePC_9b8Ry4k"  # API KEY CỦA BẠN
INPUT_ARB = "lib/l10n/app_en.arb"
OUTPUT_DIR = "lib/l10n"

TARGET_LANGS = {
    "ar": "app_ar.arb",
    "fr": "app_fr.arb",
    "vi": "app_vi.arb",
    "zh-CN": "app_zh.arb"
}

# =====================
# TRANSLATE FUNCTION
# =====================
def translate_text(text, target_lang):
    url = "https://translation.googleapis.com/language/translate/v2"
    payload = {
        "q": text,
        "source": "en",
        "target": target_lang,
        "format": "text",
        "key": API_KEY
    }
    r = requests.post(url, data=payload)
    r.raise_for_status()
    return r.json()["data"]["translations"][0]["translatedText"]

# =====================
# LOAD SOURCE ARB
# =====================
with open(INPUT_ARB, "r", encoding="utf-8") as f:
    source = json.load(f)

os.makedirs(OUTPUT_DIR, exist_ok=True)

# =====================
# TRANSLATE
# =====================
for lang, filename in TARGET_LANGS.items():
    print(f"🌍 Translating → {lang}")
    result = {"@@locale": lang.split("-")[0]}

    for key, value in source.items():
        if key.startswith("@") or key == "@@locale":
            continue

        if not isinstance(value, str) or not value.strip():
            continue

        try:
            translated = translate_text(value, lang)
        except Exception as e:
            print(f"❌ {key}: {e}")
            translated = value  # fallback

        result[key] = translated

    output_path = os.path.join(OUTPUT_DIR, filename)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(result, f, indent=2, ensure_ascii=False)

    print(f"✅ Created {output_path}")

print("\n🎉 DONE! Run: flutter gen-l10n")
