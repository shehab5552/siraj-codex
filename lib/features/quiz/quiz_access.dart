abstract interface class QuizAccessPort {
  Future<bool> isCurrent();
  Stream<bool> watchValidity();
}
