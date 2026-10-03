// injector.cpp — quizbot hook 注入器（32 位，注入同为 x86 的 WAATClient.exe）
// 用法：
//   injector.exe                 注入所有 WAATClient.exe（已注入的自动跳过）
//   injector.exe -w              watch 模式：每 3 秒扫描补注入新开的客户端
//   injector.exe <dll路径>       指定 DLL（默认 exe 同目录 quizbot_hook.dll）
// 需要：目标进程用户权限允许（管理员运行更稳）
#include <windows.h>
#include <tlhelp32.h>
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <string>
#include <vector>

static std::wstring exe_dir() {
    wchar_t path[MAX_PATH];
    GetModuleFileNameW(nullptr, path, MAX_PATH);
    wchar_t* slash = wcsrchr(path, L'\\');
    if (slash) *slash = 0;
    return path;
}

static std::string to_utf8(const std::wstring& ws) {
    int n = WideCharToMultiByte(CP_UTF8, 0, ws.c_str(), (int)ws.size(), nullptr, 0, nullptr, nullptr);
    std::string s(n, 0);
    WideCharToMultiByte(CP_UTF8, 0, ws.c_str(), (int)ws.size(), &s[0], n, nullptr, nullptr);
    return s;
}

static std::vector<DWORD> find_pids(const wchar_t* name) {
    std::vector<DWORD> out;
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) return out;
    PROCESSENTRY32W e; e.dwSize = sizeof e;
    if (Process32FirstW(snap, &e)) {
        do {
            if (_wcsicmp(e.szExeFile, name) == 0) out.push_back(e.th32ProcessID);
        } while (Process32NextW(snap, &e));
    }
    CloseHandle(snap);
    return out;
}

static bool has_module(DWORD pid, const wchar_t* dllname) {
    HANDLE snap = INVALID_HANDLE_VALUE;
    for (int retry = 0; retry < 5; retry++) {
        snap = CreateToolhelp32Snapshot(TH32CS_SNAPMODULE | TH32CS_SNAPMODULE32, pid);
        if (snap != INVALID_HANDLE_VALUE) break;
        Sleep(40);
    }
    if (snap == INVALID_HANDLE_VALUE) return false;
    MODULEENTRY32W m; m.dwSize = sizeof m;
    bool found = false;
    if (Module32FirstW(snap, &m)) {
        do {
            if (_wcsicmp(m.szModule, dllname) == 0) { found = true; break; }
        } while (Module32NextW(snap, &m));
    }
    CloseHandle(snap);
    return found;
}

