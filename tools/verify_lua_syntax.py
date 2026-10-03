# -*- coding: utf-8 -*-
import re
from pathlib import Path

def strip_lua_comments_and_strings(code: str) -> str:
    # 1. Strip block comments --[[ ... ]] or --[=[ ... ]=]
    code = re.sub(r'--\[(=*)\[[\s\S]*?\]\1\]', '', code)
    # 2. Strip single line comments -- ...
    code = re.sub(r'--[^\n]*', '', code)
    # 3. Strip long strings [[ ... ]] or [=[ ... ]=]
    code = re.sub(r'\[(=*)\[[\s\S]*?\]\1\]', '""', code)
    # 4. Strip single and double quoted strings
    code = re.sub(r'"(?:\\.|[^"\\])*"', '""', code)
    code = re.sub(r"'(?:\\.|[^'\\])*'", "''", code)
    return code

def verify_lua_file(path: Path):
    if not path.exists():
        print(f"[!] File not found: {path}")
        return False
    raw_code = path.read_text(encoding='utf-8')
    clean_code = strip_lua_comments_and_strings(raw_code)
    
    # Track lines approximately
    lines = clean_code.splitlines()
    stack = []
    
    for idx, line in enumerate(lines, 1):
        words = re.findall(r'\b(?:function|if|elseif|for|while|repeat|do|end|until)\b', line)
        for w in words:
            if w == 'if':
                stack.append(('if', idx))
            elif w == 'elseif':
                pass # shares end with if
            elif w == 'for':
                stack.append(('for', idx))
            elif w == 'while':
                stack.append(('while', idx))
            elif w == 'repeat':
                stack.append(('repeat', idx))
            elif w == 'function':
                stack.append(('function', idx))
            elif w == 'do':
                # Check if this 'do' belongs to 'for' or 'while'
                if stack and stack[-1][0] in ('for', 'while'):
                    top = stack.pop()
                    stack.append((top[0] + '_done', top[1]))
                else:
                    stack.append(('do', idx))
            elif w == 'end':
                if not stack:
                    print(f"[!] Syntax error at line {idx} in {path.name}: unexpected 'end'")
                    return False
                top = stack.pop()
                if top[0] not in ('if', 'for_done', 'while_done', 'do', 'function'):
                    print(f"[!] Syntax error at line {idx} in {path.name}: unexpected 'end' closing {top}")
                    return False
            elif w == 'until':
                if not stack or stack[-1][0] != 'repeat':
                    print(f"[!] Syntax error at line {idx} in {path.name}: unexpected 'until'")
                    return False
                stack.pop()

    if stack:
        print(f"[!] Syntax error: unclosed block(s) in {path.name}: {stack}")
        return False
    
    print(f"[+] {path.name}: Block matching verified successfully! (0 syntax errors)")
    return True

if __name__ == "__main__":
    src_dir = Path(r"d:\Codes\GG_Antigravity\smsm2-game\src")
    files_to_check = [
        "auto_fight.lua",
        "ai_fight_strategy.lua",
        "fight_skill_list.lua",
    ]
    all_ok = True
    for f in files_to_check:
        if not verify_lua_file(src_dir / f):
            all_ok = False
            
    if all_ok:
        print("\nAll Lua files verified cleanly!")
    else:
        exit(1)
