.PHONY: locale build clean

locale:
	dart run easy_localization:generate -S assets/translations -O lib/config/consants -o locale_keys.g.dart -f keys

build:
	dart run build_runner build

rebuild:
	dart run build_runner build --delete-conflicting-outputs

clean:
	flutter clean && flutter pub get

bundle:
	flutter build appbundle --release

apk:
	flutter build apk --release