static bool inject_one(DWORD pid, const std::wstring& dll_path) {
    if (has_module(pid, L"quizbot_hook.dll")) {
        printf("  [pid %lu] already injected, skip\n", pid);
        return true;
    }
    HANDLE h = OpenProcess(
        PROCESS_CREATE_THREAD | PROCESS_QUERY_INFORMATION |
        PROCESS_VM_READ | PROCESS_VM_WRITE | PROCESS_VM_OPERATION,
        FALSE, pid);
    if (!h) { printf("  [pid %lu] OpenProcess failed err=%lu\n", pid, GetLastError()); return false; }
    SIZE_T len = (dll_path.size() + 1) * sizeof(wchar_t);
    void* remote = VirtualAllocEx(h, nullptr, len, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
    if (!remote) { printf("  [pid %lu] VirtualAllocEx failed\n", pid); CloseHandle(h); return false; }
    if (!WriteProcessMemory(h, remote, dll_path.c_str(), len, nullptr)) {
        printf("  [pid %lu] WriteProcessMemory failed\n", pid);
        VirtualFreeEx(h, remote, 0, MEM_RELEASE); CloseHandle(h); return false;
    }
    HMODULE k32 = GetModuleHandleA("kernel32.dll");
    auto LLA = (LPTHREAD_START_ROUTINE)GetProcAddress(k32, "LoadLibraryW");
    HANDLE th = CreateRemoteThread(h, nullptr, 0, LLA, remote, 0, nullptr);
    if (!th) {
        printf("  [pid %lu] CreateRemoteThread failed err=%lu\n", pid, GetLastError());
        VirtualFreeEx(h, remote, 0, MEM_RELEASE); CloseHandle(h); return false;
    }
    WaitForSingleObject(th, 8000);
    DWORD code = 0; GetExitCodeThread(th, &code);
    CloseHandle(th);
    VirtualFreeEx(h, remote, 0, MEM_RELEASE);
    CloseHandle(h);
    bool ok = code != 0;
    printf("  [pid %lu] %s\n", pid, ok ? "INJECTED" : "LoadLibrary returned NULL (path wrong?)");
    return ok;
}

// 远程卸载：先由控制器发 unload 命令让 DLL 线程退出，再远程 FreeLibrary
static bool unload_one(DWORD pid) {
    HANDLE h = OpenProcess(
        PROCESS_CREATE_THREAD | PROCESS_QUERY_INFORMATION |
        PROCESS_VM_READ | PROCESS_VM_WRITE | PROCESS_VM_OPERATION,
        FALSE, pid);
    if (!h) { printf("  [pid %lu] OpenProcess failed err=%lu\n", pid, GetLastError()); return false; }
    HMODULE k32 = GetModuleHandleA("kernel32.dll");
    // 1) 远程 GetModuleHandleW 拿到 DLL 基址
    SIZE_T len = 32 * sizeof(wchar_t);
    void* remote = VirtualAllocEx(h, nullptr, len, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
    const wchar_t* nm = L"quizbot_hook.dll";
    WriteProcessMemory(h, remote, nm, len, nullptr);
    auto GMW = (LPTHREAD_START_ROUTINE)GetProcAddress(k32, "GetModuleHandleW");
    HANDLE th = CreateRemoteThread(h, nullptr, 0, GMW, remote, 0, nullptr);
    WaitForSingleObject(th, 5000);
    DWORD hmod = 0; GetExitCodeThread(th, &hmod);
    CloseHandle(th);
    VirtualFreeEx(h, remote, 0, MEM_RELEASE);
    if (!hmod) { printf("  [pid %lu] quizbot_hook.dll not loaded\n", pid); CloseHandle(h); return false; }
    // 2) 远程 FreeLibrary（DLL 的 DETACH 会还原 IAT）
    auto FL = (LPTHREAD_START_ROUTINE)GetProcAddress(k32, "FreeLibrary");
    th = CreateRemoteThread(h, nullptr, 0, FL, (LPVOID)hmod, 0, nullptr);
    WaitForSingleObject(th, 5000);
    CloseHandle(th);
    CloseHandle(h);
    printf("  [pid %lu] FreeLibrary done (module 0x%08lX)\n", pid, hmod);
    return true;
}

int main(int argc, char** argv) {
    std::wstring dll = exe_dir() + L"\\quizbot_hook.dll";
    bool watch = false;
    DWORD only_pid = 0;
    bool do_unload = false;
    for (int i = 1; i < argc; i++) {
        std::string a = argv[i];
        if (a == "-w") watch = true;
        else if (a == "--pid" && i + 1 < argc) only_pid = (DWORD)atol(argv[++i]);
        else if (a == "--unload" && i + 1 < argc) { do_unload = true; only_pid = (DWORD)atol(argv[++i]); }
        else if (a[0] != '-') {
            int n = MultiByteToWideChar(CP_UTF8, 0, a.c_str(), (int)a.size(), nullptr, 0);
            dll.assign(n, 0);
            MultiByteToWideChar(CP_UTF8, 0, a.c_str(), (int)a.size(), &dll[0], n);
        }
    }
    if (GetFileAttributesW(dll.c_str()) == INVALID_FILE_ATTRIBUTES) {
        printf("DLL not found: %s\n", to_utf8(dll).c_str());
        return 1;
    }
    printf("DLL: %s\n", to_utf8(dll).c_str());
    do {
        if (only_pid) {
            if (do_unload) unload_one(only_pid);
            else inject_one(only_pid, dll);
        } else {
            auto pids = find_pids(L"WAATClient.exe");
            if (pids.empty()) printf("no WAATClient.exe running\n");
            for (DWORD pid : pids) inject_one(pid, dll);
        }
        if (watch) Sleep(3000);
    } while (watch);
    printf("done.\n");
    return 0;
}
