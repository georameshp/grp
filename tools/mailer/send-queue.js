/**
 * GRP mail queue sender — runs in GitHub Actions (also runnable locally).
 *
 * Polls Firestore `mailQueue` for pending mails and sends them through
 * Gmail SMTP using an app password. Env vars:
 *   FIREBASE_SERVICE_ACCOUNT  service-account JSON (Firebase console >
 *                             Project settings > Service accounts)
 *   GMAIL_USER                Gmail address (sender)
 *   GMAIL_APP_PASSWORD        16-char app password (Google Account >
 *                             Security > 2-Step Verification > App passwords)
 *   MAIL_LIMIT                max mails per run (default 20)
 *   DRY_RUN=1                 log without sending or updating
 */
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

const LIMIT = Math.min(Number(process.env.MAIL_LIMIT ?? 20) || 20, 100);
const DRY_RUN = process.env.DRY_RUN === '1';

function required(name) {
  const v = (process.env[name] ?? '').trim();
  if (!v) {
    console.error(`Missing env var: ${name}`);
    process.exit(1);
  }
  return v;
}

async function main() {
  const sa = JSON.parse(required('FIREBASE_SERVICE_ACCOUNT'));
  const user = required('GMAIL_USER');
  const pass = required('GMAIL_APP_PASSWORD');

  admin.initializeApp({ credential: admin.credential.cert(sa) });
  const db = admin.firestore();

  const tx = nodemailer.createTransport({
    host: 'smtp.gmail.com',
    port: 465,
    secure: true,
    auth: { user, pass },
  });
  if (!DRY_RUN) {
    await tx.verify();
    console.log('SMTP connection verified.');
  }

  const snap = await db
    .collection('mailQueue')
    .where('status', '==', 'pending')
    .orderBy('createdAt')
    .limit(LIMIT)
    .get();
  console.log(`Pending mails: ${snap.size}`);
  let sent = 0;
  let failed = 0;

  for (const doc of snap.docs) {
    const m = doc.data();
    if (!m.to || !m.to.includes('@') || !m.subject || !m.html) {
      await doc.ref.update({
        status: 'failed',
        error: 'Invalid mail document.',
      });
      failed++;
      continue;
    }
    if (DRY_RUN) {
      console.log(`[dry-run] would send to ${m.to}: ${m.subject}`);
      sent++;
      continue;
    }
    try {
      await tx.sendMail({
        from: `"GRP" <${user}>`,
        to: m.to,
        subject: m.subject,
        text: m.text ?? '',
        html: m.html,
      });
      await doc.ref.update({
        status: 'sent',
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`Sent to ${m.to}: ${m.subject}`);
      sent++;
    } catch (err) {
      const attempts = Number(m.attempts ?? 0) + 1;
      await doc.ref.update({
        attempts,
        status: attempts >= 5 ? 'failed' : 'pending',
        error: String((err && err.message) || err).slice(0, 500),
      });
      console.error(`Failed to ${m.to}: ${err && err.message}`);
      failed++;
    }
  }
  console.log(`Done. sent=${sent} failed=${failed}`);
}

main().catch((err) => {
  console.error('Mailer crashed:', err);
  process.exit(1);
});
