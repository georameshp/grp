import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors `users/{uid}` in Firestore.
class GrpUser {
  final String uid;
  final String emailLower;
  final String displayName;
  final String? photoUrl;
  final List<String> familyIds;
  final DateTime? createdAt;

  const GrpUser({
    required this.uid,
    required this.emailLower,
    required this.displayName,
    this.photoUrl,
    this.familyIds = const [],
    this.createdAt,
  });

  static const collection = 'users';
  static const byEmailCollection = 'usersByEmail';

  factory GrpUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return GrpUser(
      uid: doc.id,
      emailLower: (d['emailLower'] as String? ?? '').toLowerCase(),
      displayName: d['displayName'] as String? ?? '',
      photoUrl: d['photoUrl'] as String?,
      familyIds: List<String>.from(d['familyIds'] ?? []),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
        'emailLower': emailLower.toLowerCase(),
        'displayName': displayName,
        'photoUrl': photoUrl,
        'familyIds': familyIds,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

/// Mirrors `families/{fid}` + `families/{fid}/members/{uid}`.
class Family {
  final String id;
  final String name;
  final String ownerUid;

  const Family({required this.id, required this.name, required this.ownerUid});

  static const collection = 'families';
  static const membersSub = 'members';

  factory Family.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Family(
      id: doc.id,
      name: d['name'] as String? ?? 'My Family',
      ownerUid: d['ownerUid'] as String? ?? '',
    );
  }
}

/// Mirrors `families/{fid}/todos/{id}`.
class TodoItem {
  final String? id;
  final String title;
  final String notes;
  final DateTime? dueAt;
  final DateTime? remindAt;
  final String scope; // personal | family | child
  final String? childId;
  final List<String> assigneeUids;
  final bool done;

  const TodoItem({
    this.id,
    required this.title,
    this.notes = '',
    this.dueAt,
    this.remindAt,
    this.scope = 'personal',
    this.childId,
    this.assigneeUids = const [],
    this.done = false,
  });

  static const sub = 'todos';

  factory TodoItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return TodoItem(
      id: doc.id,
      title: d['title'] as String? ?? '',
      notes: d['notes'] as String? ?? '',
      dueAt: (d['dueAt'] as Timestamp?)?.toDate(),
      remindAt: (d['remindAt'] as Timestamp?)?.toDate(),
      scope: d['scope'] as String? ?? 'personal',
      childId: d['childId'] as String?,
      assigneeUids: List<String>.from(d['assigneeUids'] ?? []),
      done: d['done'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson(String createdBy) => {
        'title': title,
        'notes': notes,
        'dueAt': dueAt != null ? Timestamp.fromDate(dueAt!) : null,
        'remindAt': remindAt != null ? Timestamp.fromDate(remindAt!) : null,
        'scope': scope,
        'childId': childId,
        'assigneeUids': assigneeUids,
        'done': done,
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

/// Mirrors `families/{fid}/transactions/{id}`.
class TransactionEntry {
  final String? id;
  final String type; // income|expense|loan_given|loan_taken|repayment|investment
  final double amount;
  final String currency;
  final String category;
  final DateTime date;
  final String notes;
  final String receiptUrl;

  const TransactionEntry({
    this.id,
    required this.type,
    required this.amount,
    this.currency = 'INR',
    this.category = 'general',
    required this.date,
    this.notes = '',
    this.receiptUrl = '',
  });

  static const sub = 'transactions';

  factory TransactionEntry.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return TransactionEntry(
      id: doc.id,
      type: d['type'] as String? ?? 'expense',
      amount: (d['amount'] as num?)?.toDouble() ?? 0,
      currency: d['currency'] as String? ?? 'INR',
      category: d['category'] as String? ?? 'general',
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: d['notes'] as String? ?? '',
      receiptUrl: d['receiptUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson(String createdBy) => {
        'type': type,
        'amount': amount,
        'currency': currency,
        'category': category,
        'date': Timestamp.fromDate(date),
        'notes': notes,
        'receiptUrl': receiptUrl,
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
