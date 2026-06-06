import 'dart:async';
import 'package:dio/dio.dart';

class WebGroundingResult {
  final String query;
  final DateTime fetchedAt;
  final List<WebGroundingSource> sources;

  const WebGroundingResult({
    required this.query,
    required this.fetchedAt,
    required this.sources,
  });

  bool get hasSources => sources.isNotEmpty;

  String toPromptContext() {
    final buffer = StringBuffer()
      ..writeln('Web context for the latest user request.')
      ..writeln('Query: $query')
      ..writeln('Fetched at: ${fetchedAt.toIso8601String()}')
      ..writeln(
        'Use these sources only for live/current facts. If they do not support the answer, say you could not verify it.',
      );

    for (var i = 0; i < sources.length; i++) {
      final source = sources[i];
      buffer
        ..writeln()
        ..writeln('[${i + 1}] ${source.title}')
        ..writeln('Source: ${source.sourceName}')
        ..writeln('Date: ${source.publishedAt ?? 'Unknown'}')
        ..writeln('Snippet: ${source.snippet}')
        ..writeln('URL: ${source.url}');
    }

    return buffer.toString();
  }
}

class WebGroundingSource {
  final String title;
  final String snippet;
  final String url;
  final String sourceName;
  final String? publishedAt;

  const WebGroundingSource({
    required this.title,
    required this.snippet,
    required this.url,
    required this.sourceName,
    this.publishedAt,
  });
}

