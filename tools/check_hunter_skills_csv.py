import sys
sys.stdout.reconfigure(encoding='utf-8')
from pathlib import Path

csv_path = Path(r"d:\Codes\GG_Antigravity\smsm2-game\extracted_luas\rec_3488.csv")
with open(csv_path, 'r', encoding='gbk', errors='ignore') as f:
    headers = f.readline().strip().split(',')
    print("Headers:", headers[:15])
    for line in f:
        row = line.strip().split(',')
        if len(row) > 13 and any(k in row[13] for k in ['扫射', '连珠箭', '精准射击', '痛击', '强力攻击']):
            print(f"ID={row[0]}, Lv={row[1]}, Name={row[13]}, SP={row[8]}, MP={row[18] if len(row)>18 else 'N/A'}")
