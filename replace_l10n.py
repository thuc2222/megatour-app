import os
import re
import json

# ================= CONFIG =================
ARB_PATH = "lib/l10n/app_en.arb"
TARGET_DIR = "lib/screens" # Chỉ quét thư mục màn hình cho an toàn
PACKAGE_NAME = "megatour_app" # Xem trong pubspec.yaml
EXTENSION_IMPORT = f"import 'package:{PACKAGE_NAME}/utils/context_extension.dart';"

# Chỉ thay thế nếu chuỗi nằm trong các ngữ cảnh UI này (Regex Lookbehind giả lập)
# Để tránh thay nhầm các key logic như "status": "active"
UI_PATTERNS = [
    r'(Text\s*\(\s*)',                  # Text("...")
    r'(hintText\s*:\s*)',               # hintText: "..."
    r'(labelText\s*:\s*)',              # labelText: "..."
    r'(label\s*:\s*)',                  # label: "..." (NavigationBar)
    r'(title\s*:\s*)',                  # title: "..."
    r'(subtitle\s*:\s*)',               # subtitle: "..."
    r'(errorText\s*:\s*)',              # errorText: "..."
    r'(helperText\s*:\s*)',             # helperText: "..."
    r'(message\s*:\s*)',                # Tooltip(message: "...")
    r'(semanticsLabel\s*:\s*)',         # semanticsLabel: "..."
]

# ================= LOGIC =================

def load_arb_map(arb_path):
    """Đọc file ARB và tạo Map ngược: Value -> Key"""
    with open(arb_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # Map ngược: "Xin chào" -> "hello"
    # Bỏ qua các key bắt đầu bằng @
    reverse_map = {}
    for k, v in data.items():
        if not k.startswith('@'):
            # Lưu ý: Nếu có nhiều key chung 1 value, key sau sẽ đè key trước
            # Ta ưu tiên key ngắn hơn hoặc key đẹp hơn nếu muốn (ở đây lấy mặc định)
            if v not in reverse_map: 
                reverse_map[v] = k
    
    # Sắp xếp theo độ dài giảm dần để thay thế chuỗi dài trước (tránh thay thế nhầm chuỗi con)
    # VD: "Hello World" thay trước "Hello"
    return dict(sorted(reverse_map.items(), key=lambda item: len(item[0]), reverse=True))

def process_file(file_path, value_to_key_map):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    replacement_count = 0

    # Duyệt qua từng cặp Text -> Key
    for text_value, key in value_to_key_map.items():
        # Escape các ký tự đặc biệt trong text để dùng trong Regex
        escaped_text = re.escape(text_value)
        
        # Regex giải thích:
        # 1. (Prefix): Bắt các cụm UI (Text(, label:...)
        # 2. r?['"]: Dấu nháy đơn hoặc kép
        # 3. escaped_text: Nội dung chữ cần tìm
        # 4. ['"]: Dấu nháy đóng
        
        # Tạo pattern gộp tất cả prefix UI
        prefixes = "|".join(UI_PATTERNS)
        pattern = f'({prefixes})(r?[\'"]{escaped_text}[\'"])'
        
        # Hàm thay thế
        def replace_fn(match):
            prefix = match.group(1) # VD: Text(
            # Trả về: Text(context.l10n.myKey
            return f"{prefix}context.l10n.{key}"

        # Thực hiện replace
        new_content, count = re.subn(pattern, replace_fn, content)
        if count > 0:
            content = new_content
            replacement_count += count

    # Nếu có thay đổi, thêm import và ghi file
    if replacement_count > 0:
        # Thêm import nếu chưa có
        if "utils/context_extension.dart" not in content:
            lines = content.splitlines()
            last_import_idx = -1
            for i, line in enumerate(lines):
                if line.strip().startswith("import "):
                    last_import_idx = i
            
            # Chèn sau import cuối cùng
            if last_import_idx != -1:
                lines.insert(last_import_idx + 1, EXTENSION_IMPORT)
            else:
                lines.insert(0, EXTENSION_IMPORT)
            
            content = "\n".join(lines)

        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        
        print(f"✅ Modified: {file_path} ({replacement_count} replacements)")
    
    return replacement_count

def main():
    print("🚀 Starting Automatic Refactor...")
    
    # 1. Load Map
    if not os.path.exists(ARB_PATH):
        print("❌ ARB file not found!")
        return
        
    val_map = load_arb_map(ARB_PATH)
    print(f"Loaded {len(val_map)} strings from ARB.")

    # 2. Scan & Replace
    total_files = 0
    total_replacements = 0
    
    for root, dirs, files in os.walk(TARGET_DIR):
        for file in files:
            if file.endswith(".dart"):
                file_path = os.path.join(root, file)
                total_files += 1
                total_replacements += process_file(file_path, val_map)

    print("-" * 30)
    print(f"Done! Scanned {total_files} files.")
    print(f"Replaced {total_replacements} strings.")
    print("⚠️  PLEASE CHECK YOUR CODE FOR ERRORS (Missing context, keywords, etc.)")

if __name__ == "__main__":
    main()