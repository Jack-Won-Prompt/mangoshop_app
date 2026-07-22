import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme.dart';

/// 주소 검색 결과
class AddressResult {
  final String zonecode; // 우편번호
  final String address; // 도로명(또는 지번) 기본주소
  final String buildingName; // 건물명(참고표시)
  const AddressResult(this.zonecode, this.address, this.buildingName);
}

/// 카카오(다음) 우편번호 서비스 — 인앱 웹뷰. 선택 시 [AddressResult] 로 pop.
class AddressSearchScreen extends StatefulWidget {
  const AddressSearchScreen({super.key});

  @override
  State<AddressSearchScreen> createState() => _AddressSearchScreenState();
}

class _AddressSearchScreenState extends State<AddressSearchScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  static const _html = '''
<!doctype html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no"></head>
<body style="margin:0;padding:0">
<div id="wrap" style="position:absolute;top:0;left:0;right:0;bottom:0;"></div>
<script src="https://t1.daumcdn.net/mapjsapi/bundle/postcode/prod/postcode.v2.js"></script>
<script>
  function start(){
    new daum.Postcode({
      oncomplete: function(data){
        var payload = JSON.stringify({
          zonecode: data.zonecode || '',
          address: data.roadAddress || data.jibunAddress || data.address || '',
          buildingName: data.buildingName || ''
        });
        if (window.AddressChannel) AddressChannel.postMessage(payload);
      },
      onresize: function(size){ document.getElementById('wrap').style.height = size.height + 'px'; },
      width: '100%',
      height: '100%'
    }).embed(document.getElementById('wrap'), { autoClose: false });
  }
  if (window.daum && daum.Postcode) { start(); }
  else { window.addEventListener('load', start); }
</script>
</body>
</html>
''';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel('AddressChannel', onMessageReceived: (msg) {
        try {
          final data = jsonDecode(msg.message) as Map<String, dynamic>;
          final result = AddressResult(
            (data['zonecode'] ?? '').toString(),
            (data['address'] ?? '').toString(),
            (data['buildingName'] ?? '').toString(),
          );
          if (mounted) Navigator.of(context).pop(result);
        } catch (_) {}
      })
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ))
      ..loadHtmlString(_html, baseUrl: 'https://postcode.map.daum.net');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('주소 검색')),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const Center(child: CircularProgressIndicator(color: AppColors.navy)),
        ],
      ),
    );
  }
}
