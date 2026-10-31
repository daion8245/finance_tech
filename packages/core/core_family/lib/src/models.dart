import 'json.dart';

/// 화면에서 고르는 사용자. 보호자는 가족 전체를 봅니다.
enum Persona {
  senior('어르신'),
  child('아이'),
  guardian('보호자');

  final String label;
  const Persona(this.label);

  /// 보호 대상 사용자 id (보호자는 null).
  String? get memberId => this == Persona.guardian ? null : name;
}

enum RiskLevel {
  safe('안전', '안전한 거래로 보여요', '평소 거래 패턴과 비슷해요'),
  caution('주의', '한 번 더 확인이 필요해요', '평소와 다른 점이 있어 보호자 확인을 거쳐요'),
  high('위험', '사기 위험이 높은 거래예요', '보이스피싱에서 자주 보이는 패턴이에요');

  final String label;
  final String title;
  final String desc;
  const RiskLevel(this.label, this.title, this.desc);

  static RiskLevel parse(Object? v) =>
      RiskLevel.values.firstWhere((l) => l.name == v, orElse: () => RiskLevel.safe);
}

/// SOS 동결을 일으킨 방법. 서버 API의 trigger_type 값과 같습니다.
enum SosTrigger {
  shake('SHAKE_MOTION', '흔들기'),
  longPress('LONG_PRESS', '길게 누르기'),
  guardian('GUARDIAN_REMOTE', '보호자 원격');

  final String apiValue;
  final String label;
  const SosTrigger(this.apiValue, this.label);

  static SosTrigger? parse(Object? v) {
    for (final t in SosTrigger.values) {
      if (t.apiValue == v) return t;
    }
    return null;
  }
}

class Guardian {
  final String id;
  final String name;
  final String avatar;
  final String phone;

  /// 보호자 본인 계좌. 가족과 같은 송금·결제·내역 기능을 씁니다.
  final Member? banking;

  const Guardian({required this.id, required this.name, this.avatar = '', this.phone = '', this.banking});

  factory Guardian.fromJson(Json j) => Guardian(
    id: asString(j['id']),
    name: asString(j['name']),
    avatar: asString(j['avatar']),
    phone: asString(j['phone']),
    banking: j['banking'] is Map<String, dynamic> ? Member.fromJson(j['banking'] as Json) : null,
  );
}

class BankAccount {
  final String id;
  final String name;
  final String bank;
  final String number;
  final String kind;
  final int balance;
  final bool withdrawalBlocked;

  const BankAccount({
    required this.id,
    required this.name,
    required this.bank,
    required this.number,
    this.kind = 'CHECKING',
    this.balance = 0,
    this.withdrawalBlocked = false,
  });

  factory BankAccount.fromJson(Json j) => BankAccount(
    id: asString(j['id']),
    name: asString(j['name']),
    bank: asString(j['bank']),
    number: asString(j['number']),
    kind: asString(j['kind'], 'CHECKING'),
    balance: asInt(j['balance']),
    withdrawalBlocked: asBool(j['withdrawal_blocked']),
  );
}

class Contact {
  final String id;
  final String name;
  final String relation;
  final String bank;
  final String number;

  const Contact({required this.id, required this.name, required this.relation, required this.bank, required this.number});

  factory Contact.fromJson(Json j) => Contact(
    id: asString(j['id']),
    name: asString(j['name']),
    relation: asString(j['relation']),
    bank: asString(j['bank']),
    number: asString(j['number']),
  );
}

/// 거래 내역 한 줄. kind: in(입금) / out(출금) / protect(보호 조치).
class LedgerEntry {
  final String id;
  final String kind;
  final String title;
  final String desc;
  final int amount;
  final String emoji;
  final String? tag;
  final String? tone;
  final DateTime at;

  const LedgerEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.desc,
    required this.amount,
    required this.at,
    this.emoji = '',
    this.tag,
    this.tone,
  });

  bool get isProtect => kind == 'protect';
  bool get isDanger => tone == 'red' || tone == 'amber';

  factory LedgerEntry.fromJson(Json j) => LedgerEntry(
    id: asString(j['id']),
    kind: asString(j['kind']),
    title: asString(j['title']),
    desc: asString(j['desc']),
    amount: asInt(j['amount']),
    emoji: asString(j['emoji']),
    tag: asStringOrNull(j['tag']),
    tone: asStringOrNull(j['tone']),
    at: asDateOr(j['at'], DateTime.fromMillisecondsSinceEpoch(0)),
  );
}

/// 보호자 결정 결과 배너.
class Notice {
  final String id;
  final String? requestId;
  final String status;
  final String title;
  final int amount;
  final String reason;

  const Notice({required this.id, required this.status, required this.title, this.requestId, this.amount = 0, this.reason = ''});

