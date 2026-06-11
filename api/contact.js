'use strict';

const RESEND_ENDPOINT = 'https://api.resend.com/emails';
const TO_ADDRESS = 'contact@sui-gen.jp';
const FROM_ADDRESS = 'SUI-GEN Site <noreply@sui-gen.jp>';
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const MAX_LENGTHS = {
  type: 50,
  name: 100,
  org: 200,
  email: 254,
  message: 5000
};

function isFormEncoded(req) {
  const contentType = String((req.headers && req.headers['content-type']) || '');
  return contentType.indexOf('application/x-www-form-urlencoded') !== -1;
}

function parseRawString(raw, formEncoded) {
  if (!raw) {
    return null;
  }
  if (formEncoded) {
    const params = new URLSearchParams(raw);
    const obj = {};
    params.forEach(function (value, key) {
      obj[key] = value;
    });
    return obj;
  }
  try {
    return JSON.parse(raw);
  } catch (err) {
    return null;
  }
}

async function parseBody(req) {
  const formEncoded = isFormEncoded(req);
  if (req.body !== undefined && req.body !== null) {
    if (Buffer.isBuffer(req.body)) {
      return parseRawString(req.body.toString('utf8'), formEncoded);
    }
    if (typeof req.body === 'object') {
      return req.body;
    }
    if (typeof req.body === 'string') {
      return parseRawString(req.body, formEncoded);
    }
  }
  const chunks = [];
  for await (const chunk of req) {
    chunks.push(typeof chunk === 'string' ? Buffer.from(chunk) : chunk);
  }
  if (chunks.length === 0) {
    return null;
  }
  return parseRawString(Buffer.concat(chunks).toString('utf8'), formEncoded);
}

function fieldValue(body, key) {
  const value = body[key];
  return typeof value === 'string' ? value.trim() : '';
}

function validate(fields) {
  if (!fields.name) {
    return 'name_required';
  }
  if (!fields.email) {
    return 'email_required';
  }
  if (!fields.message) {
    return 'message_required';
  }
  if (!EMAIL_PATTERN.test(fields.email)) {
    return 'email_invalid';
  }
  for (const key of Object.keys(MAX_LENGTHS)) {
    if (fields[key] && fields[key].length > MAX_LENGTHS[key]) {
      return key + '_too_long';
    }
  }
  return null;
}

function buildText(fields) {
  return [
    'SUI-GEN 公式サイトのお問い合わせフォームから送信されました。',
    '',
    'お問い合わせ種別: ' + (fields.type || '（未選択）'),
    'お名前: ' + fields.name,
    'ご所属: ' + (fields.org || '（未記入）'),
    'メールアドレス: ' + fields.email,
    '',
    '--- お問い合わせ内容 ---',
    fields.message
  ].join('\n');
}

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).json({ error: 'method_not_allowed' });
  }

  const body = await parseBody(req);
  if (!body || typeof body !== 'object') {
    return res.status(400).json({ error: 'invalid_body' });
  }

  if (fieldValue(body, 'website')) {
    return res.status(200).json({ ok: true });
  }

  const fields = {
    type: fieldValue(body, 'type') || fieldValue(body, 'inquiry-type'),
    name: fieldValue(body, 'name'),
    org: fieldValue(body, 'org'),
    email: fieldValue(body, 'email'),
    message: fieldValue(body, 'message')
  };

  const validationError = validate(fields);
  if (validationError) {
    return res.status(400).json({ error: validationError });
  }

  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey) {
    return res.status(503).json({ error: 'not_configured' });
  }

  try {
    const resendRes = await fetch(RESEND_ENDPOINT, {
      method: 'POST',
      headers: {
        Authorization: 'Bearer ' + apiKey,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        from: FROM_ADDRESS,
        to: [TO_ADDRESS],
        reply_to: fields.email,
        subject: '【お問い合わせ】' + (fields.type || '一般') + ' / ' + fields.name,
        text: buildText(fields)
      })
    });

    if (!resendRes.ok) {
      return res.status(502).json({ error: 'send_failed' });
    }

    return res.status(200).json({ ok: true });
  } catch (err) {
    return res.status(502).json({ error: 'send_failed' });
  }
};
