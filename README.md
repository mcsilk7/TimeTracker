# ScreenTimer

Aplikacja Flutter do monitorowania czasu uruchomienia aplikacji na urządzeniu.

## Co robi ta aplikacja?

- zbiera czas użycia aplikacji przy użyciu pakietu `app_usage`
- pokazuje listę aplikacji i ich czasów użytkowania
- filtruje dane według okresów: dziś, wczoraj, tydzień, miesiąc, rok oraz cały czas
- oferuje ekran `Osiągnięcia` z kluczowymi rekordami
- oferuje ekran `Wykres` z tygodniową aktywnością
- zapisuje ustawienia motywu w `SharedPreferences`

## Funkcje

- `Monitor Czasu Ekranu`: główny ekran z listą użycia aplikacji
- `Filtry`: przełączanie zakresu czasu
- `Osiągnięcia`: rekordy, np. czas w jednym dniu, najmniej używana aplikacja, top 3 aplikacje
- `Wykres`: wizualizacja aktywności na 7-dniowym wykresie słupkowym
- `Ustawienia`: wybór motywu (jasny/ciemny/systemowy)

## Zależności

- `flutter`
- `app_usage`
- `installed_apps`
- `shared_preferences`

## Jak uruchomić

1. Pobierz zależności:

```bash
flutter pub get
```

2. Uruchom aplikację na wybranym emulatorze lub urządzeniu:

```bash
flutter run
```

## Uprawnienia

Aplikacja wymaga dostępu do statystyk użycia (Android). Musisz włączyć uprawnienie `Dostęp do danych użytkowania` w ustawieniach systemowych, jeśli aplikacja tego zażąda.

## Struktura projektu

- `lib/main.dart` — punkt wejścia aplikacji i zarządzanie motywami
- `lib/screens/app_usage_screen.dart` — ekran główny z filtrem i podsumowaniem
- `lib/screens/achievements_screen.dart` — ekran rekordów użytkownika
- `lib/screens/weekly_activity_screen.dart` — ekran tygodniowej aktywności
- `lib/screens/settings_screen.dart` — ustawienia motywu
- `lib/utils/usage_utils.dart` — logika zakresów dat, pobierania i agregacji statystyk
- `lib/widgets/` — komponenty UI, np. kafelki i dropdown

## Uwagi

- W niektórych wersjach Androida pakiet `app_usage` wymaga dodatkowej konfiguracji i uprawnień.
- Jeśli dane nie są widoczne, sprawdź, czy aplikacja ma dostęp do danych użytkowania.

---

Jeśli chcesz, mogę też dodać sekcję `Developer` z instrukcjami debugowania i testów. }