// protocol_test.cpp — DLL 协议逻辑离线回放测试（与 quizbot_hook.cpp 共用 quiz_protocol.h）
// 基准：data/packets_unique.json 的 7 条实抓封包（2026-09-30 答题活动实录）
// 覆盖：分帧（含单段双消息/半包/一字节碎片）、题目解码解析、答案构包逐字节、
//       系统提示解析、主连接 socket 模拟识别
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <string>
#include <vector>
#include "quiz_protocol.h"
#include "codec_tables.h"

using qp::Tables;

static int fails = 0;
#define CHECK(cond, msg) do { \
    if (cond) printf("  PASS  %s\n", msg); \
    else { printf("  FAIL  %s\n", msg); fails++; } \
} while (0)

static std::vector<uint8_t> hex2b(const char* h) {
    std::vector<uint8_t> out;
    for (size_t i = 0; h[i] && h[i + 1]; i += 2) {
        out.push_back((uint8_t)strtoul(std::string(h + i, 2).c_str(), nullptr, 16));
    }
    return out;
}

static std::string hexs(const uint8_t* p, size_t n) {
    std::string s;
    char b[4];
    for (size_t i = 0; i < n; i++) { snprintf(b, sizeof b, "%02x", p[i]); s += b; }
    return s;
}

// 模拟 DLL on_recv_data 的累积逻辑
struct SimSock {
    std::vector<uint8_t> buf;
    std::vector<std::pair<uint16_t, std::vector<uint8_t>>> frames;
    void feed(const uint8_t* d, size_t n, bool c2s, const Tables& tb) {
        buf.insert(buf.end(), d, d + n);
        bool bad = false;
        size_t off = qp::parse_stream(buf, buf.size(), [&](uint16_t op, uint16_t inv, size_t bo, size_t bl) {
            std::vector<uint8_t> wire(buf.begin() + bo, buf.begin() + bo + bl);
            std::vector<uint8_t> plain(bl);
            if (c2s) {  // C->S 用 encode 逆
                int idx = qp::frame_index(op, inv);
                for (size_t i = 0; i < bl; i++) {
                    bool found = false;
                    for (int v = 0; v < 256; v++)
                        if (tb.enc[(idx + i) % 10][v] == wire[i]) { plain[i] = (uint8_t)v; found = true; break; }
                    if (!found) plain[i] = 0;
                }
            } else {
                qp::decode_s2c(tb, op, inv, wire.data(), bl, plain.data());
            }
            frames.push_back({op, plain});
        }, bad);
        if (bad) { buf.clear(); }
        else buf.erase(buf.begin(), buf.begin() + (long)off);
    }
};

