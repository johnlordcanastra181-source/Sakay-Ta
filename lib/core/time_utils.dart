/// Utility class for dynamic time detection and localized greetings.
///
/// Time ranges:
/// - Morning: 5:00 AM – 11:59 AM (Hours 5 to 11)
/// - Afternoon: 12:00 PM – 5:59 PM (Hours 12 to 17)
/// - Evening: 6:00 PM – 4:59 AM (Hours 18 to 23, and 0 to 4)
class TimeGreeting {
  TimeGreeting._();

  /// Returns the greeting in English based on the provided [time] (or [DateTime.now()]).
  static String getGreeting({DateTime? time}) {
    final hour = (time ?? DateTime.now()).hour;

    if (hour >= 5 && hour < 12) {
      return 'Good Morning';
    } else if (hour >= 12 && hour < 18) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  /// Returns the greeting in Cebuano/Bisaya based on the provided [time] (or [DateTime.now()]).
  static String getCebuanoGreeting({DateTime? time}) {
    final hour = (time ?? DateTime.now()).hour;

    if (hour >= 5 && hour < 12) {
      return 'Maayong Buntag';
    } else if (hour >= 12 && hour < 18) {
      return 'Maayong Hapon';
    } else {
      return 'Maayong Gabi';
    }
  }

  /// Returns the greeting in Tagalog/Filipino based on the provided [time] (or [DateTime.now()]).
  static String getTagalogGreeting({DateTime? time}) {
    final hour = (time ?? DateTime.now()).hour;

    if (hour >= 5 && hour < 12) {
      return 'Magandang Umaga';
    } else if (hour >= 12 && hour < 18) {
      return 'Magandang Hapon';
    } else {
      return 'Magandang Gabi';
    }
  }

  /// Returns localized greeting according to [localeCode] ('en', 'ceb', 'tl').
  static String getLocalizedGreeting({String? localeCode, DateTime? time}) {
    final code = (localeCode ?? 'en').toLowerCase();
    if (code.startsWith('ceb')) {
      return getCebuanoGreeting(time: time);
    } else if (code.startsWith('tl') || code.startsWith('fil')) {
      return getTagalogGreeting(time: time);
    }
    return getGreeting(time: time);
  }
}
