class Result<T> {
  final T? value;
  final Object? error;

  const Result.ok(this.value) : error = null;
  const Result.err(this.error) : value = null;

  bool get isOk => error == null;
  bool get isErr => error != null;
}
