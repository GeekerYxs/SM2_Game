import glob, csv

for path in glob.glob('extracted_luas/*.csv'):
    try:
        with open(path, 'r', encoding='gbk', errors='ignore') as f:
            for i, line in enumerate(f):
                if line.startswith('1503,') or line.startswith('1503\t') or ',1503,' in line:
                    print(f"Found 1503 in {path} L{i+1}: {line.strip()[:100]}")
    except Exception as e:
        pass