  factory Notice.fromJson(Json j) => Notice(
    id: asString(j['id']),
    requestId: asStringOrNull(j['request_id']),
    status: asString(j['status']),
    title: asString(j['title']),
    amount: asInt(j['amount']),
    reason: asString(j['reason']),
  );
}

class PaymentCheck {
  final bool ok;
  final String code;
  final String message;
  final bool canRequest;

  const PaymentCheck({required this.ok, required this.code, this.message = '', this.canRequest = false});

  factory PaymentCheck.fromJson(Json j) => PaymentCheck(
    ok: asBool(j['ok']),
    code: asString(j['code'], 'ok'),
    message: asString(j['message']),
    canRequest: asBool(j['can_request']),
  );
}

class Merchant {
  final String id;
  final String name;
  final String category;
  final String categoryLabel;
  final String mcc;
  final int amount;
  final String emoji;
  final PaymentCheck check;

  const Merchant({
    required this.id,
    required this.name,
    required this.category,
    required this.categoryLabel,
    required this.amount,
    this.mcc = '',
    this.emoji = '',
    this.check = const PaymentCheck(ok: true, code: 'ok'),
  });

  factory Merchant.fromJson(Json j) => Merchant(
    id: asString(j['id']),
    name: asString(j['name']),
    category: asString(j['category']),
    categoryLabel: asString(j['category_label']),
    mcc: asString(j['mcc']),
    amount: asInt(j['amount']),
    emoji: asString(j['emoji']),
    check: PaymentCheck.fromJson(asJson(j['check'])),
  );
}

class LimitRange {
  final int min;
  final int max;
  final int step;

  const LimitRange({required this.min, required this.max, required this.step});

  factory LimitRange.fromJson(Json j) => LimitRange(min: asInt(j['min']), max: asInt(j['max'], 1), step: asInt(j['step'], 1));
}

/// 계좌를 가진 사용자: 보호 대상 가족(어르신·아이) 또는 보호자 본인([Guardian.banking]).
class Member {
  final String id;
  final String role;
  final String name;
  final String? nickname;
  final String relationLabel;
  final String guardianRelation;
  final String avatar;
  final int balance;
  final BankAccount account;
  final List<BankAccount> accounts;
  final int spentToday;
  final int dailyLimit;
  final LimitRange limitRange;
  final int approvalThreshold;
  final int avgTransfer;
  final String mode;
  final List<String> modes;
  final bool requireApprovalToLoosen;
  final bool sleepGuard;
  final bool sleepActive;
  final bool isFrozen;
  final DateTime? frozenUntil;
  final SosTrigger? frozenSource;
  final List<Contact> contacts;
  final List<LedgerEntry> ledger;
  final List<Notice> notices;
  final List<Merchant> merchants;

  const Member({
    required this.id,
    required this.role,
    required this.name,
    required this.relationLabel,
    required this.guardianRelation,
    required this.balance,
    required this.account,
    required this.dailyLimit,
    required this.limitRange,
    required this.approvalThreshold,
    required this.mode,
    this.nickname,
    this.avatar = '',
    this.accounts = const [],
    this.spentToday = 0,
    this.avgTransfer = 0,
    this.modes = const [],
    this.requireApprovalToLoosen = false,
    this.sleepGuard = false,
    this.sleepActive = false,
    this.isFrozen = false,
    this.frozenUntil,
    this.frozenSource,
    this.contacts = const [],
    this.ledger = const [],
    this.notices = const [],
    this.merchants = const [],
  });

  bool get isChild => role == 'CHILD';

  /// 보호자 본인 계좌. 보호자 승인·안심 모드·SOS 동결 없이 바로 보냅니다.
  bool get isGuardian => role == 'GUARDIAN';
  String get callName => nickname ?? name;

  /// "어머니 김순자"
  String get label => '$relationLabel $name';

  Merchant? merchant(String id) => merchants.where((m) => m.id == id).firstOrNull;
  Contact? contact(String id) => contacts.where((c) => c.id == id).firstOrNull;

