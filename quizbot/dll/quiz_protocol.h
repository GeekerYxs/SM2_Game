// quiz_protocol.h — 大冒险2 传输层协议纯函数（无 Windows 依赖，可移植测试）
// 帧格式（已实测验证，见交接包 docs）：
//   [inv:u16 LE][op:u16 LE][混淆正文 length 字节]
//   length = (~inv) & 0xFFFF；index = ((op<<8) ^ inv) % 10
//   正文第 i 字节过 表[(index+i)%10]
//   S->C 用 decode 表组（wire->plain）；C->S 用 encode 表组（plain->wire）
#pragma once
#include <cstdint>
#include <cstddef>
#include <cstring>
#include <string>
#include <vector>

namespace qp {

constexpr uint16_t OP_QUESTION  = 0x46F4;  // S->C 题目下发
constexpr uint16_t OP_ANSWER     = 0x1F04;  // C->S 答案（13B）
constexpr uint16_t OP_SYSPROMPT  = 0x46FF;  // S->C 系统提示
constexpr uint16_t OP_CURRENCY   = 0x40E5;  // S->C 疑似货币更新
constexpr uint16_t MAX_BODY      = 0x1BFC;  // 超长帧判定阈值

inline uint16_t body_len(uint16_t inv) { return (uint16_t)(~inv); }
inline int frame_index(uint16_t op, uint16_t inv) {
    return (int)((((uint32_t)op << 8) ^ inv) % 10);
}

struct Tables {
    uint8_t enc[10][256];   // C->S: plain -> wire
    uint8_t dec[10][256];   // S->C: wire -> plain
    bool valid = false;

    bool check_bijection() const {
        for (int t = 0; t < 10; t++) {
            bool seen[256] = {};
            for (int i = 0; i < 256; i++) {
                if (seen[enc[t][i]]) return false;
                seen[enc[t][i]] = true;
            }
            memset(seen, 0, sizeof seen);
            for (int i = 0; i < 256; i++) {
                if (seen[dec[t][i]]) return false;
                seen[dec[t][i]] = true;
            }
        }
        return true;
    }
};

// S->C 解码
inline void decode_s2c(const Tables& tb, uint16_t op, uint16_t inv,
                       const uint8_t* wire, size_t n, uint8_t* out) {
    int idx = frame_index(op, inv);
    for (size_t i = 0; i < n; i++)
        out[i] = tb.dec[(idx + (int)i) % 10][wire[i]];
}
// C->S 编码
inline void encode_c2s(const Tables& tb, uint16_t op, uint16_t inv,
                       const uint8_t* plain, size_t n, uint8_t* out) {
    int idx = frame_index(op, inv);
    for (size_t i = 0; i < n; i++)
        out[i] = tb.enc[(idx + (int)i) % 10][plain[i]];
}

// 流式分帧：把收到的任意切分块累积进 buf，切出完整帧回调 fn(op, inv, body_off, body_len)
// 返回消费后的剩余偏移；bad=true 表示流错位（上层应告警并重置该 socket 缓冲）。
template <typename F>
inline size_t parse_stream(std::vector<uint8_t>& buf, size_t append_off, F&& fn, bool& bad) {
    bad = false;
    size_t off = 0;
    while (buf.size() - off >= 4) {
        uint16_t inv, op;
        memcpy(&inv, &buf[off], 2);
        memcpy(&op, &buf[off + 2], 2);
        uint16_t len = body_len(inv);
        if (len > MAX_BODY) { bad = true; break; }          // 错位/脏数据
        if (buf.size() - off - 4 < len) break;              // 半包，等后续
        fn(op, inv, off + 4, (size_t)len);
        off += 4 + (size_t)len;
    }
    (void)append_off;
    return off;
}

struct Question {
    uint32_t field_a = 0;    // 88/89，语义未定
    uint8_t  flag = 0;      // 恒 01
    uint32_t qno = 0;        // 题号
    std::string stem;       // GBK 原始字节
    std::vector<std::string> options;  // GBK 原始字节
    bool parse_ok = false;
    std::string err;
};

// 解析 0x46F4 明文正文（结构封闭零剩余，实测验证）
inline Question parse_question(const uint8_t* p, size_t n) {
    Question q;
    auto fail = [&](const char* e) { q.err = e; return q; };
    if (n < 10) return fail("body<10");
    memcpy(&q.field_a, p, 4);
    q.flag = p[4];
    memcpy(&q.qno, p + 5, 4);
    uint8_t slen = p[9];
    if (10 + (size_t)slen > n) return fail("stem_overflow");
    q.stem.assign((const char*)p + 10, slen);
    size_t pos = 10 + slen;
    if (pos >= n) return fail("no_optcount");
    uint8_t nopt = p[pos++];
    for (int i = 0; i < nopt; i++) {
        if (pos >= n) return fail("opt_len_oob");
        uint8_t l = p[pos++];
        if (pos + l > n) return fail("opt_body_oob");
        q.options.emplace_back((const char*)p + pos, l);
        pos += l;
    }
    if (pos != n) return fail("trailing_bytes");
    q.parse_ok = true;
    return q;
}

// 0x46FF 系统提示：[201021:i32][len:i32][GBK text + 00]
inline bool parse_sysprompt(const uint8_t* p, size_t n, std::string& gbk_out) {
    if (n < 8) return false;
    int32_t len;
    memcpy(&len, p + 4, 4);
    if (len < 1 || 8 + (size_t)len > n) return false;
    gbk_out.assign((const char*)p + 8, (size_t)len);
    if (!gbk_out.empty() && gbk_out.back() == '\0') gbk_out.pop_back();
    return true;
}

// 构造 0x1F04 答案包（13B 线上字节）。逐字节验证：题号13/选项0、题号16/选项2。
inline std::vector<uint8_t> build_answer(const Tables& tb, uint32_t qno, uint8_t opt) {
    uint8_t plain[9];
    uint32_t five = 5;
    memcpy(plain, &five, 4);
    memcpy(plain + 4, &qno, 4);
    plain[8] = opt;
    uint16_t inv = body_len((uint16_t)9);   // 0xFFF6
    uint16_t op = OP_ANSWER;
    std::vector<uint8_t> wire(4 + 9);
    memcpy(&wire[0], &inv, 2);
    memcpy(&wire[2], &op, 2);
    encode_c2s(tb, op, inv, plain, 9, &wire[4]);
    return wire;
}

// ---- 流过滤（题目屏蔽）----
// 目标：0x46F4 题目帧不交付给游戏（游戏端不弹框），答出后销毁，超时放行（手动兜底）。
// 纯字节操作、无平台依赖，与 DLL hook_recv / 离线测试共用。
struct StreamFilter {
    struct Held {
        uint32_t qno = 0;
        std::vector<uint8_t> wire;   // 完整帧（含 4B 头），放行时按原字节交付
        uint32_t age_ms = 0;
    };
    std::vector<uint8_t> pend;       // 半包累积
    std::vector<uint8_t> outq;       // 待交付给游戏的字节（含超时放行的帧）
    size_t out_off = 0;
    std::vector<Held> held;
    uint32_t hold_ms = 15000;        // 扣住时长：等控制器/LLM 出答案
                                     // 最坏路径 管道0.8s+LLM超时8s+答题延迟0.5s≈9.3s，留余量

