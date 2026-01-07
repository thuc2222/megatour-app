import os

# ================= CONFIG =================
# 1. Tên package của bạn (Xem dòng 'name:' đầu tiên trong pubspec.yaml)
PACKAGE_NAME = "megatour_app" 

# 2. Dòng import cần thêm (Dùng dạng package để đúng mọi nơi)
IMPORT_LINE = f"import 'package:{PACKAGE_NAME}/utils/context_extension.dart';"

# 3. Thư mục cần quét (Thường là lib/screens)
TARGET_DIR = "lib/screens" 
# ==========================================

def add_import_to_files():
    count = 0
    skipped = 0
    
    # Duyệt qua tất cả file trong thư mục
    for root, dirs, files in os.walk(TARGET_DIR):
        for file in files:
            if file.endswith(".dart"):
                file_path = os.path.join(root, file)
                
                with open(file_path, "r", encoding="utf-8") as f:
                    lines = f.readlines()
                
                # 1. Kiểm tra xem đã có import extension chưa
                has_import = any("utils/context_extension.dart" in line for line in lines)
                
                if has_import:
                    # print(f"⏩ Skipped (Already exists): {file}")
                    skipped += 1
                    continue
                
                # 2. Tìm vị trí để chèn (Sau dòng import cuối cùng)
                last_import_index = -1
                for i, line in enumerate(lines):
                    if line.strip().startswith("import "):
                        last_import_index = i
                
                # Nếu file chưa có import nào (hiếm), chèn đầu file
                if last_import_index == -1:
                    insert_index = 0
                else:
                    insert_index = last_import_index + 1

                # 3. Chèn dòng import mới
                lines.insert(insert_index, IMPORT_LINE + "\n")
                
                # 4. Ghi lại file
                with open(file_path, "w", encoding="utf-8") as f:
                    f.writelines(lines)
                
                print(f"✅ Added to: {file}")
                count += 1

    print("-" * 30)
    print(f"Hoàn tất! Đã thêm vào {count} file.")
    print(f"Đã bỏ qua {skipped} file (do đã có sẵn).")

if __name__ == "__main__":
    add_import_to_files()