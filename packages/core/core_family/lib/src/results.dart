import 'json.dart';
import 'models.dart';

class NewAccount {
  final String bank;
  final String number;
  final String name;

  const NewAccount({required this.bank, required this.number, required this.name});

  Json toJson() => {'bank': bank, 'number': number, 'name': name};
}

/// 송금 시트에서 만드는 초안. 등록된 받는 분(contactId) 또는 새 계좌 중 하나.
class TransferDraft {
  final String? contactId;
  final NewAccount? newAccount;
  final int amount;

  const TransferDraft({this.contactId, this.newAccount, this.amount = 0});

  TransferDraft copyWith({String? contactId, NewAccount? newAccount, int? amount, bool clearContact = false}) =>
      TransferDraft(
        contactId: clearContact ? null : (contactId ?? this.contactId),
        newAccount: contactId != null ? null : (newAccount ?? this.newAccount),
        amount: amount ?? this.amount,
      );

  Json toJson(String memberId) => {
    'member_id': memberId,
    'contact_id': contactId,
    'new_account': newAccount?.toJson(),
    'amount': amount,
  };
}

class Recipient {
  final String name;
  final String relation;
  final String bank;
  final String number;
  final bool isNew;
  final String? contactId;

  const Recipient({
    required this.name,
    required this.bank,
    required this.number,
    this.relation = '',
    this.isNew = false,
    this.contactId,
  });

  factory Recipient.fromJson(Json j) => Recipient(
    name: asString(j['name']),
    relation: asString(j['relation']),
    bank: asString(j['bank']),
    number: asString(j['number']),
    isNew: asBool(j['is_new']),
    contactId: asStringOrNull(j['contact_id']),
  );
}

/// AI 안심 점검 결과 (송금 전 미리보기).
class TransferPreview {
  final Recipient recipient;
  final int amount;
  final RiskAssessment risk;

  const TransferPreview({required this.recipient, required this.amount, required this.risk});

  factory TransferPreview.fromJson(Json j) => TransferPreview(
    recipient: Recipient.fromJson(asJson(j['recipient'])),
    amount: asInt(j['amount']),
    risk: RiskAssessment.fromJson(asJson(j['risk'])),
  );
}

class TransferResult {
  /// done: 바로 보냄 / pending: 보호자 확인 대기
  final String status;
  final ApprovalRequest? request;
  final Recipient? recipient;
  final int amount;
  final RiskAssessment? risk;

  const TransferResult({required this.status, this.request, this.recipient, this.amount = 0, this.risk});

  bool get isPending => status == 'pending';

  factory TransferResult.fromJson(Json j) => TransferResult(
    status: asString(j['status']),
    request: j['request'] is Map<String, dynamic> ? ApprovalRequest.fromJson(j['request'] as Json) : null,
    recipient: j['recipient'] is Map<String, dynamic> ? Recipient.fromJson(j['recipient'] as Json) : null,
    amount: asInt(j['amount'], asInt(asJson(j['request'])['amount'])),
    risk: j['risk'] is Map<String, dynamic> ? RiskAssessment.fromJson(j['risk'] as Json) : null,
  );
}

class PaymentResult {
  final bool ok;
  final String code;
  final String message;
  final bool canRequest;
  final Merchant merchant;
  final ApprovalRequest? request;

  const PaymentResult({
    required this.ok,
    required this.code,
    required this.merchant,
    this.message = '',
    this.canRequest = false,
    this.request,
  });

  bool get isPending => ok && code == 'pending';

  factory PaymentResult.fromJson(Json j) => PaymentResult(
    ok: asBool(j['ok']),
    code: asString(j['code']),
    message: asString(j['message']),
    canRequest: asBool(j['can_request']),
    merchant: Merchant.fromJson(asJson(j['merchant'])),
    request: j['request'] is Map<String, dynamic> ? ApprovalRequest.fromJson(j['request'] as Json) : null,
  );
}

class ModeChangeResult {
  /// done / pending / same
  final String status;
  final ApprovalRequest? request;

  const ModeChangeResult(this.status, [this.request]);

  factory ModeChangeResult.fromJson(Json j) => ModeChangeResult(
    asString(j['status']),
    j['request'] is Map<String, dynamic> ? ApprovalRequest.fromJson(j['request'] as Json) : null,
  );
}

class FreezeResult {
  final bool alreadyFrozen;
  final int frozenAccountsCount;
  final DateTime? expiresAt;
  final bool guardianNotified;

  const FreezeResult({
    required this.alreadyFrozen,
    required this.frozenAccountsCount,
    required this.guardianNotified,
    this.expiresAt,
  });

  factory FreezeResult.fromJson(Json j) => FreezeResult(
    alreadyFrozen: asBool(j['already_frozen']),
    frozenAccountsCount: asInt(j['frozen_accounts_count']),
    expiresAt: asDate(j['freeze_expires_at']),
    guardianNotified: asBool(j['guardian_notified']),
  );
}

class DecisionResult {
  final String status; // approved / rejected / failed
  final String message;
  final ApprovalRequest? request;

  const DecisionResult(this.status, {this.message = '', this.request});

  factory DecisionResult.fromJson(Json j) => DecisionResult(
    asString(j['status']).toLowerCase(),
    message: asString(j['message']),
    request: j['request'] is Map<String, dynamic> ? ApprovalRequest.fromJson(j['request'] as Json) : null,
  );
}

/// 서버 실시간 이벤트. [fromThisDevice]이면 이 기기의 요청으로 생긴 이벤트입니다.
class FamilyEvent {
  final String type;
  final String message;
  final String? memberId;
  final String? requestId;
  final String? script;
  final bool fromThisDevice;

  const FamilyEvent({
    required this.type,
    this.message = '',
    this.memberId,
    this.requestId,
    this.script,
    this.fromThisDevice = false,
  });

  factory FamilyEvent.fromJson(Json j, {required String clientId}) => FamilyEvent(
    type: asString(j['type']),
    message: asString(j['message']),
    memberId: asStringOrNull(j['member_id']),
    requestId: asStringOrNull(j['request_id']),
    script: asStringOrNull(j['script']),
    fromThisDevice: j['origin'] == clientId,
  );
}

/// 외부 연동 기록 (오픈뱅킹 · FCM · SMS · ARS).
class IntegrationLogEntry {
  final String id;
  final DateTime at;
  final String channel;
  final String action;
  final String target;
  final String message;

  const IntegrationLogEntry({
    required this.id,
    required this.at,
    required this.channel,
    required this.action,
    required this.target,
    required this.message,
  });

  factory IntegrationLogEntry.fromJson(Json j) => IntegrationLogEntry(
    id: asString(j['id']),
    at: asDateOr(j['at'], DateTime.now()),
    channel: asString(j['channel']),
    action: asString(j['action']),
    target: asString(j['target']),
    message: asString(j['message']),
  );
}