class WebGroundingService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 10),
      headers: const {
        'User-Agent': 'Lokus/1.0 (Android; Flutter)',
        'Accept': 'text/html,application/rss+xml,application/xml,*/*',
      },
      followRedirects: true,
      maxRedirects: 5,
    ),
  );

  bool shouldGround(String query) {
    final text = query.trim();
    if (text.isEmpty) return false;

    final lower = text.toLowerCase();
    if (_looksCreativeOrTransformative(lower)) return false;

    final asksForCurrentInfo = RegExp(
      r'\b(current|latest|today|yesterday|tonight|now|recent|recently|live|breaking|updated|newest|this week|this month|this year)\b',
      caseSensitive: false,
    ).hasMatch(lower);
    if (asksForCurrentInfo) return true;

    final currentYear = DateTime.now().year;
    final asksQuestion = RegExp(
      r'\b(who|what|when|where|which|why|how|did|has|have|is|are|was|were)\b',
      caseSensitive: false,
    ).hasMatch(lower);
    final asksForChangingResult = RegExp(
      r'\b(won|winner|result|score|final|standings|price|weather|election|released|launched|announced|appointed|schedule|fixture)\b',
      caseSensitive: false,
    ).hasMatch(lower);

    if (asksQuestion && asksForChangingResult) return true;

    final years = RegExp(r'\b(20\d{2})\b').allMatches(lower);
    for (final match in years) {
      final year = int.tryParse(match.group(1) ?? '');
      if (year != null && year >= currentYear - 1 && asksQuestion) {
        return true;
      }
    }

    return false;
  }

  Future<WebGroundingResult?> ground(String query) async {
    if (!shouldGround(query)) return null;

    final results = await Future.wait<List<WebGroundingSource>>([
      _searchGoogleNews(query),
      _searchDuckDuckGo(query),
    ]);

    final seen = <String>{};
    final sources = <WebGroundingSource>[];
    for (final source in results.expand((items) => items)) {
      final key = '${source.title}|${source.url}'.toLowerCase();
      if (seen.add(key)) {
        sources.add(source);
      }
      if (sources.length >= 6) break;
    }

    return WebGroundingResult(
      query: query,
      fetchedAt: DateTime.now(),
      sources: sources,
    );
  }

  Future<List<WebGroundingSource>> _searchGoogleNews(String query) async {
    try {
      final uri = Uri.https('news.google.com', '/rss/search', {
        'q': query,
        'hl': 'en-IN',
        'gl': 'IN',
        'ceid': 'IN:en',
      });
      final response = await _dio.getUri<String>(uri);
      final body = response.data ?? '';
      final items = RegExp(
        r'<item>([\s\S]*?)</item>',
        caseSensitive: false,
      ).allMatches(body);

      final sources = <WebGroundingSource>[];
      for (final item in items.take(5)) {
        final block = item.group(1) ?? '';
        final title = _xmlValue(block, 'title');
        final link = _xmlValue(block, 'link');
        final description = _cleanText(_xmlValue(block, 'description'));
        final sourceName = _xmlValue(block, 'source');
        final pubDate = _xmlValue(block, 'pubDate');
        if (title.isEmpty || description.isEmpty) continue;
        sources.add(
          WebGroundingSource(
            title: _cleanText(title),
            snippet: description,
            url: link,
            sourceName: sourceName.isEmpty ? 'Google News' : sourceName,
            publishedAt: pubDate.isEmpty ? null : pubDate,
          ),
        );
      }
      return sources;
    } catch (_) {
      return const [];
    }
  }

  Future<List<WebGroundingSource>> _searchDuckDuckGo(String query) async {
    try {
      final uri = Uri.https('duckduckgo.com', '/html/', {'q': query});
      final response = await _dio.getUri<String>(uri);
      final body = response.data ?? '';
      final blocks = RegExp(
        r'<div class="result[\s\S]*?</div>\s*</div>',
        caseSensitive: false,
      ).allMatches(body);

      final sources = <WebGroundingSource>[];
      for (final blockMatch in blocks.take(5)) {
        final block = blockMatch.group(0) ?? '';
        final titleMatch = RegExp(
          r'class="result__a"[^>]*href="([^"]+)"[^>]*>([\s\S]*?)</a>',
          caseSensitive: false,
        ).firstMatch(block);
        final snippetMatch = RegExp(
          r'class="result__snippet"[^>]*>([\s\S]*?)</a>',
          caseSensitive: false,
        ).firstMatch(block);
        if (titleMatch == null || snippetMatch == null) continue;

        final title = _cleanText(titleMatch.group(2) ?? '');
        final snippet = _cleanText(snippetMatch.group(1) ?? '');
        final url = _decodeDuckDuckGoUrl(titleMatch.group(1) ?? '');
        if (title.isEmpty || snippet.isEmpty) continue;

        sources.add(
          WebGroundingSource(
            title: title,
            snippet: snippet,
            url: url,
            sourceName: _hostName(url),
          ),
        );
      }
      return sources;
    } catch (_) {
      return const [];
    }
  }

  bool _looksCreativeOrTransformative(String lower) {
    return RegExp(
      r'\b(write|create|draft|compose|story|poem|essay|email|letter|caption|rewrite|summarize|translate|explain|brainstorm|code|implement|debug|fix)\b',
      caseSensitive: false,
    ).hasMatch(lower);
  }

  String _xmlValue(String block, String tag) {
    final match = RegExp(
      '<$tag(?: [^>]*)?>([\\s\\S]*?)</$tag>',
      caseSensitive: false,
    ).firstMatch(block);
    return _decodeHtml(match?.group(1) ?? '');
  }

  String _decodeDuckDuckGoUrl(String href) {
    final decoded = _decodeHtml(href);
    final uri = Uri.tryParse(
      decoded.startsWith('//') ? 'https:$decoded' : decoded,
    );
    final target = uri?.queryParameters['uddg'];
    return target == null || target.isEmpty ? decoded : target;
  }

  String _hostName(String url) {
    final host = Uri.tryParse(url)?.host;
    if (host == null || host.isEmpty) return 'Web';
    return host.replaceFirst(RegExp(r'^www\.'), '');
  }

  String _cleanText(String value) {
    return _decodeHtml(value)
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _decodeHtml(String value) {
    var decoded = value
        .replaceAll('<![CDATA[', '')
        .replaceAll(']]>', '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");

    decoded = decoded.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (match) {
        final codePoint = int.tryParse(match.group(1) ?? '');
        if (codePoint == null) return match.group(0) ?? '';
        return String.fromCharCode(codePoint);
      },
    );

    return decoded;
  }
}
