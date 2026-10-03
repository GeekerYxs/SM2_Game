# -*- coding: utf-8 -*-
"""大冒险2 传输层协议库（便携版）——答题 hook 的核心编解码逻辑。

全部结论已实测验证（见 ../docs/答题协议完全定论与自动化hook方案.md）：
- 帧：[inv:u16 LE][op:u16 LE][混淆正文 length 字节]，length = (~inv)&0xFFFF，帧头明文
- 起始表号 index = ((op << 8) ^ inv) % 10；正文第 i 字节过 表[(index+i)%10]
- 服务端→客户端用 decode 表组（wire→plain）
- 客户端→服务端用 encode 表组（plain→wire；解码方向用逆表）
- 表来源：客户端进程内存 模块基址+0x515D6C(encode)/+0x515D94(decode)，各 10 指针×256B
"""
import json
import struct
from pathlib import Path

CODEC_PATH = Path(__file__).resolve().parent.parent / "codec" / "codec_tables.json"

OP_QUESTION = 0x46F4   # 服务端→客户端 题目下发
OP_ANSWER = 0x1F04     # 客户端→服务端 答案上行（13B）
OP_SYSPROMPT = 0x46FF  # 服务端→客户端 系统提示（测试通过！/金币奖励）
OP_0x40E5 = 0x40E5     # 服务端→客户端 疑似货币余额更新


class Codec:
    def __init__(self, codec_path=CODEC_PATH):
        d = json.loads(Path(codec_path).read_text(encoding="utf-8"))
        self.encode = [bytes.fromhex(t) for t in d["encode"]]
        self.decode = [bytes.fromhex(t) for t in d["decode"]]
        self.encode_inv = []
        for t in self.encode:
            if len(t) != 256 or len(set(t)) != 256:
                raise ValueError("encode 表非 256 项双射，客户端版本可能不同")
            inv = bytearray(256)
            for i, v in enumerate(t):
                inv[v] = i
            self.encode_inv.append(bytes(inv))
        for t in self.decode:
            if len(t) != 256 or len(set(t)) != 256:
                raise ValueError("decode 表非 256 项双射")

    @staticmethod
    def frame_index(op: int, inv: int) -> int:
        return ((op << 8) ^ inv) % 10

    def decode_body(self, op: int, inv: int, wire_body: bytes, from_client: bool) -> bytes:
        tables = self.encode_inv if from_client else self.decode
        idx = self.frame_index(op, inv)
        return bytes(tables[(idx + i) % 10][b] for i, b in enumerate(wire_body))

    def encode_body(self, op: int, inv: int, plain_body: bytes, from_client: bool = True) -> bytes:
        tables = self.encode if from_client else self.decode
        idx = self.frame_index(op, inv)
        return bytes(tables[(idx + i) % 10][b] for i, b in enumerate(plain_body))

    # ---- 分帧：把一个方向的 TCP 字节流增量切出完整消息 ----
    # hook recv 时会拿到任意切分的块，必须按流式缓冲；返回 (消息列表, 剩余缓冲)
    @staticmethod
    def parse_stream(buf: bytes):
        msgs = []
        off = 0
        while off + 4 <= len(buf):
            inv, op = struct.unpack_from("<HH", buf, off)
            length = (~inv) & 0xFFFF
            if length > 0x1BFC:          # 超长帧说明流错位/错表，上层应告警
                return msgs, buf[off:], "bad_length"
            if off + 4 + length > len(buf):
                break                     # 半包，等下次数据
            body = buf[off + 4:off + 4 + length]
            msgs.append((op, inv, body))
            off += 4 + length
        return msgs, buf[off:], None


def parse_question(body: bytes) -> dict:
    """解析 0x46F4 题目明文正文（92B 实测结构封闭零剩余）"""
    q = {
        "field_a": struct.unpack_from("<I", body, 0)[0],   # 88/89，语义未定
        "flag": body[4],                                    # 01
        "question_no": struct.unpack_from("<I", body, 5)[0],
    }
    slen = body[9]
    q["stem"] = body[10:10 + slen].decode("gbk")
    pos = 10 + slen
    n = body[pos]; pos += 1
    q["options"] = []
    for _ in range(n):
        ln = body[pos]; pos += 1
        q["options"].append(body[pos:pos + ln].decode("gbk"))
        pos += ln
    q["tail"] = body[pos:].hex()   # 正常应为空
    return q


def build_answer(codec: Codec, question_no: int, option_index: int) -> bytes:
    """构造 0x1F04 答案包（13B 完整线上字节）。

    明文正文 [5:i32][题号:i32][选项:u8]，选项 0-based（"N、" 的 N-1）。
    已用两条实抓包逐字节验证：题号13/选项0、题号16/选项2。
    """
    plain = struct.pack("<IIB", 5, question_no, option_index)
    inv = (~len(plain)) & 0xFFFF          # = 0xFFF6
    op = OP_ANSWER
    wire_body = codec.encode_body(op, inv, plain, from_client=True)
    return struct.pack("<HH", inv, op) + wire_body


if __name__ == "__main__":
    # 自检：用已知实抓样本端到端验证
    c = Codec()
    tests = [
        (13, 0, "f6ff041fce1f805bc6510bdcfa"),   # 实抓：答错Q1（选项1"正能量"）
        (16, 2, "f6ff041fce1f805bb0510bdce8"),   # 实抓：答对Q2（选项3"麋鹿"）
    ]
    ok = all(build_answer(c, q, o).hex() == expect for q, o, expect in tests)
    print("build_answer 自检:", "PASS" if ok else "FAIL")
    # 解码自检
    wire = bytes.fromhex("a3fff4467e805b6458c0dcfaa3d2b97a4f222900e19d6c8d9755846cee695a3b806695ebdb01c5792836d4b97f02bd4e306ab694f919ce12dc89058f0f46f950e483c0e0058f0374a179d04ddbdb83949f6259f7316bdca6058f6e59adc18682")
    inv, op = struct.unpack_from("<HH", wire, 0)
    body = c.decode_body(op, inv, wire[4:], from_client=False)
    q = parse_question(body)
    assert q["stem"] == '人们在动物园里看到的俗称"四不象"的动物是?'
    assert q["options"] == ["1、驯兽师", "2、猩猩队长", "3、麋鹿", "4、霸天虎"]
    assert q["tail"] == ""
    print("decode 96B 题目包自检: PASS  题号", q["question_no"])
