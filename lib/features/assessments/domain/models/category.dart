/// An assessment subject, independent of its UI icon or backend representation.
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.description,
  });

  final String id;
  final String name;
  final String description;
}