    // 喂入网络数据。fn(op, inv, body, blen, *qno) 对每个完整帧调用；
    // 返回 true = 扣住该帧（*qno 填题号用于 consume），false = 正常交付。
    // bad=true 表示流错位（上层应清空 pend/outq 并告警）。
    template <typename Fn>
    void feed(const uint8_t* data, size_t n, Fn&& fn, bool& bad) {
        pend.insert(pend.end(), data, data + n);
        if (pend.size() > (4 + (size_t)MAX_BODY) * 8) { bad = true; return; }
        size_t off = 0;
        while (pend.size() - off >= 4) {
            uint16_t inv, op;
            memcpy(&inv, &pend[off], 2);
            memcpy(&op, &pend[off + 2], 2);
            uint16_t blen = body_len(inv);
            if (blen > MAX_BODY) { bad = true; return; }
            if (pend.size() - off - 4 < blen) break;          // 半包，等后续
            uint32_t qno = 0;
            bool hold = fn(op, inv, &pend[off + 4], blen, &qno);
            size_t flen = 4 + blen;
            if (hold) {
                Held h; h.qno = qno;
                h.wire.assign(pend.begin() + off, pend.begin() + off + flen);
                held.push_back(std::move(h));
            } else {
                outq.insert(outq.end(), pend.begin() + off, pend.begin() + off + flen);
            }
            off += flen;
        }
        pend.erase(pend.begin(), pend.begin() + (long)off);
    }

    void tick(uint32_t ms) {          // 超时放行：按序追加到交付队列尾部
        for (size_t i = 0; i < held.size();) {
            held[i].age_ms += ms;
            if (held[i].age_ms >= hold_ms) {
                outq.insert(outq.end(), held[i].wire.begin(), held[i].wire.end());
                held.erase(held.begin() + i);
            } else i++;
        }
    }

    bool consume(uint32_t qno) {      // 答案已发出：销毁扣住的题帧
        for (size_t i = 0; i < held.size(); i++)
            if (held[i].qno == qno) { held.erase(held.begin() + i); return true; }
        return false;
    }

    int deliver(char* dst, int cap) { // 交付给游戏，返回字节数（0 = 暂无可交付）
        if (out_off >= outq.size()) { outq.clear(); out_off = 0; return 0; }
        size_t avail = outq.size() - out_off;
        size_t n = avail < (size_t)cap ? avail : (size_t)cap;
        memcpy(dst, outq.data() + out_off, n);
        out_off += n;
        if (out_off == outq.size()) { outq.clear(); out_off = 0; }
        else if (out_off > 4096) { outq.erase(outq.begin(), outq.begin() + (long)out_off); out_off = 0; }
        return (int)n;
    }

    void reset() { pend.clear(); outq.clear(); out_off = 0; held.clear(); }
};

} // namespace qp
