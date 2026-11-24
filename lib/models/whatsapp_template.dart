/// نموذج قالب رسالة واتساب قابل للتخصيص
class WhatsAppTemplate {
  final String id;
  final String type; // confirm_deposit | ready | reminder | thanks
  final String tone; // warm | polite | formal
  final String title;
  final String body;
  final bool isDefault;

  const WhatsAppTemplate({
    required this.id,
    required this.type,
    this.tone = 'warm',
    required this.title,
    required this.body,
    this.isDefault = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'tone': tone,
      'title': title,
      'body': body,
      'isDefault': isDefault ? 1 : 0,
    };
  }

  factory WhatsAppTemplate.fromMap(Map<String, dynamic> map) {
    return WhatsAppTemplate(
      id: map['id'] as String,
      type: map['type'] as String,
      tone: (map['tone'] as String?) ?? 'warm',
      title: map['title'] as String,
      body: map['body'] as String,
      isDefault: (map['isDefault'] as num?)?.toInt() == 1,
    );
  }

  WhatsAppTemplate copyWith({
    String? id,
    String? type,
    String? tone,
    String? title,
    String? body,
    bool? isDefault,
  }) {
    return WhatsAppTemplate(
      id: id ?? this.id,
      type: type ?? this.type,
      tone: tone ?? this.tone,
      title: title ?? this.title,
      body: body ?? this.body,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
