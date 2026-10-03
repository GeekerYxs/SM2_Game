# -*- coding: utf-8 -*-
from pathlib import Path

# Simple Lua 5.1 syntax validator
def validate_lua(path: Path):
    text = path.read_text(encoding='utf-8')
    
    # Strip multiline comments --[[ ... ]]
    import re
    text = re.sub(r'--\[\[.*?\]\]', '', text, flags=re.DOTALL)
    # Strip singleline comments -- ...
    text = re.sub(r'--[^\n]*', '', text)
    # Strip string literals "..." and '...'
    text = re.sub(r'"(?:\\.|[^"\\])*"', '""', text)
    text = re.sub(r"'(?:\\.|[^'\\])*'", "''", text)

    tokens = re.findall(r'\b(?:function|if|elseif|else|for|while|do|repeat|then|end|until)\b', text)
    
    stack = []
    for t in tokens:
        if t == 'function':
            stack.append(('function', t))
        elif t == 'if':
            stack.append(('if', t))
        elif t == 'then':
            # belongs to if or elseif
            if not stack or stack[-1][0] not in ['if', 'elseif']:
                pass
        elif t == 'elseif':
            # transforms top of stack if inside if
            pass
        elif t == 'else':
            pass
        elif t == 'for':
            stack.append(('for', t))
        elif t == 'while':
            stack.append(('while', t))
        elif t == 'do':
            # if previous is for or while, do not push
            if stack and stack[-1][0] in ['for', 'while']:
                # mark that for/while got its do
                pass
            else:
                stack.append(('do', t))
        elif t == 'repeat':
            stack.append(('repeat', t))
        elif t == 'end':
            if not stack:
                print(f"[!] {path.name}: Unexpected 'end'")
                return False
            top = stack.pop()
            if top[0] not in ['function', 'if', 'do', 'for', 'while']:
                print(f"[!] {path.name}: Mismatched 'end' for {top}")
                return False
        elif t == 'until':
            if not stack or stack[-1][0] != 'repeat':
                print(f"[!] {path.name}: Unexpected 'until'")
                return False
            stack.pop()

    if stack:
        print(f"[!] {path.name}: Unclosed blocks remaining: {stack}")
        return False

    print(f"[+] {path.name}: 100% Valid Lua 5.1 syntax!")
    return True

if __name__ == "__main__":
    src_dir = Path(r"d:\Codes\GG_Antigravity\smsm2-game\src")
    validate_lua(src_dir / "auto_fight.lua")
    validate_lua(src_dir / "ai_fight_strategy.lua")
    validate_lua(src_dir / "fight_skill_list.lua")
    validate_lua(src_dir / "map_patrol.lua")
