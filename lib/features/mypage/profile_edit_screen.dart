import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common.dart';

/// 회원정보 수정
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _postcodeCtrl = TextEditingController();
  final _addr1Ctrl = TextEditingController();
  final _addr2Ctrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pwConfirmCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    if (user != null) {
      _nameCtrl.text = user.name;
      _phoneCtrl.text = user.phone ?? '';
      _postcodeCtrl.text = user.postcode ?? '';
      _addr1Ctrl.text = user.address1 ?? '';
      _addr2Ctrl.text = user.address2 ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _postcodeCtrl.dispose();
    _addr1Ctrl.dispose();
    _addr2Ctrl.dispose();
    _pwCtrl.dispose();
    _pwConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'postcode': _postcodeCtrl.text.trim(),
      'address1': _addr1Ctrl.text.trim(),
      'address2': _addr2Ctrl.text.trim(),
    };
    if (_pwCtrl.text.isNotEmpty) {
      data['password'] = _pwCtrl.text;
      data['password_confirmation'] = _pwConfirmCtrl.text;
    }
    try {
      await ref.read(apiProvider).put('/mypage/profile', data: data);
      await ref.read(authProvider.notifier).refresh();
      if (!mounted) return;
      toast(context, '회원정보가 수정되었습니다.');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      toast(context, e is ApiException ? e.firstError : '수정에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.read(authProvider).user;
    final isBusiness = user?.isWholesale ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('회원정보 수정')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // 이메일(읽기전용)
              _sectionTitle('기본 정보'),
              _readonlyTile('이메일', user?.email ?? '', Icons.mail_outline),
              const SizedBox(height: 12),
              _field(_nameCtrl, '이름', hint: '이름을 입력하세요', validator: (v) {
                if ((v ?? '').trim().isEmpty) return '이름을 입력해주세요.';
                return null;
              }),
              const SizedBox(height: 12),
              _field(_phoneCtrl, '휴대전화', hint: '숫자만 입력', keyboard: TextInputType.phone),

              const SizedBox(height: 22),
              _sectionTitle('배송지'),
              _field(_postcodeCtrl, '우편번호', hint: '우편번호', keyboard: TextInputType.number),
              const SizedBox(height: 12),
              _field(_addr1Ctrl, '기본주소', hint: '기본주소'),
              const SizedBox(height: 12),
              _field(_addr2Ctrl, '상세주소', hint: '상세주소'),

              if (isBusiness) ...[
                const SizedBox(height: 22),
                _sectionTitle('사업자 정보'),
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text('사업자 정보는 수정할 수 없습니다. 변경이 필요하면 고객센터로 문의해주세요.',
                      style: TextStyle(fontSize: 12, color: AppColors.sub)),
                ),
                _readonlyTile('상호명', user?.companyName ?? '-', Icons.business_outlined),
                const SizedBox(height: 12),
                _readonlyTile('사업자등록번호', user?.bizNo ?? '-', Icons.badge_outlined),
                const SizedBox(height: 12),
                _readonlyTile('업종', user?.bizType ?? '-', Icons.category_outlined),
              ],

              const SizedBox(height: 22),
              _sectionTitle('비밀번호 변경'),
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text('변경 시에만 입력하세요.', style: TextStyle(fontSize: 12, color: AppColors.sub)),
              ),
              _field(
                _pwCtrl,
                '새 비밀번호',
                hint: '8자 이상',
                obscure: true,
                validator: (v) {
                  final s = v ?? '';
                  if (s.isEmpty) return null;
                  if (s.length < 8) return '비밀번호는 8자 이상이어야 합니다.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _field(
                _pwConfirmCtrl,
                '새 비밀번호 확인',
                hint: '비밀번호를 다시 입력',
                obscure: true,
                validator: (v) {
                  if (_pwCtrl.text.isEmpty) return null;
                  if ((v ?? '') != _pwCtrl.text) return '비밀번호가 일치하지 않습니다.';
                  return null;
                },
              ),

              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    : const Text('저장하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    String? hint,
    bool obscure = false,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboard,
      validator: validator,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }

  Widget _readonlyTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.chip,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.sub),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.sub, fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
