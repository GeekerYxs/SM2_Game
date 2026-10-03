import sys
from pathlib import Path

sys.stdout.reconfigure(encoding='utf-8')

# Search for class/job names in strings of WAATClient.exe or CSVs
with open(r'D:\什么什么大冒险2.0\v2.1\Win32\WAATClient.exe', 'rb') as f:
    data = f.read()

# Look for profession names
classes = ['新手', '战士', '格斗家', '狂战士', '圣骑士', '守卫', 
           '学者', '医师', '医仙', '药剂师', 
           '法师', '术士', '魔导师', '元素师', 
           '弓手', '猎人', '神射手', '游侠', 
           '浪客', '刺客', '影杀者']

print("Profession keywords in WAATClient.exe:")
for c in classes:
    count = data.count(c.encode('gbk'))
    print(f"  {c}: {count} occurrences")
