import 'api/api_client.dart';
import 'api/auth_service.dart';
import 'api/category_service.dart';
import 'api/explanation_service.dart';
import 'api/leaderboard_service.dart';
import 'api/model_answer_service.dart';
import 'api/ocr_service.dart';
import 'api/problem_service.dart';
import 'api/review_service.dart';
import 'api/user_service.dart';

class Api {
  Api._();

  static String get base => ApiClient.base;
  static String? get token => ApiClient.token;

  static void setToken(String value) => ApiClient.setToken(value);
  static void clearToken() => ApiClient.clearToken();

  static final auth = AuthService();
  static final users = UserService();
  static final categories = CategoryService();
  static final problems = ProblemService();
  static final explanations = ExplanationService();
  static final modelAnswers = ModelAnswerService();
  static final review = ReviewService();
  static final leaderboard = LeaderboardService();
  static final ocr = OcrService();
}
