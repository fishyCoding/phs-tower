# Fonts

Place the masthead font file here as exactly:

    assets/fonts/Canterbury.ttf

It's referenced by `pubspec.yaml` (`family: Canterbury`) and used by the
"The Tower" masthead in `lib/screens/news_screen.dart`.

The app will fail to build with an "unable to find asset" error until this
file is present. Canterbury is a free blackletter font (e.g. from dafont);
download it, rename the `.ttf` to `Canterbury.ttf`, and drop it in this folder.
