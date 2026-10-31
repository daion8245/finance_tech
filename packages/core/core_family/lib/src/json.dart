// 서버 JSON을 안전하게 읽는 작은 도우미들.

typedef Json = Map<String, dynamic>;

int asInt(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;

double asDouble(Object? v, [double fallback = 0]) => v is num ? v.toDouble() : fallback;

String asString(Object? v, [String fallback = '']) => v is String ? v : fallback;

String? asStringOrNull(Object? v) => v is String && v.isNotEmpty ? v : null;

bool asBool(Object? v, [bool fallback = false]) => v is bool ? v : fallback;

DateTime? asDate(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

DateTime asDateOr(Object? v, DateTime fallback) => asDate(v) ?? fallback;

Json asJson(Object? v) => v is Map<String, dynamic> ? v : const {};

List<T> asList<T>(Object? v, T Function(Json) parse) =>
    v is List ? v.whereType<Map<String, dynamic>>().map(parse).toList(growable: false) : const [];

List<String> asStrings(Object? v) => v is List ? v.whereType<String>().toList(growable: false) : const [];