  factory Member.fromJson(Json j) {
    final accounts = asList(j['accounts'], BankAccount.fromJson);
    return Member(
      id: asString(j['id']),
      role: asString(j['role']),
      name: asString(j['name']),
      nickname: asStringOrNull(j['nickname']),
      relationLabel: asString(j['relation_label']),
      guardianRelation: asString(j['guardian_relation']),
      avatar: asString(j['avatar']),
      balance: asInt(j['balance']),
      account: j['account'] is Map<String, dynamic>
          ? BankAccount.fromJson(j['account'] as Json)
          : (accounts.firstOrNull ?? const BankAccount(id: '', name: '', bank: '', number: '')),
      accounts: accounts,
      spentToday: asInt(j['spent_today']),
      dailyLimit: asInt(j['daily_limit'], 1),
      limitRange: LimitRange.fromJson(asJson(j['limit_range'])),
      approvalThreshold: asInt(j['approval_threshold']),
      avgTransfer: asInt(j['avg_transfer']),
      mode: asString(j['mode'], 'normal'),
      modes: asStrings(j['modes']),
      requireApprovalToLoosen: asBool(j['require_approval_to_loosen']),
      sleepGuard: asBool(j['sleep_guard']),
      sleepActive: asBool(j['sleep_active']),
      isFrozen: asBool(j['is_frozen']),
      frozenUntil: asDate(j['frozen_until']),
      frozenSource: SosTrigger.parse(j['frozen_source']),
      contacts: asList(j['contacts'], Contact.fromJson),
      ledger: asList(j['ledger'], LedgerEntry.fromJson),
      notices: asList(j['notices'], Notice.fromJson),
      merchants: asList(j['merchants'], Merchant.fromJson),
    );
  }
}

class RiskSignal {
  final String id;
  final String label;
  final int weight;

  const RiskSignal({required this.id, required this.label, this.weight = 0});

  factory RiskSignal.fromJson(Json j) =>
      RiskSignal(id: asString(j['id']), label: asString(j['label']), weight: asInt(j['weight']));
}

/// Isolation Forest 판정 정보.
class AnomalyInfo {
  final bool anomaly;
  final double strength;
  final int trainedOn;

  const AnomalyInfo({required this.anomaly, required this.strength, required this.trainedOn});

  factory AnomalyInfo.fromJson(Json j) =>
      AnomalyInfo(anomaly: asBool(j['anomaly']), strength: asDouble(j['strength']), trainedOn: asInt(j['trained_on']));
}

/// AI FDS 위험도 판정.
class RiskAssessment {
  final int score;
  final RiskLevel level;
  final List<RiskSignal> signals;
  final bool needsApproval;
  final bool sleepWindow;
  final AnomalyInfo? model;

  const RiskAssessment({
    required this.score,
    required this.level,
    this.signals = const [],
    this.needsApproval = false,
    this.sleepWindow = false,
    this.model,
  });

  bool get isSafe => level == RiskLevel.safe;

  factory RiskAssessment.fromJson(Json j) => RiskAssessment(
    score: asInt(j['score']),
    level: RiskLevel.parse(j['level']),
    signals: asList(j['signals'], RiskSignal.fromJson),
    needsApproval: asBool(j['needs_approval']),
    sleepWindow: asBool(j['sleep_window']),
    model: j['model'] is Map<String, dynamic> ? AnomalyInfo.fromJson(j['model'] as Json) : null,
  );
}

/// 보호자 콜백 승인 요청.
class ApprovalRequest {
  final String id;
  final String memberId;
  final String type; // transfer / payment / mode / unfreeze
  final String title;
  final int amount;
  final String detail;
  final RiskAssessment? risk;
  final String status; // pending / approved / rejected / cancelled / expired / failed
  final String channel;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? decidedAt;
  final String? decidedBy;
  final String? failReason;
  final DateTime? pushAckAt;
  final DateTime? arsCalledAt;

  const ApprovalRequest({
    required this.id,
    required this.memberId,
    required this.type,
    required this.title,
    required this.status,
    required this.createdAt,
    this.amount = 0,
    this.detail = '',
    this.risk,
    this.channel = '앱 알림',
    this.expiresAt,
    this.decidedAt,
    this.decidedBy,
    this.failReason,
    this.pushAckAt,
    this.arsCalledAt,
  });

  bool get isPending => status == 'pending';

  factory ApprovalRequest.fromJson(Json j) => ApprovalRequest(
    id: asString(j['id']),
    memberId: asString(j['member_id']),
    type: asString(j['type']),
    title: asString(j['title']),
    amount: asInt(j['amount']),
    detail: asString(j['detail']),
    risk: j['risk'] is Map<String, dynamic> ? RiskAssessment.fromJson(j['risk'] as Json) : null,
    status: asString(j['status']),
    channel: asString(j['channel'], '앱 알림'),
    createdAt: asDateOr(j['created_at'], DateTime.now()),
    expiresAt: asDate(j['expires_at']),
    decidedAt: asDate(j['decided_at']),
    decidedBy: asStringOrNull(j['decided_by']),
    failReason: asStringOrNull(j['fail_reason']),
    pushAckAt: asDate(j['push_ack_at']),
    arsCalledAt: asDate(j['ars_called_at']),
  );
}

/// 보호자에게 보이는 가족 알림.
class FamilyAlert {
  final String id;
  final String memberId;
  final String title;
  final int amount;
  final String status;
  final String emoji;
  final String? requestId;
  final DateTime at;

