enum TimeFilter { dzis, wczoraj, tydzien, miesiac, rok, calyCzas }

extension TimeFilterLabel on TimeFilter {
  String get label => switch (this) {
        TimeFilter.dzis => 'Dziś',
        TimeFilter.wczoraj => 'Wczoraj',
        TimeFilter.tydzien => 'Ostatni tydzień',
        TimeFilter.miesiac => 'Ostatni miesiąc',
        TimeFilter.rok => 'Ostatni rok',
        TimeFilter.calyCzas => 'Cały czas',
      };
}
