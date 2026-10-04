import * as admin from 'firebase-admin';
// 1st-gen API (deployable on the no-card Spark plan; 2nd-gen needs Blaze).
import * as functions from 'firebase-functions/v1';
import {
  inviteAddedEmail,
  invitePendingEmail,
  memberJoinedEmail,
  sessionStatusEmail,
  todoAssignedEmail,
  welcomeEmail,
} from './emails';
import { enqueueMail } from './queue';
import { presignPut, r2Configured, sanitizeFilename } from './r2';

admin.initializeApp();
const db = admin.firestore();

/**
 * Spark-safe (no-card) backend:
 * - 1st-gen triggers + callables (2nd-gen needs Blaze).
 * - No Secret Manager: R2 keys come from a local `functions/.env`
 *   file at deploy time (gitignored, emulator-compatible).
 * - No SMTP here (Spark blocks external SMTP): mail is queued in
 *   `mailQueue` and sent by the GitHub Action (tools/mailer) via
 *   Gmail + app password.
 */

const emailHash = (email: string) =>
  Buffer.from(email.trim().toLowerCase()).toString('base64url');

async function userEmail(uid: string): Promise<string> {
  const snap = await db.doc(`users/${uid}`).get();
  return String(snap.data()?.emailLower ?? '').toLowerCase();
}

async function userDisplayName(uid: string): Promise<string> {
  const snap = await db.doc(`users/${uid}`).get();
  const d = snap.data() as any;
  return String(d?.displayName ?? d?.emailLower ?? 'A family member');
}

async function familyNameOf(familyId: string): Promise<string> {
  const snap = await db.doc(`families/${familyId}`).get();
  return String((snap.data() as any)?.name ?? 'Your family') || 'Your family';
}

/**
 * Keeps usersByEmail/{hash} in sync for the "check existing user" flow
 * and queues the welcome / confirmation email.
 */
export const onUserCreate = functions.firestore
  .document('users/{uid}')
  .onCreate(async (snap) => {
    const data = snap.data() as any;
    const email = String(data.emailLower ?? '').toLowerCase();
    if (!email) return;
    await db.doc(`usersByEmail/${emailHash(email)}`).set(
      {
        uid: snap.id,
        emailLower: email,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    await enqueueMail(db, email, welcomeEmail(String(data.displayName ?? '')));
  });

/**
 * Invite a family member by email. Existing users join instantly, new
 * emails get a pending invite record. Both paths queue a Gmail.
 * Returns { addedUid, invited } for the client.
 *
 * data: { familyId, email, role, assignedChildIds? } — owner/parent only.
 */
export const inviteMember = functions.https.onCall(async (data, context) => {
  const callerUid = context.auth?.uid;
  if (!callerUid) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
  }
  const { familyId, email, role, assignedChildIds } = data as {
    familyId: string;
    email: string;
    role: 'parent' | 'child' | 'teacher';
    assignedChildIds?: string[];
  };
  if (!familyId || !email || !role) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'familyId, email, role required.',
    );
  }
  const famSnap = await db.doc(`families/${familyId}`).get();
  if (!famSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Family not found.');
  }
  const memberDoc = await db
    .doc(`families/${familyId}/members/${callerUid}`)
    .get();
  const callerRole = memberDoc.data()?.role;
  if (callerRole !== 'owner' && callerRole !== 'parent') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only owner/parent can invite.',
    );
  }
  const familyName = await familyNameOf(familyId);
  const ownerUid = String((famSnap.data() as any)?.ownerUid ?? '');
  const inviterName = await userDisplayName(callerUid);

  const emailLower = email.trim().toLowerCase();
  const existing = await db.doc(`usersByEmail/${emailHash(emailLower)}`).get();
  const payload: any = {
    role,
    invitedEmail: emailLower,
    status: existing.exists ? 'active' : 'invited',
    joinedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (role === 'teacher') {
    payload.assignedChildIds = assignedChildIds ?? [];
  }
  if (existing.exists) {
    const uid = (existing.data() as any).uid as string;
    await db.doc(`families/${familyId}/members/${uid}`).set(payload, {
      merge: true,
    });
    await db.doc(`users/${uid}`).set(
      { familyIds: admin.firestore.FieldValue.arrayUnion([familyId]) },
      { merge: true },
    );
    await enqueueMail(
      db,
      emailLower,
      inviteAddedEmail({ familyName, inviterName, role }),
    );
    if (ownerUid && ownerUid !== callerUid) {
      const ownerEmail = await userEmail(ownerUid);
      if (ownerEmail) {
        await enqueueMail(
          db,
          ownerEmail,
          memberJoinedEmail({ familyName, memberEmail: emailLower }),
        );
      }
    }
    return { addedUid: uid, invited: false };
  }
  await db
    .doc(`families/${familyId}/invites/${emailHash(emailLower)}`)
    .set({ ...payload, claimed: false });
  await enqueueMail(
    db,
    emailLower,
    invitePendingEmail({ familyName, inviterName, role }),
  );
  return { addedUid: null, invited: true };
});

