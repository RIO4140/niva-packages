// خادم محاكٍ لواجهة جيت هاب — لاختبارات حزم انشر فقط.
// بلا شبكة حقيقية: يخدم تدفق الجهاز + git-data API على
// 127.0.0.1:39401، ويحفظ حالة كل تدفق جهاز على حدة،
// ويسجّل كل طلب ليُفحص من الاختبارات.
// (ملف بنية تحتية — أسماء المسارات والحقول لاتينية كما في
// واجهة جيت هاب نفسها؛ والرسائل النصية عربية.)
const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 39401;
const TOKEN = 'gho_mock_token_123';
const COMMIT_SHA = '1234567890abcdef1234567890abcdef12345678';
const BASE_SHA = 'fedcba9876543210fedcba9876543210fedcba98';
const INDEX_INITIAL = '# فهرس محاكي — حزمتان للاختبار (واحدة مسحوبة)\n'
  + 'حزمة_وسط 1.0.0 github.com/اختبار/حزمة_وسط v1.0.0 456789abcdef0123456789abcdef0123456789ab مختبر 2026-11-01T00:00:00Z 3e84e62d7e31250193de559710ff74fa86ab366865217a620fa05cf64b70f48f 277 حزمة_صغيرة:^1.0 حزمة وسط للاختبار\n'
  + 'حزمة_قديمة 0.9.0 github.com/اختبار/حزمة_قديمة v0.9.0 6789abcdef0123456789abcdef0123456789abcd مختبر 2026-10-01T00:00:00Z 6789abcdef0123456789abcdef0123456789abcdef0123456789abcdef012345 162 - حزمة قديمة سُحبت كل إصداراتها\n'
  + 'سحب حزمة_قديمة 0.9.0 سُحبت نهائيا\n';

let manifestText = '';
try {
  manifestText = fs.readFileSync(
    path.join(__dirname, 'fixtures', 'حزمة_صغيرة', 'بيان.حزمة'), 'utf8');
} catch (e) {
  manifestText = 'اسم: حزمة_صغيرة\nإصدار: 1.0.0\nوصف: حزمة صغيرة للاختبار\nدخول: حزمة_صغيرة.نيفا\n';
}

let state;
function resetState() {
  state = {
    nextDevice: 1,
    devices: {},
    forked: {},
    prCounter: 41,
    requests: [],
    lastBlob: '',
  };
}
resetState();

function sendJson(res, status, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(body);
}

