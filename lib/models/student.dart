enum StudentStatus { pending, picked, absent }

class Student {
  final String id;
  final String name;
  final String className;
  final String avatar;
  StudentStatus status;

  Student({
    required this.id,
    required this.name,
    required this.className,
    required this.avatar,
    this.status = StudentStatus.pending,
  });
}
