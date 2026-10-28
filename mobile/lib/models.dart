DateTime _dt(dynamic s) => DateTime.parse(s as String).toLocal();
DateTime _day(dynamic s) {
  final p = (s as String).split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

const goalLabels = {
  'weight_loss': "Vazn tashlash",
  'muscle_gain': "Mushak massasini oshirish",
  'stay_fit': "Formani saqlash",
  'healthy_lifestyle': "Sog'lom turmush tarzi",
  'reduce_stress': "Stressni kamaytirish",
  'more_energy': "Ko'proq energiyaga ega bo'lish",
  'general_fitness': "Umumiy jismoniy shakl",
  'strength': "Kuchni oshirish",
  'endurance': "Chidamlilik",
  'flexibility': "Egiluvchanlik",
  'active_lifestyle': "Faol turmush tarzi",
};
const setupGoals = ['weight_loss', 'muscle_gain', 'stay_fit', 'healthy_lifestyle', 'reduce_stress', 'more_energy'];
const activityLabels = {'sedentary': "Kam harakat", 'moderate': "O'rtacha", 'active': "Faol"};
const activityHints = {'sedentary': "ish, o'qish", 'moderate': "haftasiga 2-3 marta mashq", 'active': "haftasiga 4+ marta mashq"};
const levelLabels = {'beginner': "Boshlang'ich", 'intermediate': "O'rta", 'advanced': "Tajribali"};
const locationLabels = {'home': "Uy", 'gym': "Sport zali", 'outdoor': "Ochiq havo", 'mixed': "Aralash"};
const modeLabels = {'home': "Home", 'gym': "Gym", 'active': "Active"};
const _equipment = {
  'none': "Jihozsiz", 'mat': "Gilamcha", 'chair': "Stul", 'dumbbell': "Gantel", 'barbell': "Shtanga",
  'cable machine': "Blok trenajyor", 'machine': "Trenajyor", 'treadmill': "Yugurish yo'lakchasi",
  'stationary bike': "Velotrenajyor", 'elliptical': "Elliptik trenajyor",
};
String equipmentLabel(String e) => _equipment[e] ?? e;

class Me {
  Me.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        email = j['email'],
        fullName = j['full_name'],
        role = j['role'],
        profile = Map<String, dynamic>.from(j['profile'] ?? {}),
        settings = Map<String, dynamic>.from(j['settings'] ?? {}),
        profileCompleted = j['profile_completed'] ?? true;

  factory Me.defaultUser() => Me.fromJson({
        'id': 1,
        'email': 'foydalanuvchi@fithayot.uz',
        'full_name': 'FitHayot Foydalanuvchisi',
        'role': 'user',
        'profile': {
          'goal': 'general_fitness',
          'experience_level': 'beginner',
          'preferred_location': 'home',
          'daily_minutes': 30,
          'height_cm': 175.0,
          'weight_kg': 70.0,
          'birth_year': 2000,
          'gender': 'prefer_not_to_say',
        },
        'settings': {
          'language_code': 'uz',
          'reminders_enabled': true,
        },
        'profile_completed': true,
      });

  final int id;
  final String email, role;
  final String? fullName;
  final Map<String, dynamic> profile, settings;
  final bool profileCompleted;
}

class Exercise {
  Exercise.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        title = j['title'],
        description = j['description'] ?? '',
        equipment = j['equipment'] ?? 'none',
        difficulty = j['difficulty'] ?? 'beginner',
        safetyNote = j['safety_note'] ?? '',
        durationHint = j['duration_hint'],
        mediaUrl = j['media_url'],
        mode = (j['mode'] ?? (j['category'] as Map?)?['mode'] ?? 'home') as String;
  final int id;
  final String title, description, equipment, difficulty, safetyNote, mode;
  final String? durationHint, mediaUrl;
}

class PlanItem {
  PlanItem.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        date = _day(j['planned_date']),
        minutes = j['planned_minutes'],
        exercise = Exercise.fromJson(Map<String, dynamic>.from(j['exercise'])),
        isCompleted = j['is_completed'] ?? false;
  final int id, minutes;
  final DateTime date;
  final Exercise exercise;
  final bool isCompleted;
}

class Plan {
  Plan.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        title = j['title'],
        startsOn = _day(j['starts_on']),
        endsOn = _day(j['ends_on']),
        status = j['status'],
        items = ((j['items'] ?? []) as List).map((e) => PlanItem.fromJson(Map<String, dynamic>.from(e))).toList();
  final int id;
  final String title, status;
  final DateTime startsOn, endsOn;
  final List<PlanItem> items;
  bool covers(DateTime d) {
    final x = DateTime(d.year, d.month, d.day);
    return !x.isBefore(startsOn) && !x.isAfter(endsOn);
  }
}

class LogEntry {
  LogEntry.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        exercise = Exercise.fromJson(Map<String, dynamic>.from(j['exercise'])),
        planItemId = j['plan_item_id'],
        setNo = j['set_no'],
        reps = j['reps'],
        weightKg = (j['weight_kg'] as num?)?.toDouble(),
        durationSeconds = j['duration_seconds'];
  final int id, setNo;
  final Exercise exercise;
  final int? planItemId, reps, durationSeconds;
  final double? weightKg;

  String get summary {
    final parts = <String>[];
    if (reps != null) parts.add('$reps takror');
    if (weightKg != null) parts.add('${weightKg!.toStringAsFixed(weightKg! % 1 == 0 ? 0 : 1)} kg');
    if (durationSeconds != null) parts.add('$durationSeconds soniya');
    return "$setNo-yondashuv: ${parts.join(' · ')}";
  }
}

class Session {
  Session.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        mode = j['mode'],
        status = j['status'],
        planId = j['plan_id'],
        startedAt = _dt(j['started_at']),
        finishedAt = j['finished_at'] == null ? null : _dt(j['finished_at']),
        durationMinutes = j['duration_minutes'],
        notes = j['notes'],
        logs = ((j['logs'] ?? []) as List).map((e) => LogEntry.fromJson(Map<String, dynamic>.from(e))).toList();
  final int id;
  final String mode, status;
  final int? planId, durationMinutes;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final String? notes;
  final List<LogEntry> logs;
}

class ActivityType {
  ActivityType.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        code = j['code'],
        title = j['title'];
  final int id;
  final String code, title;
}

class Activity {
  Activity.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        type = ActivityType.fromJson(Map<String, dynamic>.from(j['activity_type'])),
        occurredAt = _dt(j['occurred_at']),
        minutes = j['duration_minutes'],
        distanceKm = (j['distance_km'] as num?)?.toDouble(),
        note = j['note'];
  final int id, minutes;
  final ActivityType type;
  final DateTime occurredAt;
  final double? distanceKm;
  final String? note;
}

class DayStat {
  DayStat.fromJson(Map<String, dynamic> j)
      : date = _day(j['date']),
        minutes = j['minutes'],
        sessions = j['sessions'],
        activities = j['activities'];
  final DateTime date;
  final int minutes, sessions, activities;
}

class Weekly {
  Weekly.fromJson(Map<String, dynamic> j)
      : weekStart = _day(j['week_start']),
        weekEnd = _day(j['week_end']),
        totalSessions = j['total_sessions'],
        totalActivityEntries = j['total_activity_entries'],
        totalMinutes = j['total_active_minutes'],
        byModule = Map<String, int>.from(j['minutes_by_module']),
        planned = j['planned_items'],
        completed = j['completed_items'],
        rate = (j['planned_completion_rate'] as num?)?.toDouble(),
        days = (j['days'] as List).map((e) => DayStat.fromJson(Map<String, dynamic>.from(e))).toList();
  final DateTime weekStart, weekEnd;
  final int totalSessions, totalActivityEntries, totalMinutes, planned, completed;
  final Map<String, int> byModule;
  final double? rate; // null => "N/A"
  final List<DayStat> days;
  String get rateLabel => rate == null ? 'N/A' : '${rate!.toStringAsFixed(rate! % 1 == 0 ? 0 : 1)}%';
}

class HistoryItem {
  HistoryItem.fromJson(Map<String, dynamic> j)
      : kind = j['kind'],
        id = j['id'],
        module = j['module'],
        title = j['title'],
        occurredAt = _dt(j['occurred_at']),
        minutes = j['duration_minutes'],
        distanceKm = (j['distance_km'] as num?)?.toDouble(),
        detail = j['detail'];
  final String kind, module, title;
  final int id;
  final DateTime occurredAt;
  final int? minutes;
  final double? distanceKm;
  final String? detail;
}