function sendText(res, status, text) {
  res.writeHead(status, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end(text);
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://127.0.0.1');
  // المحرك يرمّز المسار العربي (فهرس.حزمة) بالنسبة المئوية
  // قبل الإرسال — فيُفك الترميز هنا قبل المطابقة والسجل.
  let pathname = url.pathname;
  try { pathname = decodeURIComponent(pathname); } catch (e) { pathname = url.pathname; }
  state.requests.push(req.method + ' ' + pathname);
  let rawBody = '';
  req.on('data', (chunk) => { rawBody += chunk; });
  req.on('end', () => {
    // نقاط فحص المحاكي نفسه (ليست جزءا من واجهة جيت هاب)
    if (req.method === 'GET' && pathname === '/__صحة') return sendText(res, 200, 'بخير');
    if (req.method === 'GET' && pathname === '/__إعادة') { resetState(); return sendText(res, 200, 'أعيد'); }
    if (req.method === 'GET' && pathname === '/__طلبات') return sendText(res, 200, state.requests.join('\n'));
    if (req.method === 'GET' && pathname === '/__آخر_بلوب') return sendJson(res, 200, { content: state.lastBlob });

    // تدفق الجهاز: إصدار رمز
    if (req.method === 'POST' && pathname === '/login/device/code') {
      const scenario = url.searchParams.get('سيناريو') || 'نجاح';
      const code = 'dev-' + state.nextDevice;
      state.nextDevice += 1;
      state.devices[code] = { scenario: scenario, polls: 0 };
      const expires = scenario === 'تعليق' ? 3 : 900;
      const interval = scenario === 'تعليق' ? 1 : 0;
      return sendJson(res, 200, {
        device_code: code,
        user_code: 'WXYZ-ABCD',
        verification_uri: 'http://127.0.0.1:' + PORT + '/activate',
        expires_in: expires,
        interval: interval,
      });
    }

    // تدفق الجهاز: الاستطلاع
    if (req.method === 'POST' && pathname === '/login/oauth/access_token') {
      const form = new URLSearchParams(rawBody);
      const code = form.get('device_code') || '';
      const dev = state.devices[code];
      if (!dev) return sendJson(res, 200, { error: 'incorrect_device_code' });
      dev.polls += 1;
      if (dev.scenario === 'رفض') return sendJson(res, 200, { error: 'access_denied' });
      if (dev.scenario === 'انتهاء') return sendJson(res, 200, { error: 'expired_token' });
      if (dev.scenario === 'تعليق') return sendJson(res, 200, { error: 'authorization_pending' });
      if (dev.scenario === 'بطء') {
        if (dev.polls <= 1) return sendJson(res, 200, { error: 'slow_down' });
        return sendJson(res, 200, { access_token: TOKEN, token_type: 'bearer', scope: 'public_repo' });
      }
      // نجاح: تعليق مرة ثم الرمز
      if (dev.polls <= 1) return sendJson(res, 200, { error: 'authorization_pending' });
      return sendJson(res, 200, { access_token: TOKEN, token_type: 'bearer', scope: 'public_repo' });
    }

    // تفرع مستودع الفهرس
    if (req.method === 'POST' && pathname === '/repos/RIO4140/niva-index/forks') {
      state.forked['tester'] = true;
      return sendJson(res, 201, { full_name: 'tester/niva-index', owner: { login: 'tester' } });
    }

    // فحص وجود مستودع (للتفرع): 200 إن مُتفرَّع، وإلا 404
    let m = pathname.match(/^\/repos\/([^/]+)\/niva-index$/);
    if (req.method === 'GET' && m) {
      if (state.forked[m[1]]) return sendJson(res, 200, { full_name: m[1] + '/niva-index' });
      return sendJson(res, 404, { message: 'Not Found' });
    }

    // مرجع أساس الفهرس
    m = pathname.match(/^\/repos\/([^/]+)\/niva-index\/git\/ref\/heads\/main$/);
    if (req.method === 'GET' && m) {
      return sendJson(res, 200, { ref: 'refs/heads/main', object: { sha: BASE_SHA, type: 'commit', url: 'http://127.0.0.1:' + PORT + '/x' } });
    }

    // فهرس.حزمة الخام (مركزي أو هدف)
    m = pathname.match(/^\/([^/]+)\/niva-index\/main\/فهرس\.حزمة$/);
    if (req.method === 'GET' && m) return sendText(res, 200, INDEX_INITIAL);

    // بيان.حزمة عند وسم (أي مستودع/وسم — المحاكي يرد بالملف نفسه)
    m = pathname.match(/^\/([^/]+)\/([^/]+)\/([^/]+)\/بيان\.حزمة$/);
    if (req.method === 'GET' && m) return sendText(res, 200, manifestText);

    // التزام الوسم
    m = pathname.match(/^\/repos\/([^/]+)\/([^/]+)\/commits\/([^/]+)$/);
    if (req.method === 'GET' && m) {
      return sendJson(res, 200, { sha: COMMIT_SHA, commit: { message: 'وسم' } });
    }

    // git-data: كائن
    m = pathname.match(/^\/repos\/([^/]+)\/niva-index\/git\/blobs$/);
    if (req.method === 'POST' && m) {
      try {
        const body = JSON.parse(rawBody || '{}');
        state.lastBlob = body.content || '';
      } catch (e) { state.lastBlob = ''; }
      return sendJson(res, 201, { sha: 'b'.repeat(40) });
    }

    // git-data: شجرة
    m = pathname.match(/^\/repos\/([^/]+)\/niva-index\/git\/trees$/);
    if (req.method === 'POST' && m) return sendJson(res, 201, { sha: 'c'.repeat(40) });

    // git-data: التزام
    m = pathname.match(/^\/repos\/([^/]+)\/niva-index\/git\/commits$/);
    if (req.method === 'POST' && m) return sendJson(res, 201, { sha: 'd'.repeat(40) });

    // git-data: مرجع
    m = pathname.match(/^\/repos\/([^/]+)\/niva-index\/git\/refs$/);
    if (req.method === 'POST' && m) {
      let refName = '';
      try { refName = JSON.parse(rawBody || '{}').ref || ''; } catch (e) { refName = ''; }
      return sendJson(res, 201, { ref: refName, object: { sha: 'd'.repeat(40) } });
    }

    // طلب دمج
    if (req.method === 'POST' && pathname === '/repos/RIO4140/niva-index/pulls') {
      state.prCounter += 1;
      return sendJson(res, 201, { number: state.prCounter, html_url: 'http://127.0.0.1:' + PORT + '/pull/' + state.prCounter });
    }

    return sendJson(res, 404, { message: 'غير موجود في المحاكي: ' + pathname });
  });
});

server.listen(PORT, '127.0.0.1', () => console.log('محاكي جيت هاب على ' + PORT));
