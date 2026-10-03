import csv

def inspect(path, name):
    with open(path, 'r', encoding='gbk', errors='ignore') as f:
        reader = csv.reader(f)
        header = next(reader)
        print(f"=== {name} ({path}) ===")
        print("Header:", header[:15])
        for row in reader:
            if len(row) > 0 and row[0] in ['1501', '1502', '1503', '1504', '310', '803', '101']:
                print(f"ID={row[0]}, Lv={row[1] if len(row)>1 else ''}, Type={row[2] if len(row)>2 else ''}, Range={row[7] if len(row)>7 else ''}, Name={row[13] if len(row)>13 else ''}")

inspect('extracted_luas/rec_3531.csv', 'MagicLib (rec_3531)')
inspect('extracted_luas/rec_7662.csv', 'SkillLib (rec_7662)')
