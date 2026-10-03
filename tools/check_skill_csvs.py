import sys
sys.stdout.reconfigure(encoding='utf-8')
from pathlib import Path

p = Path('extracted_luas/rec_7662.csv')
with open(p, 'r', encoding='gbk', errors='ignore') as f:
    headers = f.readline().strip().split(',')
    for line in f:
        row = line.strip().split(',')
        if len(row) > 22 and row[0] in ['307', '308', '309', '310', '803', '104']:
            if row[1] in ['1', '5', '6', '12']:
                print(f"ID={row[0]}, Lv={row[1]}, Name={row[14]}, 蓄力点(SP)={row[9]}, 消耗值(MP)={row[21]}, 职业={row[22]}")
