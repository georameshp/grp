import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors `families/{fid}/children/{cid}`.
class ChildProfile {
  final String? id;
  final String name;
  final DateTime? dob;
  final String school;
  final List<String> subjects;
  final List<String> linkedParentUids;

  const ChildProfile({
    this.id,
    required this.name,
    this.dob,
    this.school = '',
    this.subjects = const [],
    this.linkedParentUids = const [],
  });

  static const sub = 'children';

  factory ChildProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ChildProfile(
      id: doc.id,
      name: d['name'] as String? ?? '',
      dob: (d['dob'] as Timestamp?)?.toDate(),
      school: d['school'] as String? ?? '',
      subjects: List<String>.from(d['subjects'] ?? []),
      linkedParentUids: List<String>.from(d['linkedParentUids'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'dob': dob != null ? Timestamp.fromDate(dob!) : null,
        'school': school,
        'subjects': subjects,
        'linkedParentUids': linkedParentUids,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

/// Mirrors `families/{fid}/children/{cid}/activities/{id}`.
class ChildActivity {
  final String? id;
  final DateTime date;
  final String schoolLog;
  final double studyHours;
  final String mood;
  final String addedBy;

  const ChildActivity({
    this.id,
    required this.date,
    this.schoolLog = '',
    this.studyHours = 0,
    this.mood = '',
    this.addedBy = '',
  });

  static const sub = 'activities';

  factory ChildActivity.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ChildActivity(
      id: doc.id,
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      schoolLog: d['schoolLog'] as String? ?? '',
      studyHours: (d['studyHours'] as num?)?.toDouble() ?? 0,
      mood: d['mood'] as String? ?? '',
      addedBy: d['addedBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson(String childId, String uid) => {
        'childId': childId,
        'date': Timestamp.fromDate(date),
        'schoolLog': schoolLog,
        'studyHours': studyHours,
        'mood': mood,
        'addedBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

/// Mirrors `families/{fid}/teachers/{tid}` (doc id = member uid).
class TeacherProfile {
  final String? id;
  final String userId;
  final String name;
  final String email;
  final List<String> subjects;
  final double hourlyRate;
  final List<String> assignedChildIds;

  const TeacherProfile({
    this.id,
    required this.userId,
    this.name = '',
    this.email = '',
    this.subjects = const [],
    this.hourlyRate = 0,
    this.assignedChildIds = const [],
  });

  static const sub = 'teachers';

  factory TeacherProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return TeacherProfile(
      id: doc.id,
      userId: d['userId'] as String? ?? doc.id,
      name: d['name'] as String? ?? '',
      email: d['email'] as String? ?? '',
      subjects: List<String>.from(d['subjects'] ?? []),
      hourlyRate: (d['hourlyRate'] as num?)?.toDouble() ?? 0,
      assignedChildIds: List<String>.from(d['assignedChildIds'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'name': name,
        'email': email,
        'subjects': subjects,
        'hourlyRate': hourlyRate,
        'assignedChildIds': assignedChildIds,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

/// Session statuses: logged -> approved -> paid.
class TuitionSession {
  final String? id;
  final String childId;
  final DateTime start;
  final DateTime end;
  final double hours;
  final double rateSnapshot;
  final double amount;
  final String status;
  final String? approvedBy;

  const TuitionSession({
    this.id,
    required this.childId,
    required this.start,
    required this.end,
    this.hours = 0,
    this.rateSnapshot = 0,
    this.amount = 0,
    this.status = 'logged',
    this.approvedBy,
  });

  static const sub = 'sessions';

  factory TuitionSession.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return TuitionSession(
      id: doc.id,
      childId: d['childId'] as String? ?? '',
      start: (d['start'] as Timestamp?)?.toDate() ?? DateTime.now(),
      end: (d['end'] as Timestamp?)?.toDate() ?? DateTime.now(),
      hours: (d['hours'] as num?)?.toDouble() ?? 0,
      rateSnapshot: (d['rateSnapshot'] as num?)?.toDouble() ?? 0,
      amount: (d['amount'] as num?)?.toDouble() ?? 0,
      status: d['status'] as String? ?? 'logged',
      approvedBy: d['approvedBy'] as String?,
    );
  }

  Map<String, dynamic> toJson(String loggedBy) => {
        'childId': childId,
        'start': Timestamp.fromDate(start),
        'end': Timestamp.fromDate(end),
        'hours': hours,
        'rateSnapshot': rateSnapshot,
        'amount': amount,
        'status': status,
        'loggedBy': loggedBy,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

/// Pure helpers — unit-tested, reused by UI and (mirrored) Functions.
double sessionHours(DateTime start, DateTime end) =>
    end.difference(start).inMinutes / 60.0;

double sessionAmount(double hours, double rate) =>
    double.parse((hours * rate).toStringAsFixed(2));

/// Sum of approved-but-unpaid session amounts.
double paymentDue(Iterable<TuitionSession> sessions) => sessions
    .where((s) => s.status == 'approved')
    .fold(0.0, (sum, s) => sum + s.amount);
