/** GRP email templates. Rendered by the GitHub Action mailer
 * (tools/mailer) via Gmail SMTP + app password. */

function layout(title: string, body: string): string {
  return `<!doctype html><html><body style="margin:0;padding:0;background:#eef1f8;font-family:Arial,sans-serif;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding:32px 16px;">
<table role="presentation" width="480" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:16px;overflow:hidden;">
<tr><td style="background:#2d5bff;color:#ffffff;padding:24px 28px;">
<div style="font-size:26px;font-weight:bold;">GRP</div>
<div style="opacity:0.85;font-size:13px;">Personal &amp; family manager</div>
</td></tr>
<tr><td style="padding:28px;">
<h2 style="margin:0 0 12px;font-size:20px;color:#17203a;">${title}</h2>
${body}
</td></tr>
<tr><td style="padding:16px 28px 24px;color:#8a90a6;font-size:12px;">
You received this email because of activity on your GRP account.
</td></tr>
</table></td></tr></table></body></html>`;
}

const p = (t: string) =>
  `<p style="margin:0 0 12px;font-size:14px;line-height:1.6;color:#333a4d;">${t}</p>`;

export interface Mail {
  subject: string;
  html: string;
  text: string;
}

export function welcomeEmail(name: string): Mail {
  const safe = name || 'there';
  return {
    subject: 'Welcome to GRP — please confirm your email',
    html: layout(
      `Welcome, ${safe}!`,
      p('Your GRP account is created. Plan daily activities, track income and expenses, and share everything with your family.') +
        p('<b>Next step:</b> open the GRP app and verify your email address using the confirmation link we sent separately, then create your family workspace.'),
    ),
    text: `Welcome to GRP, ${safe}! Your account is created. Open the app, verify your email with the confirmation link, then create your family workspace.`,
  };
}

export function inviteAddedEmail(opts: {
  familyName: string;
  inviterName: string;
  role: string;
}): Mail {
  return {
    subject: `You've been added to "${opts.familyName}" on GRP`,
    html: layout(
      'You are in!',
      p(`${opts.inviterName} added you to the family <b>${opts.familyName}</b> on GRP as <b>${opts.role}</b>.`) +
        p('Open the GRP app and sign in with this email address — the family workspace, shared todos and finance are waiting for you.'),
    ),
    text: `${opts.inviterName} added you to the family "${opts.familyName}" on GRP as ${opts.role}. Sign in to the GRP app with this email to join.`,
  };
}

export function invitePendingEmail(opts: {
  familyName: string;
  inviterName: string;
  role: string;
}): Mail {
  return {
    subject: `Join "${opts.familyName}" on GRP`,
    html: layout(
      'You are invited!',
      p(`${opts.inviterName} invited you to join the family <b>${opts.familyName}</b> on GRP as <b>${opts.role}</b>.`) +
        p('<b>What to do:</b> 1) Install the GRP app and create an account with <b>this exact email address</b>. 2) Ask the inviter to send the invite again — you will then join instantly.'),
    ),
    text: `${opts.inviterName} invited you to join the family "${opts.familyName}" on GRP as ${opts.role}. Create a GRP account with this exact email, then ask the inviter to re-send the invite.`,
  };
}

export function memberJoinedEmail(opts: {
  familyName: string;
  memberEmail: string;
}): Mail {
  return {
    subject: `"${opts.familyName}" — a new member joined`,
    html: layout(
      'Good news!',
      p(`<b>${opts.memberEmail}</b> just joined your family <b>${opts.familyName}</b> on GRP.`) +
        p('Open the Family tab in the app to see the updated member list.'),
    ),
    text: `${opts.memberEmail} just joined your family "${opts.familyName}" on GRP.`,
  };
}

export function todoAssignedEmail(opts: {
  title: string;
  due: string;
  familyName: string;
  assignerName: string;
}): Mail {
  return {
    subject: `New task: ${opts.title}`,
    html: layout(
      'A task was assigned to you',
      p(`<b>${opts.assignerName}</b> assigned you a task in <b>${opts.familyName}</b>:`) +
        p(`<b>${opts.title}</b>${opts.due ? `<br/>Due: ${opts.due}` : ''}`) +
        p('Open the Todos tab in GRP to view it and mark it done.'),
    ),
    text: `${opts.assignerName} assigned you "${opts.title}"${opts.due ? ` (due ${opts.due})` : ''} in ${opts.familyName}. Open GRP Todos to view it.`,
  };
}

export function sessionStatusEmail(opts: {
  status: 'approved' | 'paid';
  childName: string;
  amount: number;
  familyName: string;
}): Mail {
  const approved = opts.status === 'approved';
  return {
    subject: approved
      ? `Session approved: ${opts.childName} — ₹${opts.amount}`
      : `Payment marked paid: ${opts.childName} — ₹${opts.amount}`,
    html: layout(
      approved ? 'Session approved' : 'You got paid',
      p(
        approved
          ? `Your tuition session for <b>${opts.childName}</b> (${opts.familyName}) was <b>approved</b> for <b>₹${opts.amount}</b>. It is now counted in your payment due.`
          : `Your payment of <b>₹${opts.amount}</b> for <b>${opts.childName}</b> (${opts.familyName}) was marked <b>paid</b>. Thank you!`,
      ) + p('Open the Tuition tab in GRP to see the updated sessions.'),
    ),
    text: approved
      ? `Your session for ${opts.childName} (${opts.familyName}) was approved for ₹${opts.amount}.`
      : `Your payment of ₹${opts.amount} for ${opts.childName} (${opts.familyName}) was marked paid.`,
  };
}
