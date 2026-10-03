// quizbot LLM 边车服务
// 暴露 OpenAI 风格 HTTP 接口给 Python 控制器，内部用 WorkBuddy 云服务 SDK 免密钥调大模型。
// 只监听 127.0.0.1 —— 仅供本机使用。
const http = require('http');
const { createWorkBuddyCloud } = require('@tencent-ai/workbuddy-cloud-sdk');

const PORT = 8765;
// publicConfig（WorkBuddy 云服务生命周期返回；publishableKey 仅标识应用，无独立权限）
const ENDPOINT = 'https://quizbot.app.workbuddy.host';
const PUBLISHABLE_KEY = 'wbpk_bKLfhWMXdEKLARyLuBcSKw_T1TMG255h3Nzyg8HsvX2JI8VHsbS3CMn';

const cloud = createWorkBuddyCloud({ endpoint: ENDPOINT, publishableKey: PUBLISHABLE_KEY });

let MODEL_ID = null;
let MODEL_NAME = null;

async function pickModel() {
  const models = await cloud.llm.models.list();
  if (!models || models.length === 0) throw new Error('模型列表为空');
  const ok = models.filter(m => m.disabled !== true && m.enabled !== false);
  if (!ok.length) throw new Error('无可用模型');
  // 优先挑响应快的：名字含 flash/mini/turbo/h Lightning 的排前，否则取第一个
  const fast = ok.find(m => /flash|mini|turbo|light|8b|instant/i.test(m.id || '') || /flash|mini|turbo|light/i.test(m.name || ''));
  const pick = fast || ok[0];
  MODEL_ID = pick.id;
  MODEL_NAME = pick.name || pick.id;
  console.log(`[sidecar] 使用模型: ${MODEL_NAME} (${MODEL_ID}), 可选模型 ${ok.length} 个`);
}

const SYSTEM_PROMPT = '你是游戏答题助手，只输出正确选项的序号数字（1 到 N 之一），不要任何解释、标点或其他文字。';

async function callLLM(messages, maxTokens) {
  const msgs = (messages && messages.length && messages[0].role === 'system')
    ? messages
    : [{ role: 'system', content: SYSTEM_PROMPT }, ...(messages || [])];
  let content = '';
  const stream = await cloud.llm.chat.completions.create({
    model: MODEL_ID,
    messages: msgs,
    stream: true,
    temperature: 0,
    max_tokens: Math.max(8, Math.min(maxTokens || 8, 128)),
  });
  for await (const chunk of stream) {
    const d = chunk.choices && chunk.choices[0] && chunk.choices[0].delta;
    if (d && d.content) content += d.content;
  }
  return content;
}

const server = http.createServer(async (req, res) => {
  // 只允许本机
  const addr = req.socket.remoteAddress || '';
  if (!/^127\.0\.0\.1$|^::1$|^::ffff:127\.0\.0\.1$/.test(addr)) {
    res.writeHead(403); res.end('forbidden'); return;
  }
  if (req.method === 'GET' && req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: true, model: MODEL_NAME, model_id: MODEL_ID }));
    return;
  }
  if (req.method === 'POST' && req.url === '/v1/chat/completions') {
    let raw = '';
    req.on('data', c => { raw += c; if (raw.length > 65536) req.destroy(); });
    req.on('end', async () => {
      let body;
      try { body = JSON.parse(raw); } catch { res.writeHead(400); res.end('bad json'); return; }
      try {
        const text = await callLLM(body.messages, body.max_tokens);
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
          id: 'sidecar', object: 'chat.completion',
          choices: [{ index: 0, message: { role: 'assistant', content: text }, finish_reason: 'stop' }],
        }));
      } catch (ex) {
        const info = (ex && ex.error && ex.error.code) ? `${ex.error.code}: ${ex.error.message}` : String(ex);
        console.error('[sidecar] LLM 错误:', info);
        res.writeHead(502, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: { message: info } }));
      }
    });
    return;
  }
  res.writeHead(404); res.end('not found');
});

pickModel().then(() => {
  server.listen(PORT, '127.0.0.1', () => console.log(`[sidecar] listening on 127.0.0.1:${PORT}`));
}).catch(ex => {
  console.error('[sidecar] 模型列表获取失败:', ex && ex.error ? ex.error.code + ': ' + ex.error.message : String(ex));
  process.exit(1);
});
