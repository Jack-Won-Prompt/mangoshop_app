import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common.dart';

/// 회원가입 화면 (소매회원 / 도매회원)
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _pwConfirm = TextEditingController();
  final _phone = TextEditingController();
  final _company = TextEditingController();
  final _bizNo = TextEditingController();
  final _bizType = TextEditingController();

  bool _business = false; // false=소매, true=도매(사업자)
  bool _agree = false;
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pw.dispose();
    _pwConfirm.dispose();
    _phone.dispose();
    _company.dispose();
    _bizNo.dispose();
    _bizType.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agree) {
      toast(context, '이용약관에 동의해주세요.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final data = <String, dynamic>{
        'member_type': _business ? 'business' : 'general',
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'password': _pw.text,
        'password_confirmation': _pwConfirm.text,
        'phone': _phone.text.trim(),
      };
      if (_business) {
        data['company_name'] = _company.text.trim();
        data['biz_no'] = _bizNo.text.trim();
        data['biz_type'] = _bizType.text.trim();
      }
      await ref.read(authProvider.notifier).register(data);
      if (!mounted) return;
      toast(context, '회원가입이 완료되었습니다.');
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    } catch (e) {
      if (!mounted) return;
      toast(context, e is ApiException ? e.firstError : '회원가입에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _segmented(),
                const SizedBox(height: 16),
                _pointNotice(),
                const SizedBox(height: 20),
                _label('기본 정보'),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: '이름', prefixIcon: Icon(Icons.person_outline)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? '이름을 입력해주세요.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: '이메일', prefixIcon: Icon(Icons.mail_outline)),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return '이메일을 입력해주세요.';
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) {
                      return '올바른 이메일 형식이 아닙니다.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pw,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: '비밀번호 (8자 이상)',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return '비밀번호를 입력해주세요.';
                    if (v.length < 8) return '비밀번호는 8자 이상이어야 합니다.';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pwConfirm,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: '비밀번호 확인', prefixIcon: Icon(Icons.lock_outline)),
                  validator: (v) {
                    if (v == null || v.isEmpty) return '비밀번호를 다시 입력해주세요.';
                    if (v != _pw.text) return '비밀번호가 일치하지 않습니다.';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: '휴대폰 번호', prefixIcon: Icon(Icons.phone_outlined)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? '휴대폰 번호를 입력해주세요.' : null,
                ),
                if (_business) ...[
                  const SizedBox(height: 24),
                  _label('사업자 정보'),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _company,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: '상호(사업자명)', prefixIcon: Icon(Icons.storefront_outlined)),
                    validator: (v) =>
                        _business && (v == null || v.trim().isEmpty) ? '상호(사업자명)을 입력해주세요.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _bizNo,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '사업자등록번호',
                      hintText: '000-00-00000',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: (v) =>
                        _business && (v == null || v.trim().isEmpty) ? '사업자등록번호를 입력해주세요.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _bizType,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: '업종 (선택)',
                      hintText: '예: 농수산물 도소매, 식자재유통',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _agreeBox(),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : const Text('가입하기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _segmented() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.chip,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _segItem('소매회원', !_business, () => setState(() => _business = false)),
          _segItem('도매회원', _business, () => setState(() => _business = true)),
        ],
      ),
    );
  }

  Widget _segItem(String text, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.navy : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: active ? Colors.white : AppColors.sub,
            ),
          ),
        ),
      ),
    );
  }

  Widget _pointNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.redSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: const [
          Icon(Icons.card_giftcard, color: AppColors.red, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '지금 가입하면 3,000원 적립금을 드려요!',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink),
      );

  Widget _agreeBox() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _agree = !_agree),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _agree ? AppColors.navy : AppColors.line),
        ),
        child: Row(
          children: [
            Icon(
              _agree ? Icons.check_circle : Icons.circle_outlined,
              color: _agree ? AppColors.navy : AppColors.sub,
              size: 22,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '이용약관 및 개인정보 처리방침에 동의합니다. (필수)',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
