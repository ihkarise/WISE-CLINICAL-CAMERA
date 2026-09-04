import 'failures.dart';

/// Explicit success/failure return type.
///
/// Services return this instead of throwing so that a caller cannot ignore a
/// failure by accident, and so the UI always has a `Failure.userMessage` to show
/// rather than a raw exception (Build Specification sections 90-91).
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;
  const factory Result.failed(Failure failure) = Err<T>;

  bool get isOk => this is Ok<T>;
  bool get isFailure => this is Err<T>;

  /// The value, or null on failure.
  T? get valueOrNull => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>() => null,
  };

  /// The failure, or null on success.
  Failure? get failureOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final failure) => failure,
  };

  R fold<R>({
    required R Function(T value) onOk,
    required R Function(Failure failure) onFailure,
  }) => switch (this) {
    Ok<T>(:final value) => onOk(value),
    Err<T>(:final failure) => onFailure(failure),
  };

  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok<T>(:final value) => Ok<R>(transform(value)),
    Err<T>(:final failure) => Err<R>(failure),
  };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}
