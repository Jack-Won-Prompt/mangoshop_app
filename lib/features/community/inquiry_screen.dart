import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common.dart';

/// 문의 작성 화면 — 견적/1:1/상품요청
class InquiryScreen extends ConsumerStatefulWidget {
  final String? type;
  final String? product; // 견적문의 대상 상품명 (자동 첨부)
  const InquiryScreen({super.key, this.type, this.product});

  @override
  ConsumerState<InquiryScreen> createState() => _InquiryScreenState();
}

class _InquiryScreenState extends ConsumerState<InquiryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  static const _types = [
    ('quote', '견적문의'),
    ('qna', '1:1문의'),
    ('request', '상품요청'),
  ];

  late String _type;
  bool _isSecret = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _type = _types.any((t) => t.$1 == widget.type) ? widget.type! : 'qna';
    // 견적문의로 진입 + 상품명이 있으면 제목/본문 자동 첨부
    if (widget.product != null && widget.product!.isNotEmpty) {
      _subjectCtrl.text = '[견적문의] ${widget.product}';
      _bodyCtrl.text = '상품: ${widget.product}\n수량:\n문의내용:\n';
    }
    final user = ref.read(authProvider).user;
    if (user != null) {
      _nameCtrl.text = user.name;
      if (user.phone != null) _phoneCtrl.text = user.phone!;
      _emailCtrl.text = user.email;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await ref.read(apiProvider).post('/community/inquiry', data: {
        'type': _type,
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'subject': _subjectCtrl.text.trim(),
        'body': _bodyCtrl.text.trim(),
        'is_secret': _isSecret,
      });
      if (!mounted) return;
      toast(context, '문의가 접수되었습니다.');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      toast(context, e is ApiException ? e.firstError : '오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('문의하기')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                _label('문의 유형'),
                const SizedBox(height: 8),
                _typeSelector(),
                const SizedBox(height: 20),
                _label('이름'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(hintText: '이름을 입력해주세요'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? '이름을 입력해주세요.' : null,
                ),
                const SizedBox(height: 16),
                _label('연락처'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(hintText: '010-0000-0000'),
                ),
                const SizedBox(height: 16),
                _label('이메일'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'example@mangoshop.com'),
                ),
                const SizedBox(height: 16),
                _label('제목'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _subjectCtrl,
                  decoration: const InputDecoration(hintText: '제목을 입력해주세요'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? '제목을 입력해주세요.' : null,
                ),
                const SizedBox(height: 16),
                _label('문의 내용'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _bodyCtrl,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    hintText: '문의하실 내용을 자세히 적어주세요',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? '문의 내용을 입력해주세요.' : null,
                ),
                const SizedBox(height: 12),
                _secretCheckbox(),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : const Text('문의 접수'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) =>
      Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700));

  Widget _typeSelector() {
    return Row(
      children: [
        for (final t in _types) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _type = t.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: _type == t.$1 ? AppColors.navy : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _type == t.$1 ? AppColors.navy : AppColors.line),
                ),
                alignment: Alignment.center,
                child: Text(
                  t.$2,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _type == t.$1 ? Colors.white : AppColors.sub,
                  ),
                ),
              ),
            ),
          ),
          if (t != _types.last) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _secretCheckbox() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _isSecret = !_isSecret),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.chip,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Icon(
              _isSecret ? Icons.check_box : Icons.check_box_outline_blank,
              color: _isSecret ? AppColors.navy : AppColors.sub,
              size: 22,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('비밀글로 문의하기',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            const Text('🔒', style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
