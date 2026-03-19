#! /bin/bash
flutter clean

dart run build_runner build --delete-conflicting-outputs                                                                                                                     ─╯

flutter build app --release --dart-define=isOhosStore=true
