/// A knowledge area within a category, such as grammar or async/await.
class Topic {
  const Topic({required this.id, required this.categoryId, required this.name});

  final String id;
  final String categoryId;
  final String name;
}
