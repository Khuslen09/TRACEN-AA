import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:tracen/services/env_service.dart';

class AiPlannerScreen extends StatefulWidget {
  const AiPlannerScreen({super.key});

  @override
  State<AiPlannerScreen> createState() => _AiPlannerScreenState();
}

class _AiPlannerScreenState extends State<AiPlannerScreen> {
  static const Color primary = Color(0xFF8B55F1);
  static const _claudeBase = 'https://api.anthropic.com/v1/messages';

  final _departureController = TextEditingController();
  final _destinationController = TextEditingController();

  String _transport = '대중교통';
  int _people = 2;
  int _budget = 50000;
  final List<String> _styles = ['맛집', '핫플', '자연', '문화'];
  final Set<String> _selectedStyles = {'맛집', '핫플'};

  bool _loading = false;
  String? _result;

  @override
  void dispose() {
    _departureController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final departure = _departureController.text.trim();
    final destination = _destinationController.text.trim();
    if (departure.isEmpty || destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('출발지와 목적지를 모두 입력해주세요'), backgroundColor: Colors.black87),
      );
      return;
    }
    setState(() { _loading = true; _result = null; });
    try {
      final plan = await _callClaude(departure, destination);
      if (!mounted) return;
      setState(() => _result = plan);
    } catch (e) {
      if (kDebugMode) debugPrint('[AiPlanner] $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI 플랜 생성에 실패했어요. 잠시 후 다시 시도해주세요'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String> _callClaude(String departure, String destination) async {
    final apiKey = Env.claudeApiKey;
    if (apiKey.isEmpty) throw Exception('Claude API 키가 설정되지 않았습니다');

    final prompt = '''한국 여행 플래너입니다. 아래 조건에 맞는 여행 코스를 추천해주세요.

출발지: $departure / 목적지: $destination
교통수단: $_transport / 인원: $_people명 / 1인 예산: ${(_budget / 10000).toInt()}만원
여행 스타일: ${_selectedStyles.join(', ')}

시간대별 일정(오전/오후/저녁), 예상 총 비용, 이동 시 주의사항을 포함해 마크다운 없이 답변해주세요.''';

    final res = await http.post(
      Uri.parse(_claudeBase),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': 'claude-haiku-4-5-20251001',
        'max_tokens': 1024,
        'messages': [{'role': 'user', 'content': prompt}],
      }),
    );
    if (res.statusCode != 200) throw Exception('Claude API 오류 (${res.statusCode})');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return ((data['content'] as List).first as Map<String, dynamic>)['text'] as String;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('AI 여행 플래너', style: TextStyle(color: Colors.black, fontSize: 17)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 27),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFFE8E0FF), borderRadius: BorderRadius.circular(16)),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome, color: primary, size: 28),
                  SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI가 최적의 코스를 추천해드려요', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      SizedBox(height: 4),
                      Text('조건을 입력하면 맞춤 여행 플랜을 짜드립니다', style: TextStyle(color: Color(0xFF757575), fontSize: 13)),
                    ],
                  )),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _sectionTitle('출발지 / 목적지'),
            _inputField(_departureController, '예: 서울역'),
            const SizedBox(height: 8),
            _inputField(_destinationController, '예: 부산역'),
            const SizedBox(height: 24),
            _sectionTitle('인원'),
            Row(children: [
              IconButton(icon: const Icon(Icons.remove_circle_outline, color: primary),
                  onPressed: () => setState(() { if (_people > 1) _people--; })),
              Container(
                width: 50, height: 40, alignment: Alignment.center,
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD9D9D9)), borderRadius: BorderRadius.circular(8)),
                child: Text('$_people명', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              IconButton(icon: const Icon(Icons.add_circle_outline, color: primary),
                  onPressed: () => setState(() => _people++)),
            ]),
            const SizedBox(height: 24),
            _sectionTitle('예산 (1인 기준)'),
            Slider(
              value: _budget.toDouble(), min: 10000, max: 200000, divisions: 19,
              activeColor: primary, label: '${(_budget / 10000).toInt()}만원',
              onChanged: (v) => setState(() => _budget = v.toInt()),
            ),
            Text('${(_budget / 10000).toInt()}만원', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primary)),
            const SizedBox(height: 24),
            _sectionTitle('교통수단'),
            Wrap(spacing: 8, children: ['대중교통', '자가용', '도보', '자전거'].map((t) => ChoiceChip(
              label: Text(t), selected: _transport == t,
              onSelected: (_) => setState(() => _transport = t),
              selectedColor: primary,
              labelStyle: TextStyle(color: _transport == t ? Colors.white : Colors.black),
              backgroundColor: const Color(0xFFF5F5F5),
            )).toList()),
            const SizedBox(height: 24),
            _sectionTitle('여행 스타일'),
            Wrap(spacing: 8, children: _styles.map((s) => FilterChip(
              label: Text(s), selected: _selectedStyles.contains(s),
              onSelected: (v) => setState(() { if (v) {
                _selectedStyles.add(s);
              } else {
                _selectedStyles.remove(s);
              } }),
              selectedColor: const Color(0xFFE8E0FF), checkmarkColor: primary,
              labelStyle: TextStyle(color: _selectedStyles.contains(s) ? primary : Colors.black),
              backgroundColor: const Color(0xFFF5F5F5),
            )).toList()),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _generate,
                icon: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                    : const Icon(Icons.auto_awesome, size: 20),
                label: Text(_loading ? '생성 중...' : 'AI 플랜 생성하기', style: const TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
              ),
            ),
            if (_result != null) ...[
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F5FF),
                  border: Border.all(color: const Color(0xFFD4C4FF)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.auto_awesome, color: primary, size: 18),
                    SizedBox(width: 8),
                    Text('AI 추천 플랜', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primary)),
                  ]),
                  const SizedBox(height: 16),
                  Text(_result!, style: const TextStyle(fontSize: 14, height: 1.7, color: Colors.black87)),
                ]),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
  );

  Widget _inputField(TextEditingController controller, String hint) => TextField(
    controller: controller,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFB3B3B3)),
      prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFFB3B3B3)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD9D9D9))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD9D9D9))),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  );
}
