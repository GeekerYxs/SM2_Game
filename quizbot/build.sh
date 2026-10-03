#!/usr/bin/env bash
# build.sh — quizbot 全量构建（MinGW-w64 i686，win32 线程模型）
# 产物：build/quizbot_hook.dll, build/injector.exe, build/protocol_test.exe
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
TC=""
# 1) 已解压的标准位置  2) 上次记录的位置  3) 都没有才解压
[ -f "$ROOT/toolchain/mingw32/bin/g++.exe" ] && TC="$ROOT/toolchain/mingw32"
if [ -z "$TC" ] && [ -f "$ROOT/toolchain/tc_path.txt" ]; then
  cand="$(cat "$ROOT/toolchain/tc_path.txt")"
  [ -f "$cand/bin/g++.exe" ] && TC="$cand"
fi
if [ -z "$TC" ]; then
  # 解压工具链（首次）
  echo "[1/4] extracting toolchain..."
  mkdir -p "$ROOT/toolchain/x"
  "/c/Program Files/7-Zip/7z.exe" x "$ROOT/toolchain/mingw.7z" -o"$ROOT/toolchain/x" -y > /dev/null
  found=$(find "$ROOT/toolchain/x" -maxdepth 4 -name "g++.exe" -path "*bin*" | head -1)
  TC="$(dirname "$(dirname "$found")")"
  echo "$TC" > "$ROOT/toolchain/tc_path.txt"
fi
GXX="$TC/bin/g++.exe"
# as.exe/ld.exe 依赖顶层 bin 里的运行时 DLL（缺它则报 STATUS_DLL_NOT_FOUND）
export PATH="$(cygpath -u "$TC/bin" 2>/dev/null || echo "$TC/bin"):$PATH"
"$GXX" --version | head -1

echo "[2/4] generating codec_tables.h (static tables for tests)"
PY="C:/Users/R/.workbuddy/binaries/python/versions/3.13.12/python.exe"
"$PY" "$ROOT/tools/gen_tables.py"

echo "[3/4] compiling..."
CFLAGS="-O2 -std=c++17 -Wall -Wextra -Wno-unused-parameter -mconsole -static -static-libgcc -static-libstdc++"
mkdir -p "$ROOT/build" "$ROOT/logs"

# 协议回放测试（静态表）
"$GXX" $CFLAGS -I"$ROOT/dll" -I"$ROOT/build" -o "$ROOT/build/protocol_test.exe" "$ROOT/tools/protocol_test.cpp"
echo "  -> build/protocol_test.exe"

# hook DLL（运行时从游戏内存读表，不依赖静态表）
"$GXX" $CFLAGS -shared -I"$ROOT/dll" -o "$ROOT/build/quizbot_hook.dll" "$ROOT/dll/quizbot_hook.cpp" -lws2_32 -lgdi32 -luser32
echo "  -> build/quizbot_hook.dll"

# 注入器
"$GXX" $CFLAGS -o "$ROOT/build/injector.exe" "$ROOT/injector/injector.cpp"
echo "  -> build/injector.exe"

echo "[4/4] running protocol replay tests"
"$ROOT/build/protocol_test.exe"
echo "BUILD OK"