int main() {
    Tables tb;
    load_static_tables(tb);
    CHECK(tb.check_bijection(), "tables bijection");

    // ---- 实抓 7 条（quiz02a） ----
    const char* pk_s2c_f005  = "e7ff05f024c812922d93702b1f805b64510bdcfaa3cec4ef18bcb57f";
    const char* pk_ans_wrong = "f6ff041fce1f805bc6510bdcfa";   // C->S qno13 opt0（答错）
    const char* pk_ans_right = "f6ff041fce1f805bb0510bdce8";   // C->S qno16 opt2（答对）
    const char* pk_question = "a3fff4467e805b6458c0dcfaa3d2b97a4f222900e19d6c8d9755846cee695a3b806695ebdb01c5792836d4b97f02bd4e306ab694f919ce12dc89058f0f46f950e483c0e0058f0374a179d04ddbdb83949f6259f7316bdca6058f6e59adc18682"; // S->C 96B 麋鹿题
    const char* pk_sys1     = "ecffff461fd8de1f105b64517d514e6a822f6b9c7b050b";   // S->C 23B 测试通过！
    const char* pk_sys2     = "d9ffff46a75dad805e64510bf80080277c7aeae9572337a24f289f6a6f77532337ec8ac5f71a0be1250bf3ffe540cc8052faa62b1f805b64510b"; // S->C 58B = 0x46FF奖励 + 0x40E5 两条拼接

    // ---- 1) 分帧 + 题目解码（整块投喂）----
    {
        printf("[1] whole-block question decode\n");
        SimSock s;
        s.feed(hex2b(pk_question).data(), hex2b(pk_question).size(), false, tb);
        CHECK(s.frames.size() == 1, "one frame in 96B packet");
        if (s.frames.size() == 1) {
            CHECK(s.frames[0].first == 0x46F4, "op == 0x46F4");
            qp::Question q = qp::parse_question(s.frames[0].second.data(), s.frames[0].second.size());
            CHECK(q.parse_ok, "question parse_ok");
            CHECK(q.qno == 16, "qno == 16");
            CHECK(q.field_a == 88, "field_a == 88");
            CHECK(q.stem.size() == 41, "stem len == 41");
            CHECK(hexs((const uint8_t*)q.stem.data(), q.stem.size()) ==
                  "c8cbc3c7d4dab6afceefd4b0c0efbfb4b5bdb5c4cbd7b3c622cbc4b2bbcff322b5c4b6afceefcac73f",
                  "stem GBK bytes exact");
            CHECK(q.options.size() == 4, "4 options");
            CHECK(q.err.empty(), "no error");
        }
    }
    // ---- 2) 逐字节碎片投喂（流式缓冲）----
    {
        printf("[2] 1-byte-chunk streaming\n");
        SimSock s;
        auto pkt = hex2b(pk_question);
        for (auto b : pkt) s.feed(&b, 1, false, tb);
        CHECK(s.frames.size() == 1, "stream reassembles to 1 frame");
        if (s.frames.size() == 1) {
            qp::Question q = qp::parse_question(s.frames[0].second.data(), s.frames[0].second.size());
            CHECK(q.parse_ok && q.qno == 16, "streamed question qno == 16");
        }
    }
    // ---- 3) 单段双消息（58B 段 = 0x46FF + 0x40E5）----
    {
        printf("[3] two-frames-in-one-segment\n");
        SimSock s;
        auto pkt = hex2b(pk_sys2);
        s.feed(pkt.data(), pkt.size(), false, tb);
        CHECK(s.frames.size() == 2, "58B segment -> 2 frames");
        if (s.frames.size() == 2) {
            CHECK(s.frames[0].first == 0x46FF, "frame0 op 0x46FF");
            CHECK(s.frames[1].first == 0x40E5, "frame1 op 0x40E5");
            std::string gbk;
            CHECK(qp::parse_sysprompt(s.frames[0].second.data(), s.frames[0].second.size(), gbk),
                  "sysprompt parse");
            CHECK(hexs((const uint8_t*)gbk.data(), gbk.size()) ==
                  "bbf1b5c3c1cb23303046463030233130302346464636393223bdf0b1d2",
                  "reward text GBK bytes exact (金币奖励)");
            // 0x40E5: 明文实测 3d140300 c8000000 00000000
            // （交接包文档写 201021 是笔误：0x0003143D 实为 201789）
            auto& f1 = s.frames[1].second;
            CHECK(hexs(f1.data(), f1.size()) == "3d140300c800000000000000",
                  "0x40E5 payload bytes exact");
        }
    }
    // ---- 4) 测试通过！ sysprompt ----
    {
        printf("[4] '测试通过' sysprompt\n");
        SimSock s;
        auto pkt = hex2b(pk_sys1);
        s.feed(pkt.data(), pkt.size(), false, tb);
        CHECK(s.frames.size() == 1 && s.frames[0].first == 0x46FF, "23B -> 0x46FF");
        std::string gbk;
        CHECK(qp::parse_sysprompt(s.frames[0].second.data(), s.frames[0].second.size(), gbk) &&
              hexs((const uint8_t*)gbk.data(), gbk.size()) == "b2e2cad4cda8b9fda3a1",
              "text == 测试通过！");
    }
    // ---- 5) 答案构包逐字节（两条实抓基准）----
    {
        printf("[5] build_answer byte-exact\n");
        auto w1 = qp::build_answer(tb, 13, 0);
        CHECK(hexs(w1.data(), w1.size()) == pk_ans_wrong, "qno13 opt0 == captured wire");
        auto w2 = qp::build_answer(tb, 16, 2);
        CHECK(hexs(w2.data(), w2.size()) == pk_ans_right, "qno16 opt2 == captured wire");
    }
    // ---- 6) C->S 答案帧解码回环（DLL 的 encode 逆校验路径）----
    {
        printf("[6] answer frame decode roundtrip\n");
        SimSock s;
        auto pkt = hex2b(pk_ans_right);
        s.feed(pkt.data(), pkt.size(), true, tb);
        CHECK(s.frames.size() == 1 && s.frames[0].first == 0x1F04, "13B -> 0x1F04");
        auto& p = s.frames[0].second;
        CHECK(p.size() == 9, "body 9B");
        uint32_t five = 0, qno = 0;
        memcpy(&five, p.data(), 4); memcpy(&qno, p.data() + 4, 4);
        CHECK(five == 5 && qno == 16 && p[8] == 2, "payload [5][16][2]");
    }
    // ---- 7) 心跳包不受影响 ----
    {
        printf("[7] heartbeat frame\n");
        SimSock s;
        auto pkt = hex2b(pk_s2c_f005);
        s.feed(pkt.data(), pkt.size(), false, tb);
        CHECK(s.frames.size() == 1 && s.frames[0].first == 0xF005, "28B -> 0xF005");
    }
    // ---- 8) 半包后接续（模拟 TCP 拆包）----
    {
        printf("[8] split-across-feeds\n");
        SimSock s;
        auto pkt = hex2b(pk_question);
        s.feed(pkt.data(), 50, false, tb);
        CHECK(s.frames.empty(), "half packet yields no frame");
        s.feed(pkt.data() + 50, pkt.size() - 50, false, tb);
        CHECK(s.frames.size() == 1, "continuation completes frame");
    }

    // ---- 9) 流过滤：题目帧扣住/放行/销毁（题目屏蔽功能）----
    {
        printf("[9] stream filter (question shielding)\n");
        // 模拟 DLL 回调：0x46F4 扣住并提取 qno，其余帧放行
        auto hold_fn = [&tb](uint16_t op, uint16_t inv, const uint8_t* body,
                             size_t blen, uint32_t* qno) -> bool {
            if (op != 0x46F4) return false;
            std::vector<uint8_t> plain(blen);
            qp::decode_s2c(tb, op, inv, body, blen, plain.data());
            qp::Question q = qp::parse_question(plain.data(), blen);
            *qno = q.qno;
            return true;
        };

        auto qpkt = hex2b(pk_question);
        auto spkt = hex2b(pk_sys1);

        // 9.1 题目帧单独到达：被扣住，游戏拿不到任何字节
        {
            qp::StreamFilter f;
            bool bad = false;
            f.feed(qpkt.data(), qpkt.size(), hold_fn, bad);
            char tmp[512];
            CHECK(!bad && f.held.size() == 1 && f.held[0].qno == 16,
                  "question held with qno=16");
            CHECK(f.deliver(tmp, sizeof tmp) == 0, "nothing delivered while held");
        }
        // 9.2 提示帧与题目帧同块到达：提示照常交付，题目扣住
        {
            qp::StreamFilter f;
            bool bad = false;
            std::vector<uint8_t> chunk = spkt;
            chunk.insert(chunk.end(), qpkt.begin(), qpkt.end());
            f.feed(chunk.data(), chunk.size(), hold_fn, bad);
            char tmp[512];
            int n = f.deliver(tmp, sizeof tmp);
            CHECK(!bad && n == (int)spkt.size(), "sysprompt delivered, question held");
            CHECK(memcmp(tmp, spkt.data(), spkt.size()) == 0, "delivered bytes intact");
        }
        // 9.3 题目帧跨块拆分：第一块无可交付、无扣住；第二块补全后扣住
        {
            qp::StreamFilter f;
            bool bad = false;
            char tmp[512];
            f.feed(qpkt.data(), 50, hold_fn, bad);
            CHECK(!bad && f.held.empty() && f.deliver(tmp, sizeof tmp) == 0,
                  "split first half: no hold, no deliver");
            f.feed(qpkt.data() + 50, qpkt.size() - 50, hold_fn, bad);
            CHECK(f.held.size() == 1 && f.deliver(tmp, sizeof tmp) == 0,
                  "split second half: held");
        }
        // 9.4 答出销毁：consume 后即使超时也不放行
        {
            qp::StreamFilter f;
            bool bad = false;
            f.feed(qpkt.data(), qpkt.size(), hold_fn, bad);
            CHECK(f.consume(16), "consume(qno=16) hits");
            CHECK(!f.consume(16), "double consume returns false");
            f.tick(20000);
            char tmp[512];
            CHECK(f.deliver(tmp, sizeof tmp) == 0, "consumed frame never released");
        }
        // 9.5 超时放行：扣住帧按原字节序列化回交付流
        {
            qp::StreamFilter f;
            bool bad = false;
            f.feed(qpkt.data(), qpkt.size(), hold_fn, bad);
            f.tick(f.hold_ms - 1);
            char tmp[512];
            CHECK(f.deliver(tmp, sizeof tmp) == 0, "just before timeout: still held");
            f.tick(2);
            int n = f.deliver(tmp, sizeof tmp);
            CHECK(n == (int)qpkt.size() && memcmp(tmp, qpkt.data(), qpkt.size()) == 0,
                  "timeout release: original wire bytes intact");
        }
        // 9.6 小容量交付：分多次取完且不丢不乱
        {
            qp::StreamFilter f;
            bool bad = false;
            std::vector<uint8_t> chunk = spkt;
            chunk.insert(chunk.end(), qpkt.begin(), qpkt.end());
            f.feed(chunk.data(), chunk.size(), hold_fn, bad);
            f.tick(20000);   // 题目超时放行 → 交付队列 = sys + question
            std::vector<uint8_t> got;
            char tmp[64];
            int n;
            while ((n = f.deliver(tmp, sizeof tmp)) > 0)
                got.insert(got.end(), tmp, tmp + n);
            CHECK(got.size() == spkt.size() + qpkt.size(), "chunked deliver total size");
            CHECK(memcmp(got.data(), spkt.data(), spkt.size()) == 0 &&
                  memcmp(got.data() + spkt.size(), qpkt.data(), qpkt.size()) == 0,
                  "chunked deliver byte order intact");
        }
        // 9.7 消费错题号：不误删，超时仍放行
        {
            qp::StreamFilter f;
            bool bad = false;
            f.feed(qpkt.data(), qpkt.size(), hold_fn, bad);
            CHECK(!f.consume(999), "consume wrong qno returns false");
            f.tick(20000);
            char tmp[512];
            CHECK(f.deliver(tmp, sizeof tmp) == (int)qpkt.size(),
                  "wrong consume: frame released at timeout");
        }
    }

    printf("\n%s (%d failures)\n", fails == 0 ? "ALL TESTS PASSED" : "TESTS FAILED", fails);
    return fails == 0 ? 0 : 1;
}
