import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/user_model.dart';

/// Error dari lapisan API dengan pesan yang sudah ramah dibaca pengguna.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class UserService {
  static const String _baseUrl = 'https://reqres.in/api/users';

  // Ganti dengan API key milikmu dari https://app.reqres.in jika key ini
  // ditolak (error 401/403).
  static const String _apiKey = 'reqres-free-v1';

  static const Duration _timeout = Duration(seconds: 15);

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'x-api-key': _apiKey,
  };

  /// READ: ambil daftar user.
  Future<List<UserModel>> getUsers() async {
    final response = await _send(
      () => http.get(
        Uri.parse('$_baseUrl?page=1&per_page=12'),
        headers: _headers,
      ),
    );
    _ensureStatus(response, const [200], 'Gagal mengambil data user');

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final list = body['data'] as List<dynamic>;
      return list
          .map((item) => UserModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      throw const ApiException('Format data dari server tidak sesuai.');
    }
  }

  /// CREATE: tambah user baru. Mengembalikan id dari server (jika ada).
  Future<int?> createUser({
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    final response = await _send(
      () => http.post(
        Uri.parse(_baseUrl),
        headers: _headers,
        body: jsonEncode({
          'name': '$firstName $lastName'.trim(),
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
        }),
      ),
    );
    _ensureStatus(response, const [200, 201], 'Gagal menambahkan user');

    final body = _tryDecode(response.body);
    return body is Map ? int.tryParse('${body['id']}') : null;
  }

  /// UPDATE: ubah data user.
  Future<void> updateUser(
    int id, {
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    final response = await _send(
      () => http.put(
        Uri.parse('$_baseUrl/$id'),
        headers: _headers,
        body: jsonEncode({
          'name': '$firstName $lastName'.trim(),
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
        }),
      ),
    );
    _ensureStatus(response, const [200], 'Gagal mengubah user');
  }

  /// DELETE: hapus user.
  Future<void> deleteUser(int id) async {
    final response = await _send(
      () => http.delete(Uri.parse('$_baseUrl/$id'), headers: _headers),
    );
    _ensureStatus(response, const [200, 202, 204], 'Gagal menghapus user');
  }

  // ---------------------------------------------------------------- helpers

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_timeout);
    } on TimeoutException {
      throw const ApiException(
        'Koneksi timeout. Periksa internet kamu lalu coba lagi.',
      );
    } catch (_) {
      throw const ApiException(
        'Tidak dapat terhubung ke server. Periksa koneksi internet kamu.',
      );
    }
  }

  void _ensureStatus(http.Response response, List<int> ok, String fallback) {
    if (ok.contains(response.statusCode)) return;
    throw ApiException(
      _messageFor(response.statusCode, fallback),
      statusCode: response.statusCode,
    );
  }

  String _messageFor(int code, String fallback) {
    if (code == 401 || code == 403) {
      return 'Akses ditolak server (API key tidak valid atau kedaluwarsa).';
    }
    if (code == 404) return 'Data tidak ditemukan di server.';
    if (code == 429) return 'Terlalu banyak permintaan. Coba lagi sebentar.';
    if (code >= 500) return 'Server sedang bermasalah (kode $code).';
    return '$fallback (kode $code).';
  }

  dynamic _tryDecode(String source) {
    try {
      return jsonDecode(source);
    } catch (_) {
      return null;
    }
  }
}
