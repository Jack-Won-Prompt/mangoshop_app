import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common.dart';

/// 실시간 1:1 상담 화면 (Pusher)
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scroll = ScrollController();
  final _inputCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  final List<Map> _messages = [];
  String? _roomToken;
  bool _hasContact = false;
  bool _loading = true;
  bool _sending = false;
  bool _starting = false;
  Object? _error;

  PusherChannelsFlutter? _pusher;
  String? _channelName;

  @override
  void initState() {
    super.initState();
    // 로그인 상태에서만 실제 초기화 진행
    if (ref.read(authProvider).isLoggedIn) {
      _open();
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _inputCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _teardownPusher();
    super.dispose();
  }

  Future<void> _open() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiProvider).get('/chat/open');
      if (!mounted) return;
      _roomToken = res['room_token']?.toString();
      _hasContact = res['has_contact'] == true || res['has_contact'] == 1;
      if ((res['name']?.toString() ?? '').isNotEmpty) _nameCtrl.text = res['name'].toString();
      if ((res['phone']?.toString() ?? '').isNotEmpty) _phoneCtrl.text = res['phone'].toString();
      _messages
        ..clear()
        ..addAll(((res['messages'] as List?) ?? []).map((e) => e as Map));
      final pusher = res['pusher'] is Map ? res['pusher'] as Map : null;
      setState(() => _loading = false);
      _scrollToBottom();
      if (pusher != null && _roomToken != null) {
        await _initPusher(pusher['key']?.toString(), pusher['cluster']?.toString());
      }
    } catch (e) {
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _initPusher(String? key, String? cluster) async {
    if (key == null || key.isEmpty || cluster == null || cluster.isEmpty) return;
    _channelName = 'chat-$_roomToken';
    try {
      final pusher = PusherChannelsFlutter.getInstance();
      await pusher.init(apiKey: key, cluster: cluster, onEvent: _onPusherEvent);
      await pusher.subscribe(channelName: _channelName!);
      await pusher.connect();
      _pusher = pusher;
    } catch (_) {
      // 실시간 연결 실패 시에도 수동 전송으로 대화는 가능
      _pusher = null;
    }
  }

  void _onPusherEvent(PusherEvent event) {
    if (event.eventName != 'message') return;
    try {
      final decoded = jsonDecode(event.data);
      if (decoded is! Map) return;
      final msg = decoded['message'];
      if (msg is! Map) return;
      final sender = msg['sender']?.toString();
      // 내가 보낸 메시지는 이미 로컬에 추가했으므로 admin 메시지만 반영
      if (sender != 'admin') return;
      final id = msg['id'];
      final exists = _messages.any((m) => id != null && m['id'] == id);
      if (exists) return;
      if (!mounted) return;
      setState(() => _messages.add(msg));
      _scrollToBottom();
    } catch (_) {
      // 파싱 실패는 무시
    }
  }

  Future<void> _teardownPusher() async {
    final pusher = _pusher;
    if (pusher == null) return;
    try {
      if (_channelName != null) await pusher.unsubscribe(channelName: _channelName!);
      await pusher.disconnect();
    } catch (_) {}
    _pusher = null;
  }

  Future<void> _startContact() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      toast(context, '이름과 전화번호를 입력해주세요.');
      return;
    }
    setState(() => _starting = true);
    try {
      await ref.read(apiProvider).post('/chat/start', data: {'name': name, 'phone': phone});
      if (!mounted) return;
      setState(() => _hasContact = true);
    } catch (e) {
      if (!mounted) return;
      toast(context, e is ApiException ? e.firstError : '오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _send() async {
    final body = _inputCtrl.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final res = await ref.read(apiProvider).post('/chat/send', data: {'body': body});
      if (!mounted) return;
      _inputCtrl.clear();
      final msg = res['message'];
      if (msg is Map) {
        setState(() => _messages.add(msg));
      }
      if (res['room_token'] != null) _roomToken = res['room_token'].toString();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      toast(context, e is ApiException ? e.firstError : '전송에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = ref.watch(authProvider).isLoggedIn;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('실시간 상담', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text('보통 몇 분 내 답변', style: TextStyle(fontSize: 12, color: AppColors.sub, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
      body: !loggedIn ? _loginRequired() : _buildBody(),
    );
  }

  Widget _loginRequired() {
    return EmptyState(
      Icons.lock_outline,
      '로그인이 필요합니다',
      action: SizedBox(
        width: 200,
        child: ElevatedButton(
          onPressed: () => context.push('/login'),
          child: const Text('로그인'),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.navy));
    if (_error != null) return ErrorRetry(_error!, _open);
    return Column(
      children: [
        Expanded(child: _messageList()),
        if (!_hasContact) _contactForm() else _inputBar(),
      ],
    );
  }

  Widget _messageList() {
    if (_messages.isEmpty) {
      return const EmptyState(Icons.chat_bubble_outline, '무엇을 도와드릴까요?\n메시지를 남겨주세요.');
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _bubble(_messages[i]),
    );
  }

  Widget _bubble(Map m) {
    final isUser = m['sender']?.toString() == 'user';
    final body = m['body']?.toString() ?? '';
    final time = m['time']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isUser) ...[
            Text(time, style: const TextStyle(fontSize: 10.5, color: AppColors.sub)),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
              decoration: BoxDecoration(
                color: isUser ? AppColors.navy : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser ? null : Border.all(color: AppColors.line),
              ),
              child: Text(
                body,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.5,
                  color: isUser ? Colors.white : AppColors.ink,
                ),
              ),
            ),
          ),
          if (!isUser) ...[
            const SizedBox(width: 6),
            Text(time, style: const TextStyle(fontSize: 10.5, color: AppColors.sub)),
          ],
        ],
      ),
    );
  }

  Widget _contactForm() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('상담 시작 전, 연락처를 남겨주세요.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(hintText: '이름', prefixIcon: Icon(Icons.person_outline)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(hintText: '전화번호', prefixIcon: Icon(Icons.phone_outlined)),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _starting ? null : _startContact,
              child: _starting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : const Text('상담 시작하기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '메시지를 입력하세요',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    filled: true,
                    fillColor: AppColors.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _sendButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sendButton() {
    final enabled = _inputCtrl.text.trim().isNotEmpty && !_sending;
    return GestureDetector(
      onTap: enabled ? _send : null,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: enabled ? AppColors.navy : AppColors.line,
          shape: BoxShape.circle,
        ),
        child: _sending
            ? const Padding(
                padding: EdgeInsets.all(13),
                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
              )
            : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 24),
      ),
    );
  }
}
