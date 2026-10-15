class Toda {
  final String id;
  final String code;
  final String name;
  final String leader;
  final String contact;
  final String area;
  final bool active;
  final DateTime createdAt;

  const Toda({
    required this.id,
    this.code = '',
    required this.name,
    this.leader = '',
    this.contact = '',
    this.area = '',
    this.active = true,
    required this.createdAt,
  });

  Toda copyWith({
    String? code,
    String? name,
    String? leader,
    String? contact,
    String? area,
    bool? active,
  }) {
    return Toda(
      id: id,
      code: code ?? this.code,
      name: name ?? this.name,
      leader: leader ?? this.leader,
      contact: contact ?? this.contact,
      area: area ?? this.area,
      active: active ?? this.active,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'code': code,
        'name': name,
        'leader': leader,
        'contact': contact,
        'area': area,
        'active': active ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Toda.fromMap(Map<String, Object?> map) => Toda(
        id: map['id'] as String,
        code: (map['code'] as String?) ?? '',
        name: map['name'] as String,
        leader: (map['leader'] as String?) ?? '',
        contact: (map['contact'] as String?) ?? '',
        area: (map['area'] as String?) ?? '',
        active: (map['active'] as int? ?? 1) == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (map['created_at'] as int?) ?? 0,
        ),
      );
}

class LguPartnership {
  final String id;
  final String name;
  final List<String> todaIds;
  final bool active;
  final DateTime createdAt;

  const LguPartnership({
    required this.id,
    required this.name,
    this.todaIds = const [],
    this.active = true,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'toda_ids': todaIds.join(','),
        'active': active ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory LguPartnership.fromMap(Map<String, Object?> map) => LguPartnership(
        id: map['id'] as String,
        name: map['name'] as String,
        todaIds: ((map['toda_ids'] as String?) ?? '')
            .split(',')
            .where((e) => e.isNotEmpty)
            .toList(),
        active: (map['active'] as int? ?? 1) == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (map['created_at'] as int?) ?? 0,
        ),
      );
}
