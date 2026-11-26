# SpendMinute

Log expenses in yen, browse by day, and see totals grouped by the hour they were logged. A separate calculator supports addition, subtraction, multiplication, and division. Entries persist on the current device through shared preferences.

Use Flutter 3.24 or later with Dart 3.5 or later. Generate the platform runner in a sibling directory and copy its Android runner into this project.

```sh
flutter create --platforms=android --project-name spendminute ../spendminute-runner
cp -R ../spendminute-runner/android .
flutter pub get
flutter run
```

The source and package manifest are included. Flutter tooling generates the platform runner and APK.