  const FamilyAlert({
    required this.id,
    required this.memberId,
    required this.title,
    required this.status,
    required this.at,
    this.amount = 0,
    this.emoji = '',
    this.requestId,
  });

  factory FamilyAlert.fromJson(Json j) => FamilyAlert(
    id: asString(j['id']),
    memberId: asString(j['member_id']),
    title: asString(j['title']),
    amount: asInt(j['amount']),
    status: asString(j['status']),
    emoji: asString(j['emoji']),
    requestId: asStringOrNull(j['request_id']),
    at: asDateOr(j['at'], DateTime.fromMillisecondsSinceEpoch(0)),
  );
}

/// 상황별 안심 모드 (MCC 화이트리스트).
class ModeInfo {
  final String id;
  final String label;
  final String short;
  final String icon;
  final String desc;
  final String schedule;
  final List<String>? allow;
  final List<String> allowedMcc;

  const ModeInfo({
    required this.id,
    required this.label,
    required this.short,
    required this.desc,
    this.icon = '',
    this.schedule = '',
    this.allow,
    this.allowedMcc = const [],
  });

  bool get restricted => allow != null;

  factory ModeInfo.fromJson(Json j) => ModeInfo(
    id: asString(j['id']),
    label: asString(j['label']),
    short: asString(j['short']),
    icon: asString(j['icon']),
    desc: asString(j['desc']),
    schedule: asString(j['schedule']),
    allow: j['allow'] is List ? asStrings(j['allow']) : null,
    allowedMcc: asStrings(j['allowed_mcc']),
  );
}

class ApprovalConfig {
  final int approvalTimeoutSeconds;
  final int arsAfterSeconds;
  final int freezeHours;

  const ApprovalConfig({this.approvalTimeoutSeconds = 180, this.arsAfterSeconds = 20, this.freezeHours = 24});

  factory ApprovalConfig.fromJson(Json j) => ApprovalConfig(
    approvalTimeoutSeconds: asInt(j['approval_timeout_seconds'], 180),
    arsAfterSeconds: asInt(j['ars_after_seconds'], 20),
    freezeHours: asInt(j['freeze_hours'], 24),
  );
}

/// /api/v1/state 전체.
class FamilySnapshot {
  final DateTime serverTime;
  final ApprovalConfig config;
  final Guardian guardian;
  final List<Member> members;
  final List<ApprovalRequest> requests;
  final List<FamilyAlert> alerts;
  final List<ModeInfo> modes;
  final List<String> banks;
  final int blockedToday;
  final int riskyTransfers;

  const FamilySnapshot({
    required this.serverTime,
    required this.guardian,
    required this.members,
    this.config = const ApprovalConfig(),
    this.requests = const [],
    this.alerts = const [],
    this.modes = const [],
    this.banks = const [],
    this.blockedToday = 0,
    this.riskyTransfers = 0,
  });

  factory FamilySnapshot.fromJson(Json j) {
    final catalog = asJson(j['catalog']);
    final stats = asJson(j['stats']);
    return FamilySnapshot(
      serverTime: asDateOr(j['server_time'], DateTime.now()),
      config: ApprovalConfig.fromJson(asJson(j['config'])),
      guardian: Guardian.fromJson(asJson(j['guardian'])),
      members: asList(j['members'], Member.fromJson),
      requests: asList(j['requests'], ApprovalRequest.fromJson),
      alerts: asList(j['alerts'], FamilyAlert.fromJson),
      modes: asList(catalog['modes'], ModeInfo.fromJson),
      banks: asStrings(catalog['banks']),
      blockedToday: asInt(stats['blocked_today']),
      riskyTransfers: asInt(stats['risky_transfers']),
    );
  }

  /// 계좌 주인 (보호 대상 가족 또는 보호자 본인).
  Member? memberOrNull(String id) =>
      members.where((m) => m.id == id).firstOrNull ?? (guardian.banking?.id == id ? guardian.banking : null);

  /// 이 사용자가 쓰는 내 계좌 (보호자는 본인 계좌).
  Member? accountOf(Persona p) => p.memberId == null ? guardian.banking : memberOrNull(p.memberId!);

  Member member(String id) {
    final m = memberOrNull(id);
    if (m == null) throw StateError('알 수 없는 사용자: $id');
    return m;
  }

  ModeInfo mode(String id) =>
      modes.where((m) => m.id == id).firstOrNull ?? ModeInfo(id: id, label: id, short: id, desc: '');

  ApprovalRequest? request(String id) => requests.where((r) => r.id == id).firstOrNull;

  List<ApprovalRequest> pending([String? memberId]) =>
      requests.where((r) => r.isPending && (memberId == null || r.memberId == memberId)).toList(growable: false);

  bool hasPending(String memberId, String type) => pending(memberId).any((r) => r.type == type);
}
