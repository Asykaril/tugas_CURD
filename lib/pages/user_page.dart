import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs.dart';
import '../widgets/user_avatar.dart';
import '../widgets/user_form_sheet.dart';

const double _maxContentWidth = 720;

class UserPage extends StatefulWidget {
  /// [service] bisa diisi untuk keperluan test (fake service).
  const UserPage({super.key, this.service});

  final UserService? service;

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  late final UserService _service = widget.service ?? UserService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<UserModel> _users = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  /// reqres.in adalah API demo: POST/PUT/DELETE tidak benar-benar menyimpan
  /// data. Karena itu hasil operasi diterapkan ke daftar lokal setelah server
  /// menjawab sukses, dan penanda ini dipakai untuk memperingatkan pengguna.
  bool _hasLocalChanges = false;

  final Set<int> _busyIds = {};
  final Set<int> _sessionCreatedIds = {};

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ data

  List<UserModel> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _users;
    return _users
        .where(
          (u) =>
              u.fullName.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _fetch() async {
    try {
      final users = await _service.getUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
        _error = null;
        _hasLocalChanges = false;
        _busyIds.clear();
        _sessionCreatedIds.clear();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      final hadData = _users.isNotEmpty;
      setState(() {
        _loading = false;
        if (!hadData) _error = e.message;
      });
      if (hadData) _toast(e.message, error: true);
    }
  }

  Future<void> _reload({required bool pull}) async {
    if (_hasLocalChanges) {
      final ok = await showConfirmDialog(
        context,
        title: 'Muat ulang data?',
        message:
            
            'Astgfirllah.',
        confirmLabel: 'Muat Ulang',
        icon: Icons.refresh_rounded,
      );
      if (!ok || !mounted) return;
    }

    if (!pull) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    await _fetch();
  }

  int _nextLocalId(int? serverId) {
    final taken = _users.map((u) => u.id).toSet();
    if (serverId != null && serverId > 0 && !taken.contains(serverId)) {
      return serverId;
    }
    final highest = taken.fold<int>(0, (m, e) => e > m ? e : m);
    return highest + 1;
  }

  // ------------------------------------------------------------------ CRUD

  Future<void> _openForm({UserModel? user}) async {
    String? doneMessage;

    await showUserFormSheet(
      context,
      user: user,
      existingUsers: _users,
      onSubmit: (data) async {
        final error =
            user == null ? await _createUser(data) : await _updateUser(user, data);
        if (error == null) {
          doneMessage = user == null
              ? '${data.fullName} berhasil ditambahkan'
              : 'Data ${data.fullName} berhasil diperbarui';
        }
        return error;
      },
    );

    final message = doneMessage;
    if (message != null && mounted) _toast(message);
  }

  Future<String?> _createUser(UserFormData data) async {
    try {
      final serverId = await _service.createUser(
        firstName: data.firstName,
        lastName: data.lastName,
        email: data.email,
      );
      if (!mounted) return null;

      final newUser = UserModel(
        id: _nextLocalId(serverId),
        email: data.email,
        firstName: data.firstName,
        lastName: data.lastName,
      );
      setState(() {
        _users = [newUser, ..._users];
        _sessionCreatedIds.add(newUser.id);
        _hasLocalChanges = true;
      });
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> _updateUser(UserModel old, UserFormData data) async {
    try {
      await _service.updateUser(
        old.id,
        firstName: data.firstName,
        lastName: data.lastName,
        email: data.email,
      );
    } on ApiException catch (e) {
      // User yang baru dibuat di sesi ini memang belum ada di server demo.
      final ignorable =
          e.statusCode == 404 && _sessionCreatedIds.contains(old.id);
      if (!ignorable) return e.message;
    }
    if (!mounted) return null;

    setState(() {
      final index = _users.indexWhere((u) => u.id == old.id);
      if (index != -1) {
        _users[index] = old.copyWith(
          firstName: data.firstName,
          lastName: data.lastName,
          email: data.email,
        );
      }
      _hasLocalChanges = true;
    });
    return null;
  }

  Future<void> _confirmDelete(UserModel user) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Hapus user?',
      message:
          '${user.fullName} (${user.email}) akan dihapus. '
          'Tindakan ini tidak bisa dibatalkan.',
      confirmLabel: 'Hapus',
      icon: Icons.delete_outline_rounded,
      destructive: true,
    );
    if (!ok || !mounted) return;

    setState(() => _busyIds.add(user.id));

    try {
      await _service.deleteUser(user.id);
    } on ApiException catch (e) {
      final ignorable =
          e.statusCode == 404 && _sessionCreatedIds.contains(user.id);
      if (!ignorable) {
        if (!mounted) return;
        setState(() => _busyIds.remove(user.id));
        await showErrorDialog(
          context,
          title: 'Gagal menghapus',
          message: e.message,
        );
        return;
      }
    }
    if (!mounted) return;

    setState(() {
      _users = _users.where((u) => u.id != user.id).toList();
      _busyIds.remove(user.id);
      _sessionCreatedIds.remove(user.id);
      _hasLocalChanges = true;
    });
    _toast('${user.fullName} berhasil dihapus');
  }

  // ------------------------------------------------------------------- UI

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? AppColors.danger : AppColors.success,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Row(
            children: [
              Icon(
                error
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          if (_hasLocalChanges) _buildNotice(),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                child: _buildBody(),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : () => _openForm(),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Tambah User'),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Manajemen User',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _loading
                                  ? 'Memuat data...'
                                  : '${_users.length} user terdaftar',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Muat ulang',
                        onPressed:
                            _loading ? null : () => _reload(pull: false),
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: 'Cari nama atau email',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Hapus pencarian',
                                onPressed: _clearSearch,
                                icon: const Icon(Icons.close_rounded),
                              ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotice() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4D6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 20, color: Color(0xFF8A5A00)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Perubahan hanya tersimpan sementara di aplikasi. API demo '
                  'tidak menyimpan data, jadi memuat ulang akan mengembalikan '
                  'data awal.',
                  style: TextStyle(color: Color(0xFF6B4500), fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _users.isEmpty) {
      return _StateMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Gagal memuat data',
        message: _error!,
        actionLabel: 'Coba Lagi',
        onAction: () => _reload(pull: false),
      );
    }

    if (_users.isEmpty) {
      return _StateMessage(
        icon: Icons.group_outlined,
        title: 'Belum ada user',
        message: 'Tambahkan user pertama dengan tombol di bawah.',
        actionLabel: 'Tambah User',
        onAction: () => _openForm(),
      );
    }

    final list = _filtered;
    if (list.isEmpty) {
      return _StateMessage(
        icon: Icons.search_off_rounded,
        title: 'Tidak ditemukan',
        message: 'Tidak ada user yang cocok dengan "$_query".',
        actionLabel: 'Hapus pencarian',
        onAction: _clearSearch,
      );
    }

    return RefreshIndicator(
      onRefresh: () => _reload(pull: true),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: list.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _buildUserCard(list[index]),
      ),
    );
  }

  Widget _buildUserCard(UserModel user) {
    final scheme = Theme.of(context).colorScheme;
    final busy = _busyIds.contains(user.id);
    final isNew = _sessionCreatedIds.contains(user.id);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: busy ? null : () => _openForm(user: user),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            children: [
              UserAvatar(user: user, radius: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isNew) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Baru',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: scheme.onTertiaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: () => _openForm(user: user),
                      icon: Icon(Icons.edit_outlined, color: scheme.primary),
                    ),
                    IconButton(
                      tooltip: 'Hapus',
                      onPressed: () => _confirmDelete(user),
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: scheme.error,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.tonal(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
