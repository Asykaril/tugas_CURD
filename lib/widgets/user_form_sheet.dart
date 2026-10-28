import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/user_model.dart';
import '../utils/validators.dart';
import 'dialogs.dart';

class UserFormData {
  const UserFormData({
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  final String firstName;
  final String lastName;
  final String email;

  String get fullName => '$firstName $lastName'.trim();
}

/// Membuka form tambah (user == null) atau edit (user != null).
///
/// [onSubmit] dipanggil setelah semua validasi lolos. Kembalikan `null`
/// jika sukses (sheet akan menutup), atau pesan error (sheet tetap terbuka
/// dan datanya tidak hilang).
Future<void> showUserFormSheet(
  BuildContext context, {
  UserModel? user,
  required List<UserModel> existingUsers,
  required Future<String?> Function(UserFormData data) onSubmit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: false,
    constraints: const BoxConstraints(maxWidth: 560),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => UserFormSheet(
      user: user,
      existingUsers: existingUsers,
      onSubmit: onSubmit,
    ),
  );
}

class UserFormSheet extends StatefulWidget {
  const UserFormSheet({
    super.key,
    this.user,
    required this.existingUsers,
    required this.onSubmit,
  });

  final UserModel? user;
  final List<UserModel> existingUsers;
  final Future<String?> Function(UserFormData data) onSubmit;

  @override
  State<UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends State<UserFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstCtrl;
  late final TextEditingController _lastCtrl;
  late final TextEditingController _emailCtrl;

  late final String _initFirst;
  late final String _initLast;
  late final String _initEmail;

  bool _saving = false;
  String? _formError;

  bool get _isEdit => widget.user != null;

  bool get _isDirty =>
      _firstCtrl.text.trim() != _initFirst ||
      _lastCtrl.text.trim() != _initLast ||
      _emailCtrl.text.trim() != _initEmail;

  @override
  void initState() {
    super.initState();
    _initFirst = widget.user?.firstName ?? '';
    _initLast = widget.user?.lastName ?? '';
    _initEmail = widget.user?.email ?? '';

    _firstCtrl = TextEditingController(text: _initFirst);
    _lastCtrl = TextEditingController(text: _initLast);
    _emailCtrl = TextEditingController(text: _initEmail);

    _firstCtrl.addListener(_onChanged);
    _lastCtrl.addListener(_onChanged);
    _emailCtrl.addListener(_onChanged);
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() => _formError = null);
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  String? _duplicateEmailError(String email) {
    final lower = email.toLowerCase();
    for (final u in widget.existingUsers) {
      if (u.id != widget.user?.id && u.email.toLowerCase() == lower) {
        return 'Email ini sudah dipakai oleh ${u.fullName}';
      }
    }
    return null;
  }

  Future<void> _requestClose() async {
    if (_saving) return;
    if (!_isDirty) {
      Navigator.of(context).pop();
      return;
    }

    final discard = await showConfirmDialog(
      context,
      title: 'Buang perubahan?',
      message: 'Data yang sudah kamu isi belum disimpan dan akan hilang.',
      confirmLabel: 'Buang',
      cancelLabel: 'Lanjut mengisi',
      icon: Icons.warning_amber_rounded,
      destructive: true,
    );
    if (discard && mounted) Navigator.of(context).pop();
  }

  Future<void> _submit() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() => _formError = null);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final data = UserFormData(
      firstName: _firstCtrl.text.trim(),
      lastName: _lastCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
    );

    if (_isEdit) {
      if (!_isDirty) {
        setState(() => _formError = 'Belum ada perubahan data untuk disimpan.');
        return;
      }

      final confirmed = await showConfirmDialog(
        context,
        title: 'Simpan perubahan?',
        message: 'Data ${widget.user!.fullName} akan diperbarui.',
        confirmLabel: 'Simpan',
        icon: Icons.save_outlined,
      );
      if (!confirmed || !mounted) return;
    }

    setState(() => _saving = true);
    final error = await widget.onSubmit(data);
    if (!mounted) return;

    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _formError = error;
      });
    }
  }

  InputDecoration _decoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    final scheme = Theme.of(context).colorScheme;
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      border: border(scheme.outlineVariant),
      enabledBorder: border(scheme.outlineVariant),
      disabledBorder: border(scheme.outlineVariant),
      focusedBorder: border(scheme.primary, 2),
      errorBorder: border(scheme.error),
      focusedErrorBorder: border(scheme.error, 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: !_saving && !_isDirty,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _saving) return;
        _requestClose();
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _isEdit
                            ? Icons.edit_outlined
                            : Icons.person_add_alt_1_rounded,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEdit ? 'Edit User' : 'Tambah User Baru',
                            style: textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            _isEdit
                                ? 'Perbarui data lalu simpan'
                                : 'Isi data user dengan benar',
                            style: textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tutup',
                      onPressed: _saving ? null : _requestClose,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (_formError != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 20,
                          color: scheme.onErrorContainer,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _formError!,
                            style: TextStyle(color: scheme.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                TextFormField(
                  controller: _firstCtrl,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  inputFormatters: [LengthLimitingTextInputFormatter(30)],
                  decoration: _decoration(
                    label: 'Nama depan',
                    hint: 'Contoh: Budi',
                    icon: Icons.person_outline_rounded,
                  ),
                  validator: Validators.firstName,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _lastCtrl,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  inputFormatters: [LengthLimitingTextInputFormatter(30)],
                  decoration: _decoration(
                    label: 'Nama belakang (opsional)',
                    hint: 'Contoh: Santoso',
                    icon: Icons.badge_outlined,
                  ),
                  validator: Validators.lastName,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailCtrl,
                  enabled: !_saving,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  enableSuggestions: false,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  ],
                  onFieldSubmitted: (_) => _submit(),
                  decoration: _decoration(
                    label: 'Email',
                    hint: 'nama@gmail.com',
                    icon: Icons.alternate_email_rounded,
                  ),
                  validator: (value) =>
                      Validators.email(value) ??
                      _duplicateEmailError((value ?? '').trim()),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : _requestClose,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _isEdit
                                    ? Icons.save_outlined
                                    : Icons.check_rounded,
                              ),
                        label: Text(
                          _saving
                              ? 'Menyimpan...'
                              : (_isEdit ? 'Simpan Perubahan' : 'Simpan'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
