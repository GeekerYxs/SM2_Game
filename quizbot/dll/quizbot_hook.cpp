// quizbot_hook.cpp — 大冒险2 纯网络层自动答题 hook DLL（x86，注入 WAATClient.exe）
// =============================================================================
// 纯网络层模式原则：
//   - 所有网络字节 100% 原始透传（p_recv 收到多少原封不动还给游戏，绝不持包、不延时、不修改）
//   - 旁路解析（g_rbuf）仅做入站数据嗅探，识别题目、系统提示、战斗结算
//   - 收到题目后推事件给 Python 控制器（\\.\pipe\quizbot_<pid>），控制器决策后调 SendQuizAnswer 发包
//   - 绝不干涉游戏界面：不拦截答题弹窗、不模拟鼠标点击、不注入 UI 线程
//   - Winsock 原生事件模型不受任何干扰，彻底消除 30 秒超时掉线隐患
// =============================================================================
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <cstdio>
#include <cstdarg>
#include <cstdint>
#include <cstring>
#include <string>
#include <vector>
#include <deque>
#include <map>
#include <atomic>
#include "quiz_protocol.h"

using qp::Tables;
using qp::Question;

// 临界区 RAII 包装（避免引入 gthreads 运行时依赖）
struct CSLock {
    CRITICAL_SECTION& cs;
    CSLock(CRITICAL_SECTION& c) : cs(c) { EnterCriticalSection(&cs); }
    ~CSLock() { LeaveCriticalSection(&cs); }
};

// ---------------- 全局状态 ----------------
static Tables       g_tb;
static HMODULE      g_self = nullptr;
static std::string  g_logdir;
static std::atomic<DWORD> g_recv_bytes{0};
static std::atomic<DWORD> g_frames{0};
static std::atomic<DWORD> g_questions{0};

// 旁路嗅探缓冲（仅用于拼装完整协议帧做明文解码，不拦截交付）
struct SockBuf { std::vector<uint8_t> data; };
static std::map<SOCKET, SockBuf> g_rbuf;
static CRITICAL_SECTION g_sockmtx;

static std::atomic<SOCKET> g_main_sock{INVALID_SOCKET};   // 游戏主会话 Socket