/**
 * Queues a notification email when a todo is created with assignees.
 */
export const onTodoAssigned = functions.firestore
  .document('families/{fid}/todos/{todoId}')
  .onCreate(async (snap, context) => {
    const data = snap.data() as any;
    const assignees: string[] = data.assigneeUids ?? [];
    if (assignees.length === 0) return;
    const fid = context.params.fid as string;
    const fam = await familyNameOf(fid);
    const assigner = data.createdBy
      ? await userDisplayName(String(data.createdBy))
      : 'A family member';
    let due = '';
    try {
      if (data.dueAt?.toDate) due = (data.dueAt.toDate() as Date).toDateString();
    } catch {
      due = '';
    }
    const mail = todoAssignedEmail({
      title: String(data.title ?? 'Untitled task'),
      due,
      familyName: fam,
      assignerName: assigner,
    });
    for (const uid of assignees) {
      const to = await userEmail(String(uid));
      if (to) await enqueueMail(db, to, mail);
    }
  });

/**
 * Queues a notification email to the teacher when a session is
 * approved or marked paid.
 */
export const onSessionStatus = functions.firestore
  .document('families/{fid}/teachers/{tid}/sessions/{sid}')
  .onUpdate(async (change, context) => {
    const before = change.before.data() as any;
    const after = change.after.data() as any;
    if (!before || !after || before.status === after.status) return;
    if (after.status !== 'approved' && after.status !== 'paid') return;
    const fid = context.params.fid as string;
    const tid = context.params.tid as string;
    const teacherEmail = await userEmail(tid);
    if (!teacherEmail) return;
    const fam = await familyNameOf(fid);
    let child = 'your student';
    if (after.childId) {
      const csnap = await db
        .doc(`families/${fid}/children/${after.childId}`)
        .get();
      if (csnap.exists) child = String((csnap.data() as any)?.name ?? child);
    }
    await enqueueMail(
      db,
      teacherEmail,
      sessionStatusEmail({
        status: after.status,
        childName: child,
        amount: Number(after.amount ?? 0),
        familyName: fam,
      }),
    );
  });

/**
 * R2 direct-upload URL. Presigning is local crypto (no network), so it
 * works on Spark. R2_* keys come from `functions/.env` (gitignored).
 *
 * data: { familyId?, kind, filename, contentType }
 */
export const getUploadUrl = functions.https.onCall(async (data, context) => {
  const callerUid = context.auth?.uid;
  if (!callerUid) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
  }
  if (!r2Configured()) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'File storage is not configured yet.',
    );
  }
  const { familyId, kind, filename, contentType } = data as {
    familyId?: string;
    kind: 'receipts' | 'chat' | 'avatars';
    filename: string;
    contentType: string;
  };
  if (!kind || !filename || !contentType) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'kind, filename, contentType required.',
    );
  }
  let key: string;
  if (kind === 'avatars') {
    key = `avatars/${callerUid}/${Date.now()}_${sanitizeFilename(filename)}`;
  } else {
    if (!familyId || (kind !== 'receipts' && kind !== 'chat')) {
      throw new functions.https.HttpsError('invalid-argument', 'familyId required.');
    }
    const member = await db
      .doc(`families/${familyId}/members/${callerUid}`)
      .get();
    if (!member.exists) {
      throw new functions.https.HttpsError('permission-denied', 'Not a family member.');
    }
    key = `families/${familyId}/${kind}/${callerUid}_${Date.now()}_${sanitizeFilename(filename)}`;
  }
  try {
    return await presignPut(key, contentType);
  } catch (err: any) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      err?.message ?? 'Upload rejected.',
    );
  }
});
