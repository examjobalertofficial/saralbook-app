import 'package:flutter/material.dart';

/// ============================================================
/// ALL WEBSITE SETTINGS LIVE HERE.
/// To change a website address, edit the `url` line below.
/// ============================================================
class Website {
  final String id;
  final String name;
  final String description;
  final String url;
  final IconData icon;
  final Color color;

  const Website({
    required this.id,
    required this.name,
    required this.description,
    required this.url,
    required this.icon,
    required this.color,
  });
}

class Websites {
  static const List<Website> all = [
    Website(
      id: 'examjobalert',
      name: 'Exam Job Alert',
      description:
          'Latest Sarkari Jobs, Admit Cards, Results & Government Exam Updates',
      url: 'https://examjobalert.com/',
      icon: Icons.work_outline_rounded,
      color: Color(0xFFD9480F),
    ),
    Website(
      id: 'saralbook',
      name: 'SaralBook',
      description:
          'Government Exam Preparation, Study Material & Current Affairs',
      url: 'https://saralbook.com/',
      icon: Icons.menu_book_rounded,
      color: Color(0xFF1E5AA8),
    ),
    Website(
      id: 'saralbooktest',
      name: 'SaralBook Test',
      description: 'Mock Tests, Practice Tests & Online Exam Preparation',
      url: 'https://test.saralbook.com/',
      icon: Icons.quiz_outlined,
      color: Color(0xFF0B8457),
    ),
    Website(
      id: 'saralbookstore',
      name: 'SaralBook Store',
      description:
          'Digital Products, Ebooks, Plugins & Learning Resources',
      url: 'https://store.saralbook.com/',
      icon: Icons.storefront_outlined,
      color: Color(0xFF7B3FC4),
    ),
    Website(
      id: 'onlinecalcy',
      name: 'Online Calcy',
      description: 'Online Calculators & Useful Everyday Tools',
      url: 'https://onlinecalcy.com/',
      icon: Icons.calculate_outlined,
      color: Color(0xFFC2255C),
    ),
  ];

  /// Links to these sites (e.g. social media footers) open in the phone's
  /// own apps/browser instead of inside SaralBook.
  static const List<String> externalHostSuffixes = [
    'wa.me',
    'whatsapp.com',
    't.me',
    'telegram.me',
    'facebook.com',
    'instagram.com',
    'twitter.com',
    'x.com',
    'youtube.com',
    'youtu.be',
    'play.google.com',
  ];

  static bool isExternalHost(String host) {
    final h = host.toLowerCase();
    return externalHostSuffixes.any((s) => h == s || h.endsWith('.$s'));
  }
}
