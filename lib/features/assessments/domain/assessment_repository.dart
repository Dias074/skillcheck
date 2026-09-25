import 'models/category.dart';
import 'models/question.dart';

abstract interface class AssessmentRepository {
  Future<List<Category>> fetchCategories();
  Future<List<Question>> fetchQuestions(String categoryId);
}
