import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';

/// Fetches a legal page from the `legal_pages` table and renders it.
/// page_type: 'privacy_policy' | 'refund_policy' | 'terms_conditions'
class LegalPageScreen extends StatefulWidget {
  final String pageType;
  final String fallbackTitle;

  const LegalPageScreen({
    super.key,
    required this.pageType,
    this.fallbackTitle = '',
  });

  @override
  State<LegalPageScreen> createState() => _LegalPageScreenState();
}

class _LegalPageScreenState extends State<LegalPageScreen> {
  bool _loading = true;
  String? _title;
  String? _content;
  String? _error;
  DateTime? _updatedAt;

  @override
  void initState() {
    super.initState();
    _fetchPage();
  }

  Future<void> _fetchPage() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await Supabase.instance.client
          .from('legal_pages')
          .select('title, content, updated_at')
          .eq('page_type', widget.pageType)
          .maybeSingle();
      if (data != null) {
        setState(() {
          _title = data['title'] as String?;
          _content = data['content'] as String?;
          _updatedAt = data['updated_at'] != null
              ? DateTime.tryParse(data['updated_at'].toString())
              : null;
        });
      } else {
        setState(() {
          _error = 'This page is not available yet. Please check back soon.';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Could not load this page. Please check your connection and try again.';
      });
      debugPrint('LegalPageScreen fetch error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBgColor(context),
      appBar: AppBar(
        backgroundColor: appBgColor(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(shape: BoxShape.circle, color: appPaperColor(context)),
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: appInkColor(context)),
          ),
        ),
        title: Text(
          _title ??
              (widget.fallbackTitle.isNotEmpty
                  ? widget.fallbackTitle
                  : (widget.pageType == 'privacy_policy'
                      ? 'Privacy Policy'
                      : widget.pageType == 'refund_policy'
                          ? 'Refund Policy'
                          : 'Terms & Conditions')),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17, fontWeight: FontWeight.w800, color: appInkColor(context),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.orange),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(fontSize: 14, color: appInkSoftColor(context))),
                        const SizedBox(height: 20),
                        ElevatedButton(onPressed: _fetchPage, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_updatedAt != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            'Last updated: ${_updatedAt!.day}/${_updatedAt!.month}/${_updatedAt!.year}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12, color: appInkSoftColor(context),
                            ),
                          ),
                        ),
                      // Render content as simple formatted text
                      // Split by lines and render headings (## prefix) and body text
                      ..._renderContent(_content ?? ''),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }

  List<Widget> _renderContent(String content) {
    final lines = content.split('\n');
    final widgets = <Widget>[];
    for (final line in lines) {
      if (line.startsWith('# ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(line.substring(2), style: GoogleFonts.plusJakartaSans(
            fontSize: 20, fontWeight: FontWeight.w800, color: appInkColor(context),
          )),
        ));
      } else if (line.startsWith('## ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(line.substring(3), style: GoogleFonts.plusJakartaSans(
            fontSize: 15, fontWeight: FontWeight.w700, color: appInkColor(context),
          )),
        ));
      } else if (line.startsWith('| ') && line.endsWith(' |')) {
        // Simple table row
        if (!line.contains('---')) {
          final cells = line.split('|').where((c) => c.trim().isNotEmpty).toList();
          widgets.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: cells.map((c) => Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(border: Border.all(color: appLineColor(context))),
                  child: Text(c.trim(), style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: appInkColor(context),
                  )),
                ),
              )).toList(),
            ),
          ));
        }
      } else if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(line, style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5, color: appInkColor(context), height: 1.6,
          )),
        ));
      }
    }
    return widgets;
  }
}
