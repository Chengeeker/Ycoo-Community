import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

String unwrapPortalHtml(String source) {
  final start = source.indexOf('<![CDATA[');
  final end = source.lastIndexOf(']]>');
  return start >= 0 && end > start ? source.substring(start + 9, end) : source;
}

class PortalEntry {
  const PortalEntry({
    required this.title,
    required this.url,
    this.image = '',
    this.author = '',
    this.avatar = '',
    this.detail = '',
  });
  final String title, url, image, author, avatar, detail;

  factory PortalEntry.fromJson(Map value) => PortalEntry(
    title: value['title'] as String? ?? '',
    url: value['url'] as String? ?? '',
    image: value['image'] as String? ?? '',
    author: value['author'] as String? ?? '',
    avatar: value['avatar'] as String? ?? '',
    detail: value['detail'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'url': url,
    'image': image,
    'author': author,
    'avatar': avatar,
    'detail': detail,
  };
}

class PortalData {
  const PortalData({
    this.banners = const [],
    this.services = const [],
    this.forums = const [],
    this.rankings = const [],
    this.pinned = const [],
    this.notices = const [],
  });
  final List<PortalEntry> banners, services, forums, rankings, pinned, notices;

  factory PortalData.parse(String source) {
    final doc = html.parse(unwrapPortalHtml(source));
    final base = Uri.parse('https://ycoo.net/');
    String url(String? value) {
      if (value == null || value.trim().isEmpty) return '';
      final parsed = Uri.tryParse(value.trim());
      if (parsed == null) return '';
      final uri = base.resolveUri(parsed);
      if (!['https', 'http'].contains(uri.scheme) ||
          uri.userInfo.isNotEmpty ||
          uri.host.isEmpty) {
        return '';
      }
      return uri.toString();
    }

    List<PortalEntry> entries(String selector) {
      return doc
          .querySelectorAll(selector)
          .map((Element a) {
            final user = a.querySelector('.kmuser');
            final title =
                a.querySelector('.kmtit, .album_tit, p')?.text.trim() ??
                a.attributes['title'] ??
                a.text.trim();
            return PortalEntry(
              title: title,
              url: url(a.attributes['href']),
              image: url(a.querySelector('img')?.attributes['src']),
              author: user?.text.trim() ?? '',
              avatar: url(user?.querySelector('img')?.attributes['src']),
              detail:
                  a
                      .querySelector('.comiis_tm, .album_txt, .f_d.y')
                      ?.text
                      .trim() ??
                  '',
            );
          })
          .where((entry) => entry.url.isNotEmpty && entry.title.isNotEmpty)
          .toList();
    }

    return PortalData(
      banners: entries('.comiis_mh_img35 li > a, .comiis_mh_img14 li > a'),
      services: entries('.comiis_mh_hdico5 li a'),
      forums: entries('.comiis_mh_hotbk li a'),
      rankings: entries('.comiis_mh_list19 li a'),
      pinned: entries('.comiis_mh_img26 li a'),
      notices: entries('.comiis_mh_gonggao li a'),
    );
  }

  factory PortalData.fromJson(Map value) {
    List<PortalEntry> read(String key) => (value[key] as List? ?? [])
        .whereType<Map>()
        .map(PortalEntry.fromJson)
        .toList();
    return PortalData(
      banners: read('banners'),
      services: read('services'),
      forums: read('forums'),
      rankings: read('rankings'),
      pinned: read('pinned'),
      notices: read('notices'),
    );
  }

  Map<String, dynamic> toJson() => {
    'banners': banners.map((e) => e.toJson()).toList(),
    'services': services.map((e) => e.toJson()).toList(),
    'forums': forums.map((e) => e.toJson()).toList(),
    'rankings': rankings.map((e) => e.toJson()).toList(),
    'pinned': pinned.map((e) => e.toJson()).toList(),
    'notices': notices.map((e) => e.toJson()).toList(),
  };
}
