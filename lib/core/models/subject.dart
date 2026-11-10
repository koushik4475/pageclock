class Subject {
  final String id;
  final String name;
  final String color;
  final bool archived;

  const Subject({
    required this.id,
    required this.name,
    required this.color,
    this.archived = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'color': color,
        'archived': archived,
      };

  factory Subject.fromMap(Map<String, dynamic> map) => Subject(
        id: map['id'] as String,
        name: map['name'] as String,
        color: map['color'] as String,
        archived: map['archived'] as bool? ?? false,
      );
}
