class Validators {
  Validators._();

  static final RegExp _namePattern =
      RegExp(r"^[\p{L}][\p{L}\s'.\-]*$", unicode: true);

  static final RegExp _emailPattern = RegExp(
    r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$',
  );

  static String? firstName(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Nama depan wajib diisi';
    if (v.length < 2) return 'Nama depan minimal 2 karakter';
    if (!_namePattern.hasMatch(v)) {
      return 'Nama hanya boleh berisi huruf (tanpa angka atau simbol)';
    }
    return null;
  }

  /// Nama belakang opsional, tapi kalau diisi harus valid.
  static String? lastName(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    if (!_namePattern.hasMatch(v)) {
      return 'Nama belakang hanya boleh berisi huruf';
    }
    return null;
  }

  static String? email(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Email wajib diisi';
    if (v.contains(RegExp(r'\s'))) return 'Email tidak boleh mengandung spasi';
    if (!v.contains('@')) {
      return 'Email harus mengandung tanda @ (contoh: nama@gmail.com)';
    }
    if ('@'.allMatches(v).length > 1) {
      return 'Email hanya boleh memiliki satu tanda @';
    }

    final parts = v.split('@');
    final local = parts[0];
    final domain = parts[1];
    if (local.isEmpty) return 'Tulis nama email sebelum tanda @';
    if (domain.isEmpty) {
      return 'Tulis domain setelah tanda @ (contoh: gmail.com)';
    }
    if (!domain.contains('.')) {
      return 'Domain harus memiliki titik (contoh: gmail.com)';
    }
    if (!_emailPattern.hasMatch(v)) return 'Format email tidak valid';
    return null;
  }
}
