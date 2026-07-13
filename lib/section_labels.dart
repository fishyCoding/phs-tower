/// Human-readable section name for a category's database moniker.
///
/// The raw monikers (e.g. `news-features`, `arts-entertainment`) must never be
/// shown in the UI — always route category text through this.
String sectionName(String category) {
  switch (category.toLowerCase().trim()) {
    case 'news-features':
      return 'News and Features';
    case 'arts-entertainment':
      return 'Arts and Entertainment';
    case 'opinions':
      return 'Opinions';
    case 'sports':
      return 'Sports';
    case 'vanguard':
      return 'Vanguard';
    case 'all':
      return 'All';
    default:
      // Title-case any unknown moniker so a raw slug never leaks through.
      return category
          .split(RegExp(r'[-_\s]+'))
          .where((w) => w.isNotEmpty)
          .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
          .join(' ');
  }
}
