/// Lightweight Result<T> sum type for service-layer returns.
/// Avoids throwing for *expected* failures (e.g. wrong password) while still
/// letting unexpected exceptions propagate.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get valueOrNull => switch (this) {
        Success<T>(value: final v) => v,
        Failure<T>() => null,
      };

  R when<R>({
    required R Function(T value) success,
    required R Function(String message, Object? error) failure,
  }) {
    return switch (this) {
      Success<T>(value: final v) => success(v),
      Failure<T>(message: final m, error: final e) => failure(m, e),
    };
  }
}

class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

class Failure<T> extends Result<T> {
  const Failure(this.message, [this.error]);
  final String message;
  final Object? error;
}
