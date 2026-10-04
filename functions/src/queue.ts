import * as admin from 'firebase-admin';
import { Mail } from './emails';

/**
 * Outbox for the GitHub Action mailer (tools/mailer), which sends via
 * Gmail SMTP + app password. Functions only WRITE here (pure Firestore,
 * Spark-safe) — sending happens outside Firebase, so no Blaze plan and
 * no Secret Manager are needed anywhere.
 */
export async function enqueueMail(
  db: admin.firestore.Firestore,
  to: string,
  mail: Mail,
): Promise<void> {
  const addr = (to || '').trim().toLowerCase();
  if (!addr || !addr.includes('@')) return;
  await db.collection('mailQueue').add({
    to: addr,
    subject: mail.subject,
    html: mail.html,
    text: mail.text,
    status: 'pending',
    attempts: 0,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}