// ---------------- 日志 ----------------
static CRITICAL_SECTION g_logmtx;
static void logline(const char* fmt, ...) {
    CSLock lk(g_logmtx);
    char path[MAX_PATH];
    _snprintf_s(path, sizeof path, _TRUNCATE, "%s\\quizbot_%u.log",
                g_logdir.c_str(), GetCurrentProcessId());
    HANDLE f = CreateFileA(path, FILE_APPEND_DATA,
                           FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr,
                           OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (f == INVALID_HANDLE_VALUE) return;
    char line[2048];
    SYSTEMTIME t; GetLocalTime(&t);
    int n = _snprintf_s(line, sizeof line, _TRUNCATE,
            "%04u-%02u-%02u %02u:%02u:%02u.%03u ",
            t.wYear, t.wMonth, t.wDay, t.wHour, t.wMinute, t.wSecond, t.wMilliseconds);
    va_list ap; va_start(ap, fmt);
    int m = _vsnprintf_s(line + n, sizeof line - n, _TRUNCATE, fmt, ap);
    va_end(ap);
    if (n < 0) n = 0;
    if (m < 0) m = 0;
    n += m;
    if (n < (int)sizeof line - 2) { line[n++] = '\r'; line[n++] = '\n'; }
    DWORD wrote = 0;
    WriteFile(f, line, n, &wrote, nullptr);
    CloseHandle(f);
}

// ---------------- 抓包模式（管道命令 cap_on/cap_off）----------------
static std::atomic<bool> g_capture{false};
static std::atomic<unsigned> g_cap_frames{0};

static void capline(const char* fmt, ...) {
    CSLock lk(g_logmtx);
    char path[MAX_PATH];
    _snprintf_s(path, sizeof path, _TRUNCATE, "%s\\cap_%u.log",
                g_logdir.c_str(), GetCurrentProcessId());
    HANDLE f = CreateFileA(path, FILE_APPEND_DATA,
                           FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr,
                           OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (f == INVALID_HANDLE_VALUE) return;
    char line[16384];
    SYSTEMTIME t; GetLocalTime(&t);
    int n = _snprintf_s(line, sizeof line, _TRUNCATE,
            "%02u:%02u:%02u.%03u ",
            t.wHour, t.wMinute, t.wSecond, t.wMilliseconds);
    va_list ap; va_start(ap, fmt);
    int m = _vsnprintf_s(line + n, sizeof line - n, _TRUNCATE, fmt, ap);
    va_end(ap);
    if (n < 0) n = 0;
    if (m < 0) m = 0;
    n += m;
    if (n < (int)sizeof line - 2) { line[n++] = '\r'; line[n++] = '\n'; }
    DWORD wrote = 0;
    WriteFile(f, line, n, &wrote, nullptr);
    CloseHandle(f);
}

static void hex_of(std::string& out, const uint8_t* p, size_t n, size_t cap) {
    char t[8];
    if (n > cap) n = cap;
    for (size_t i = 0; i < n; i++) {
        _snprintf_s(t, sizeof t, _TRUNCATE, "%02x", p[i]);
        out += t;
    }
    if (n < cap) out += "|trunc";
}

// ---------------- GBK -> UTF-8 ----------------
static std::string gbk_to_utf8(const std::string& gbk) {
    if (gbk.empty()) return {};
    int w = MultiByteToWideChar(936, 0, gbk.data(), (int)gbk.size(), nullptr, 0);
    if (w <= 0) return {};
    std::wstring ws(w, L'\0');
    MultiByteToWideChar(936, 0, gbk.data(), (int)gbk.size(), &ws[0], w);
    int u = WideCharToMultiByte(CP_UTF8, 0, ws.data(), w, nullptr, 0, nullptr, nullptr);
    if (u <= 0) return {};
    std::string out(u, '\0');
    WideCharToMultiByte(CP_UTF8, 0, ws.data(), w, &out[0], u, nullptr, nullptr);
    return out;
}

// ---------------- JSON 转义 ----------------
static std::string jesc(const std::string& s) {
    std::string out;
    out.reserve(s.size() + 8);
    for (unsigned char c : s) {
        switch (c) {
        case '"':  out += "\\\""; break;
        case '\\': out += "\\\\"; break;
        case '\n': out += "\\n";  break;
        case '\r': out += "\\r";  break;
        case '\t': out += "\\t";  break;
        default:
            if (c < 0x20) { char b[8]; _snprintf_s(b, sizeof b, _TRUNCATE, "\\u%04x", c); out += b; }
            else out += (char)c;
        }
    }
    return out;
}

// ---------------- 管道：事件队列 + 异步写线程 ----------------
static HANDLE g_pipe = INVALID_HANDLE_VALUE;
static CRITICAL_SECTION g_wmtx;
static CRITICAL_SECTION g_connmtx;
static std::deque<std::string> g_eq;
static std::atomic<bool> g_stop{false};

static void push_event(std::string line) {
    CSLock lk(g_wmtx);
    if (g_eq.size() > 512) g_eq.pop_front();
    g_eq.push_back(std::move(line));
}

static DWORD WINAPI writer_thread(LPVOID) {
    while (!g_stop.load()) {
        std::string line;
        {
            CSLock lk(g_wmtx);
            if (!g_eq.empty()) { line = std::move(g_eq.front()); g_eq.pop_front(); }
        }
        if (line.empty()) { Sleep(10); continue; }
        bool ok = false;
        {
            CSLock lk(g_connmtx);
            if (g_pipe != INVALID_HANDLE_VALUE) {
                DWORD wrote = 0;
                ok = WriteFile(g_pipe, line.data(), (DWORD)line.size(), &wrote, nullptr) != 0;
                if (!ok) g_pipe = INVALID_HANDLE_VALUE;
            }
        }
        if (!ok) Sleep(50);
    }
    return 0;
}

// ---------------- 帧处理（旁路嗅探） ----------------
static void handle_frame(SOCKET s, uint16_t op, uint16_t inv,
                         const uint8_t* body, size_t len) {
    g_frames++;
    if (g_capture.load()) {
        unsigned cf = g_cap_frames.fetch_add(1);
        if (cf < 300000u) {
            std::vector<uint8_t> plain(len ? len : 1);
            qp::decode_s2c(g_tb, op, inv, body, len, plain.data());
            std::string w, p;
            hex_of(w, body, len, 1024);
            hex_of(p, plain.data(), len, 1024);
            capline("[CAP] %04X inv=%04X len=%zu #%u wire=%s plain=%s",
                    op, inv, len, cf + 1, w.c_str(), p.c_str());
        }
    }

    // 战斗结算（0x472A）
    if (op == 0x472A && len >= 8) {
        std::vector<uint8_t> plain(len);
        qp::decode_s2c(g_tb, op, inv, body, len, plain.data());
        int32_t exp = (int32_t)(plain[4] | (plain[5] << 8) |
                                (plain[6] << 16) | ((uint32_t)plain[7] << 24));
        int32_t gold = (int32_t)(plain[0] | (plain[1] << 8) |
                                 (plain[2] << 16) | ((uint32_t)plain[3] << 24));
        logline("[SETTLE] exp=%d gold=%d len=%zu", exp, gold, len);
        push_event("{\"type\":\"settle\",\"exp\":" + std::to_string(exp) +
                   ",\"gold\":" + std::to_string(gold) + "}\n");
    }

    // 答题下发（0x46F4）
    if (op == qp::OP_QUESTION) {
        std::vector<uint8_t> plain(len);
        qp::decode_s2c(g_tb, op, inv, body, len, plain.data());
        Question q = qp::parse_question(plain.data(), plain.size());
        g_main_sock.store(s);
        g_questions++;
        if (q.parse_ok) {
            std::string ev = "{\"type\":\"question\",\"sock\":" + std::to_string((uint64_t)s) +
                ",\"qno\":" + std::to_string(q.qno) +
                ",\"field_a\":" + std::to_string(q.field_a) +
                ",\"stem\":\"" + jesc(gbk_to_utf8(q.stem)) + "\",\"options\":[";
            for (size_t i = 0; i < q.options.size(); i++) {
                if (i) ev += ",";
                ev += "\"" + jesc(gbk_to_utf8(q.options[i])) + "\"";
            }
            ev += "]}";
            logline("[QUESTION] %s", ev.c_str());
            push_event(std::move(ev) + "\n");
        } else {
            logline("[QUESTION] parse FAIL qno=%u err=%s plainlen=%u",
                    q.qno, q.err.c_str(), (unsigned)len);
            push_event("{\"type\":\"question_bad\",\"qno\":" + std::to_string(q.qno) +
                       ",\"err\":\"" + q.err + "\"}\n");
        }
    } else if (op == qp::OP_SYSPROMPT) {
        std::vector<uint8_t> plain(len);
        qp::decode_s2c(g_tb, op, inv, body, len, plain.data());
        std::string gbk;
        if (qp::parse_sysprompt(plain.data(), plain.size(), gbk)) {
            std::string utf8 = gbk_to_utf8(gbk);
            push_event("{\"type\":\"sys\",\"op\":18263,\"text\":\"" + jesc(utf8) + "\"}\n");
            logline("[SYS] %s", utf8.c_str());
        }
    } else if (op == qp::OP_CURRENCY) {
        std::vector<uint8_t> plain(len);
        qp::decode_s2c(g_tb, op, inv, body, len, plain.data());
        uint32_t a = 0, b = 0;
        if (len >= 8) { memcpy(&a, plain.data(), 4); memcpy(&b, plain.data() + 4, 4); }
        push_event("{\"type\":\"currency\",\"a\":" + std::to_string(a) +
                   ",\"b\":" + std::to_string(b) + "}\n");
    }
}

// 旁路数据分帧：游戏拿原始字节后，这里仅负责拼帧推事件
static void on_recv_data_bypass(SOCKET s, const uint8_t* data, int len) {
    if (len <= 0 || !g_tb.valid) return;
    g_recv_bytes += (DWORD)len;
    CSLock lk(g_sockmtx);
    auto& buf = g_rbuf[s].data;
    buf.insert(buf.end(), data, data + len);
    if (buf.size() > (4u + (size_t)qp::MAX_BODY) * 8) { buf.clear(); return; }
    bool bad = false;
    size_t consumed = qp::parse_stream(buf, buf.size(),
        [&](uint16_t op, uint16_t inv, size_t off, size_t blen) {
            handle_frame(s, op, inv, buf.data() + off, blen);
        }, bad);
    if (bad) { buf.clear(); return; }
    buf.erase(buf.begin(), buf.begin() + (long)consumed);
}

// ---------------- 原函数指针 ----------------
static int (WINAPI *p_recv)(SOCKET, char*, int, int) = nullptr;
static int (WINAPI *p_send)(SOCKET, const char*, int, int) = nullptr;
static int (WINAPI *p_WSASend)(SOCKET, LPWSABUF, DWORD, LPDWORD, DWORD,
                               LPWSAOVERLAPPED, LPWSAOVERLAPPED_COMPLETION_ROUTINE) = nullptr;
static int (WINAPI *p_connect)(SOCKET, const struct sockaddr*, int) = nullptr;
static int (WINAPI *p_closesocket)(SOCKET) = nullptr;

// ---------------- 导出：发答案（控制器经管道触发） ----------------
extern "C" __declspec(dllexport) int SendQuizAnswer(uint32_t qno, uint8_t opt) {
    if (!g_tb.valid) return -1;
    SOCKET s = g_main_sock.load();
    if (s == INVALID_SOCKET) { logline("[SEND-ANSWER] no main sock"); return -2; }
    std::vector<uint8_t> wire = qp::build_answer(g_tb, qno, opt);
    int r = SOCKET_ERROR;
    for (int attempt = 0; attempt < 50; attempt++) {
        r = p_send(s, (const char*)wire.data(), (int)wire.size(), 0);
        if (r != SOCKET_ERROR) break;
        int err = WSAGetLastError();
        if (err != WSAEWOULDBLOCK && err != WSAEINPROGRESS) {
            logline("[SEND-ANSWER] send err=%d sock=%llu", err, (unsigned long long)s);
            push_event("{\"type\":\"sendfail\",\"qno\":" + std::to_string(qno) +
                       ",\"opt\":" + std::to_string(opt) + ",\"err\":" + std::to_string(err) + "}\n");
            return -3;
        }
        Sleep(2);
    }
    if (r == SOCKET_ERROR) {
        push_event("{\"type\":\"sendfail\",\"qno\":" + std::to_string(qno) +
                   ",\"opt\":" + std::to_string(opt) + ",\"err\":\"wouldblock_timeout\"}\n");
        return -4;
    }
    logline("[SEND-ANSWER] qno=%u opt=%u ret=%d sock=%llu", qno, opt, r, (unsigned long long)s);
    push_event("{\"type\":\"sent\",\"qno\":" + std::to_string(qno) +
               ",\"opt\":" + std::to_string(opt) + "}\n");
    return r;
}

// ---------------- hooks ----------------
// 纯网络层 hook_recv：100% 原始透传，零拦截、零延时、零持包
static int WINAPI hook_recv(SOCKET s, char* buf, int len, int flags) {
    int r0 = p_recv(s, buf, len, flags);
    if (r0 > 0) {
        on_recv_data_bypass(s, (const uint8_t*)buf, r0);
    } else if (r0 == SOCKET_ERROR && WSAGetLastError() != WSAEWOULDBLOCK) {
        logline("[NET-E] sock=%llu r=%d err=%d", (unsigned long long)s, r0, WSAGetLastError());
    }
    return r0;
}

static bool looks_like_game_frame(const char* buf, int len) {
    if (len < 4) return false;
    uint16_t inv, op;
    memcpy(&inv, buf, 2); memcpy(&op, buf + 2, 2);
    uint16_t blen = qp::body_len(inv);
    return blen <= qp::MAX_BODY;
}

static CRITICAL_SECTION g_outmtx;
static void sample_out(SOCKET s, const char* buf, int len) {
    if (len < 4 || !g_tb.valid) return;
    if (g_main_sock.load() != s) return;
    uint16_t op, inv;
    memcpy(&inv, buf, 2); memcpy(&op, buf + 2, 2);
    if (op == 0xEFFE || op == 0xF005 || op == 0x0001) {
        CSLock lk(g_outmtx);
        static std::map<uint16_t, DWORD> hbc;
        DWORD c = ++hbc[op];
        if (c <= 3 || c % 30 == 0)
            logline("[HB-OUT] op=%04X #%lu len=%d sock=%llu",
                    op, (unsigned long)c, len, (unsigned long long)s);
        return;
    }
    CSLock lk(g_outmtx);
    static std::map<uint16_t, int> cnt;
    int& c = cnt[op];
    if (c >= 5) return;
    c++;
    size_t n = len < 320 ? (size_t)len : 320;
    std::string hx;
    char t[8];
    for (size_t i = 0; i < n; i++) {
        _snprintf_s(t, sizeof t, _TRUNCATE, "%02x", (uint8_t)buf[i]);
        hx += t;
    }
    logline("[OUT] %04X inv=%04X len=%d #%d %s", op, inv, len, c, hx.c_str());
}

static int WINAPI hook_send(SOCKET s, const char* buf, int len, int flags) {
    if (looks_like_game_frame(buf, len)) {
        uint16_t op; memcpy(&op, buf + 2, 2);
        if (op == 0xF001 || op == 0x47C0 || op == 0x4101) {
            SOCKET old = g_main_sock.load();
            if (old != s) {
                g_main_sock.store(s);
                logline("[MAIN-SOCK] identified game world sock %llu (send op=%04X)",
                        (unsigned long long)s, op);
            }
        }
    }
    sample_out(s, buf, len);
    return p_send(s, buf, len, flags);
}

static int WINAPI hook_WSASend(SOCKET s, LPWSABUF bufs, DWORD cnt, LPDWORD sent,
                               DWORD flags, LPWSAOVERLAPPED ov, LPWSAOVERLAPPED_COMPLETION_ROUTINE cr) {
    if (cnt >= 1 && bufs && bufs[0].len >= 4) {
        if (looks_like_game_frame(bufs[0].buf, (int)bufs[0].len)) {
            uint16_t op; memcpy(&op, bufs[0].buf + 2, 2);
            if (op == 0xF001 || op == 0x47C0 || op == 0x4101) {
                SOCKET old = g_main_sock.load();
                if (old != s) {
                    g_main_sock.store(s);
                    logline("[MAIN-SOCK] identified game world sock %llu (WSASend op=%04X)",
                            (unsigned long long)s, op);
                }
            }
        }
    }
    return p_WSASend(s, bufs, cnt, sent, flags, ov, cr);
}

static int WINAPI hook_connect(SOCKET s, const struct sockaddr* name, int namelen) {
    if (name && namelen >= (int)sizeof(sockaddr_in)) {
        auto* sin = (const sockaddr_in*)name;
        if (sin->sin_family == AF_INET) {
            uint16_t port = ntohs(sin->sin_port);
            logline("[CONNECT] sock %llu -> port %u", (unsigned long long)s, port);
            if (port == 8484) {
                g_main_sock.store(s);
            }
        }
    }
    return p_connect(s, name, namelen);
}

static int WINAPI hook_closesocket(SOCKET s) {
    {
        CSLock lk(g_sockmtx);
        g_rbuf.erase(s);
    }
    SOCKET cur = g_main_sock.load();
    if (cur == s) {
        g_main_sock.store(INVALID_SOCKET);
        logline("[CLOSE] main sock %llu closed", (unsigned long long)s);
    }
    return p_closesocket(s);
}

// ---------------- IAT patch ----------------
struct IatRestore { FARPROC* entry = nullptr; FARPROC orig = nullptr; };
static std::vector<IatRestore> g_restore;

static bool patch_iat_by_addr(const char* func_name_ord, FARPROC target,
                              void* hook, void** orig) {
    uint8_t* base = (uint8_t*)GetModuleHandleA(nullptr);
    auto* dos = (IMAGE_DOS_HEADER*)base;
    auto* nt  = (IMAGE_NT_HEADERS*)(base + dos->e_lfanew);
    auto* dir = &nt->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT];
    if (!dir->VirtualAddress) return false;
    auto* imp = (IMAGE_IMPORT_DESCRIPTOR*)(base + dir->VirtualAddress);
    for (; imp->Name; imp++) {
        auto* thunk = (IMAGE_THUNK_DATA*)(base + imp->FirstThunk);
        for (; thunk->u1.Function; thunk++) {
            if ((FARPROC)thunk->u1.Function != target) continue;
            FARPROC* entry = (FARPROC*)&thunk->u1.Function;
            DWORD oldp;
            if (!VirtualProtect(entry, sizeof(FARPROC), PAGE_READWRITE, &oldp)) continue;
            FARPROC original = *entry;
            *entry = (FARPROC)hook;
            VirtualProtect(entry, sizeof(FARPROC), oldp, &oldp);
            *(FARPROC*)orig = original;
            g_restore.push_back({entry, original});
            return true;
        }
    }
    return false;
}

static bool hook_ws2(const char* fn, void* hookfn, void** origp) {
    HMODULE w2 = GetModuleHandleA("ws2_32.dll");
    if (!w2) return false;
    FARPROC target = nullptr;
    if (fn[0] == '#') target = GetProcAddress(w2, (LPCSTR)(intptr_t)atoi(fn + 1));
    else              target = GetProcAddress(w2, fn);
    if (!target) return false;
    return patch_iat_by_addr(fn, target, hookfn, origp);
}

// ---------------- 管道服务线程 ----------------
static DWORD WINAPI pipe_thread(LPVOID) {
    char name[64];
    _snprintf_s(name, sizeof name, _TRUNCATE, "\\\\.\\pipe\\quizbot_%u", GetCurrentProcessId());
    while (!g_stop.load()) {
        HANDLE p = CreateNamedPipeA(name,
            PIPE_ACCESS_DUPLEX,
            PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT,
            1, 8192, 8192, 0, nullptr);
        if (p == INVALID_HANDLE_VALUE) { Sleep(1000); continue; }
        if (!ConnectNamedPipe(p, nullptr) && GetLastError() != ERROR_PIPE_CONNECTED) {
            CloseHandle(p); Sleep(1000); continue;
        }
        logline("[PIPE] controller connected");
        {
            CSLock lk(g_connmtx);
            g_pipe = p;
        }
        char buf[2048];
        std::string line;
        DWORD n = 0;
        while (!g_stop.load()) {
            if (!ReadFile(p, buf, sizeof buf, &n, nullptr) || n == 0) break;
            line.append(buf, buf + n);
            size_t pos;
            while ((pos = line.find('\n')) != std::string::npos) {
                std::string cmd = line.substr(0, pos);
                line.erase(0, pos + 1);
                if (cmd.empty()) continue;
                if (cmd.find("\"ping\"") != std::string::npos) {
                    push_event("{\"type\":\"pong\",\"pid\":" +
                        std::to_string(GetCurrentProcessId()) + "}\n");
                } else if (cmd.find("\"stats\"") != std::string::npos) {
                    push_event("{\"type\":\"stats\",\"recv_bytes\":" +
                        std::to_string(g_recv_bytes.load()) + ",\"frames\":" +
                        std::to_string(g_frames.load()) + ",\"questions\":" +
                        std::to_string(g_questions.load()) + "}\n");
                } else if (cmd.find("\"answer\"") != std::string::npos) {
                    auto grab = [&](const char* key) -> long long {
                        std::string k = key;
                        auto p1 = cmd.find(k);
                        if (p1 == std::string::npos) return -1;
                        return atoll(cmd.c_str() + p1 + k.size());
                    };
                    long long qno = grab("\"qno\":");
                    long long opt = grab("\"opt\":");
                    if (qno >= 0 && opt >= 0) {
                        SendQuizAnswer((uint32_t)qno, (uint8_t)opt);
                    }
                } else if (cmd.find("\"cap_on\"") != std::string::npos) {
                    g_cap_frames.store(0);
                    g_capture.store(true);
                    logline("[CAP] capture ON (pid %u)", GetCurrentProcessId());
                    capline("[CAP] ---- capture ON ----");
                    push_event("{\"type\":\"cap\",\"state\":\"on\"}\n");
                } else if (cmd.find("\"cap_off\"") != std::string::npos) {
                    g_capture.store(false);
                    logline("[CAP] capture OFF frames=%u", g_cap_frames.load());
                    capline("[CAP] ---- capture OFF frames=%u ----", g_cap_frames.load());
                    push_event("{\"type\":\"cap\",\"state\":\"off\",\"frames\":" +
                        std::to_string(g_cap_frames.load()) + "}\n");
                } else if (cmd.find("\"unload\"") != std::string::npos) {
                    push_event("{\"type\":\"bye\"}\n");
                    g_stop.store(true);
                }
            }
        }
        logline("[PIPE] controller disconnected");
        {
            CSLock lk(g_connmtx);
            g_pipe = INVALID_HANDLE_VALUE;
        }
        DisconnectNamedPipe(p);
        CloseHandle(p);
        Sleep(200);
    }
    return 0;
}

// ---------------- 游戏内存读取解码表 ----------------
static bool rpm_self(uintptr_t addr, void* out, size_t n) {
    SIZE_T got = 0;
    HANDLE self = GetCurrentProcess();
    if (!ReadProcessMemory(self, (LPCVOID)addr, out, n, &got)) return false;
    return got == n;
}

static bool load_codec() {
    uintptr_t base = (uintptr_t)GetModuleHandleA(nullptr);
    uintptr_t enc_ptrs = base + 0x515D6C;
    uintptr_t dec_ptrs = base + 0x515D94;
    for (int i = 0; i < 10; i++) {
        uintptr_t ep = 0, dp = 0;
        if (!rpm_self(enc_ptrs + i * 4, &ep, 4) || !rpm_self(dec_ptrs + i * 4, &dp, 4))
            return false;
        if (ep < 0x10000 || dp < 0x10000) return false;
        if (!rpm_self(ep, g_tb.enc[i], 256)) return false;
        if (!rpm_self(dp, g_tb.dec[i], 256)) return false;
    }
    if (!g_tb.check_bijection()) return false;
    g_tb.valid = true;
    return true;
}

// ---------------- 入口 ----------------
static void restore_all() {
    for (auto& r : g_restore) {
        DWORD oldp;
        if (VirtualProtect(r.entry, sizeof(FARPROC), PAGE_READWRITE, &oldp)) {
            *r.entry = r.orig;
            VirtualProtect(r.entry, sizeof(FARPROC), oldp, &oldp);
        }
    }
    g_restore.clear();
}

BOOL APIENTRY DllMain(HMODULE h, DWORD reason, LPVOID) {
    if (reason == DLL_PROCESS_ATTACH) {
        g_self = h;
        DisableThreadLibraryCalls(h);
        InitializeCriticalSection(&g_sockmtx);
        InitializeCriticalSection(&g_logmtx);
        InitializeCriticalSection(&g_wmtx);
        InitializeCriticalSection(&g_connmtx);
        InitializeCriticalSection(&g_outmtx);

        char path[MAX_PATH];
        GetModuleFileNameA(h, path, MAX_PATH);
        char* slash = strrchr(path, '\\');
        if (slash) { *slash = 0; g_logdir = std::string(path) + "\\logs"; }
        else g_logdir = "C:\\quizbot_logs";
        logline("[INIT] dll loaded, pid=%u (pure network mode)", GetCurrentProcessId());

        if (!load_codec()) {
            logline("[INIT] codec load FAILED");
            return TRUE;
        }
        logline("[INIT] codec loaded OK");

        bool ok_recv   = hook_ws2("#16", (void*)hook_recv, (void**)&p_recv);
        bool ok_send   = hook_ws2("#19", (void*)hook_send, (void**)&p_send);
        bool ok_wasend = hook_ws2("WSASend", (void*)hook_WSASend, (void**)&p_WSASend);
        bool ok_conn   = hook_ws2("#4", (void*)hook_connect, (void**)&p_connect);
        bool ok_close  = hook_ws2("#3", (void*)hook_closesocket, (void**)&p_closesocket);

        logline("[INIT] iat hooks: recv=%d send=%d WSASend=%d connect=%d closesocket=%d",
                ok_recv, ok_send, ok_wasend, ok_conn, ok_close);

        push_event("{\"type\":\"init\",\"pid\":" + std::to_string(GetCurrentProcessId()) +
                   ",\"codec_ok\":true,\"mode\":\"network_pure\"}\n");

        CreateThread(nullptr, 0, writer_thread, nullptr, 0, nullptr);
        CreateThread(nullptr, 0, pipe_thread, nullptr, 0, nullptr);
    } else if (reason == DLL_PROCESS_DETACH) {
        g_stop.store(true);
        restore_all();
        logline("[INIT] dll unloaded");
    }
    return TRUE;
}
