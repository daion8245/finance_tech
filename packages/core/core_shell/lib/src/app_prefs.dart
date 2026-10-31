/// 설정 화면의 켜고 끄는 항목.
enum PrefKey { largeText, highContrast, voice, haptics, shake, hideBalance }

/// 취약계층 맞춤 화면 설정 (기획서 3.4).
class AppPrefs {
  final bool largeText;
  final bool highContrast;
  final bool voice;
  final bool haptics;
  final bool shake;
  final bool hideBalance;

  const AppPrefs({
    this.largeText = false,
    this.highContrast = false,
    this.voice = false,
    this.haptics = true,
    this.shake = true,
    this.hideBalance = false,
  });

  bool operator [](PrefKey key) => switch (key) {
    PrefKey.largeText => largeText,
    PrefKey.highContrast => highContrast,
    PrefKey.voice => voice,
    PrefKey.haptics => haptics,
    PrefKey.shake => shake,
    PrefKey.hideBalance => hideBalance,
  };

  AppPrefs set(PrefKey key, bool value) => AppPrefs(
    largeText: key == PrefKey.largeText ? value : largeText,
    highContrast: key == PrefKey.highContrast ? value : highContrast,
    voice: key == PrefKey.voice ? value : voice,
    haptics: key == PrefKey.haptics ? value : haptics,
    shake: key == PrefKey.shake ? value : shake,
    hideBalance: key == PrefKey.hideBalance ? value : hideBalance,
  );
}
