import os
import re
import json

# ================= CONFIG =================
PROJECT_DIR = "lib"  
ARB_EN_PATH = "lib/l10n/app_en.arb"
ARB_VI_PATH = "lib/l10n/app_vi.arb"

# ================= LOGIC =================

def camel_to_sentence(text):
    """Chuyển camelCase thành Sentence case"""
    s1 = re.sub('(.)([A-Z][a-z]+)', r'\1 \2', text)
    s2 = re.sub('([a-z0-9])([A-Z])', r'\1 \2', s1)
    return s2.capitalize()

def scan_keys_in_code(directory):
    found_keys = set()
    print(f"🔍 Đang quét code trong thư mục '{directory}'...")
    
    # Regex CẢI TIẾN: Bắt được cả context.l10n.key VÀ AppLocalizations.of(context)!.key
    # Bắt luôn cả trường hợp có dấu chấm than (!) hoặc khoảng trắng thừa
    regex_pattern = r'(?:context\.l10n|AppLocalizations\.of\(context\)!?)\s*\.\s*([a-zA-Z0-9_]+)'
    
    file_count = 0
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith(".dart"):
                file_count += 1
                path = os.path.join(root, file)
                with open(path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    matches = re.findall(regex_pattern, content)
                    for key in matches:
                        # Debug: In ra nếu tìm thấy key nghi vấn
                        if key == "tourNotFound":
                            print(f"   👀 Thấy 'tourNotFound' trong file: {file}")
                        found_keys.add(key)
                        
    print(f"✅ Đã quét {file_count} file Dart.")
    print(f"✅ Tìm thấy tổng cộng {len(found_keys)} key khác nhau.")
    return found_keys

def update_arb_file(arb_path, found_keys, is_vietnamese=False):
    """Cập nhật file ARB"""
    if not os.path.exists(arb_path):
        print(f"❌ Không tìm thấy file: {arb_path}")
        return

    # Đọc file cũ
    try:
        with open(arb_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except json.JSONDecodeError:
        data = {"@@locale": "vi" if is_vietnamese else "en"}

    # Tìm key còn thiếu
    missing_keys = []
    for key in found_keys:
        if key not in data:
            missing_keys.append(key)

    if not missing_keys:
        print(f"👌 File {os.path.basename(arb_path)} đã đủ key.")
        return

    # Thêm key thiếu
    print(f"⚡ Đang thêm {len(missing_keys)} key vào {os.path.basename(arb_path)}...")
    for key in missing_keys:
        text_content = camel_to_sentence(key)
        if is_vietnamese:
            data[key] = f"[DỊCH] {text_content}"
        else:
            data[key] = text_content
        print(f"   + [MỚI] {key}")

    # Ghi lại file
    with open(arb_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    print("💾 Đã lưu file thành công.")

def main():
    print("🚀 BẮT ĐẦU ĐỒNG BỘ L10N V2")
    print("-" * 30)
    
    # 1. Quét code
    used_keys = scan_keys_in_code(PROJECT_DIR)
    
    if not used_keys:
        print("❌ Không tìm thấy key nào dạng 'context.l10n.xxx'. Hãy kiểm tra lại code.")
        return

    # 2. Cập nhật file ARB
    print("\n--- Xử lý Tiếng Anh ---")
    update_arb_file(ARB_EN_PATH, used_keys, is_vietnamese=False)

    print("\n--- Xử lý Tiếng Việt ---")
    update_arb_file(ARB_VI_PATH, used_keys, is_vietnamese=True)
    
    print("-" * 30)
    print("✅ HOÀN TẤT! Hãy chạy lệnh: flutter gen-l10n")

if __name__ == "__main__":
    main()