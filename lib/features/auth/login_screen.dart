import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common.dart';

/// 로그인 화면
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).login(
            _emailCtrl.text.trim(),
            _pwCtrl.text,
          );
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    } catch (e) {
      if (!mounted) return;
      toast(context, e is ApiException ? e.firstError : '로그인에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fill(String email, String pw) {
    _emailCtrl.text = email;
    _pwCtrl.text = pw;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                // 브랜드 헤더
                Center(
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/brand/logo_stacked.png',
                        height: 128,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (_, _, _) => const Text(
                          '망고샵',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: AppColors.brand,
                            letterSpacing: -1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '수입 과일 도매·소매 오픈마켓',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.sub,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '이메일',
                    hintText: 'example@mangoshop.com',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
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
                  controller: _pwCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: '비밀번호',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? '비밀번호를 입력해주세요.' : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : const Text('로그인'),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('아직 회원이 아니신가요?', style: TextStyle(color: AppColors.sub)),
                    TextButton(
                      onPressed: () => context.push('/register'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.navy),
                      child: const Text('회원가입', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _demoHint(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _demoHint() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.chip,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline, size: 18, color: AppColors.navy),
              SizedBox(width: 6),
              Text('데모 계정', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy)),
            ],
          ),
          const SizedBox(height: 10),
          _demoRow('도매회원', 'buyer@test.com', 'test1234'),
          const SizedBox(height: 6),
          _demoRow('소매회원', 'user@test.com', 'test1234'),
          const SizedBox(height: 4),
          const Text(
            '탭하면 자동으로 입력됩니다.',
            style: TextStyle(fontSize: 11, color: AppColors.sub),
          ),
        ],
      ),
    );
  }

  Widget _demoRow(String label, String email, String pw) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _fill(email, pw),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$email / $pw',
                style: const TextStyle(fontSize: 12.5, color: AppColors.ink),
              ),
            ),
            const Icon(Icons.touch_app_outlined, size: 16, color: AppColors.sub),
          ],
        ),
      ),
    );
  }
}
