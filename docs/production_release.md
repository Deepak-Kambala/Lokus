# Production Release Checklist

## Android Signing

Release builds require `android/key.properties`. This file is intentionally
ignored by git.

Example:

```properties
storeFile=/absolute/path/to/lokus-release.jks
storePassword=change-this
keyAlias=lokus
keyPassword=change-this
```

Build commands:

```sh
flutter build appbundle --release
flutter build apk --release
```

## Preflight

Run these before shipping:

```sh
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter build apk --debug
flutter build appbundle --release
```

## Privacy

Lokus stores chats and downloaded GGUF models locally on the device. The app
does not request broad Android storage, media, notification, or foreground
service permissions in the production manifest.
