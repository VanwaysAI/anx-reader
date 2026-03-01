# CLAUDE.md

## Project Overview

Anx Reader is a cross-platform e-book reader built with Flutter, supporting iOS, macOS, Windows, and Android. It features AI integration, WebDAV synchronization, TTS narration, translation capabilities, and a modern reading experience with customizable themes and layouts.

## Development Commands

### Setup and Dependencies

```sh
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
```

### Running the Application

```sh
flutter run
```

### Testing

```sh
flutter test
flutter analyze
```

### Linting and Code Generation

```sh
dart run build_runner build --delete-conflicting-outputs  # Generate Riverpod and other generated code
flutter gen-l10n                                          # Generate localization files
dart run custom_lint                                      # Run custom lints (Riverpod lints)
```

### JavaScript Development (for e-book rendering)

```sh
cd assets/foliate-js
npm install
npm run build  # Build for production
npm run debug  # Development server with debug.html
```

## Architecture Overview

### Core Structure

- **State Management**: Uses Riverpod for state management with `flutter_riverpod`
- **Data Layer**: SQLite database with `sqflite` for local storage
- **Configuration**: `shared_preferences` for user settings via `Prefs()` singleton
- **E-book Rendering**: JavaScript-based rendering using modified `foliate-js` in WebView
- **Sync**: WebDAV-based synchronization for cross-device data sync
- **Navigation**: Custom navigation with global `navigatorKey`

### Key Directories

| Path | Description |
|------|-------------|
| `lib/config/` | Configuration management and shared preferences |
| `lib/dao/` | Database access objects for SQLite operations |
| `lib/enums/` | Type-safe enumerations |
| `lib/models/` | Data models with JSON serialization (`json_annotation` and `freezed`) |
| `lib/page/` | UI pages and screens |
| `lib/providers/` | Riverpod providers for state management |
| `lib/service/` | Business logic services (AI, sync, TTS, translation, etc.) |
| `lib/utils/` | Utility functions and helpers |
| `lib/widgets/` | Reusable UI components |
| `assets/foliate-js/` | JavaScript e-book rendering engine |

### E-book Rendering Architecture

The app uses a hybrid approach combining Flutter UI with JavaScript-based e-book rendering:

1. **Built-in Server**: `Server()` singleton serves `foliate-js` files locally
2. **WebView Integration**: `flutter_inappwebview` loads the local server content
3. **JavaScript Bridge**: Communication between Dart and JS via WebView message passing
4. **Core Files**:
   - `assets/foliate-js/index.html` — Main rendering page
   - `assets/foliate-js/src/` — JavaScript source code
   - `assets/foliate-js/dist/bundle.js` — Production build
   - `lib/page/book_player/epub_player.dart` — Main WebView integration

### Database Layer

Uses SQLite with custom DAO classes:

- `lib/dao/database.dart` — Database initialization and management
- Individual DAOs for books, notes, bookmarks, etc.
- Models use `json_annotation` for serialization

### Configuration System

Centralized configuration via `Prefs()` singleton:

- Extends `ChangeNotifier` for reactive updates
- Stores user preferences, theme settings, reading configurations
- Book-specific settings (e.g., translation modes per book)

### Services Architecture

- **AI Service**: Multi-provider AI integration (OpenAI, Claude, Gemini, DeepSeek)
- **Sync Service**: WebDAV-based cross-device synchronization
- **TTS Service**: Text-to-speech with system and Edge TTS options
- **Translation Service**: Multi-provider translation support
- **Book Player**: E-book parsing and rendering coordination

### Localization

- Uses `flutter_localizations` with ARB files in `lib/l10n/`
- Run `flutter gen-l10n` after modifying translation files
- Global access via `L10n.of(context)`

## Key Development Patterns

### State Management

- Prefer Riverpod providers over `StatefulWidget` for complex state
- Use `Prefs()` for persistent configuration
- Database operations through the DAO pattern

## Code Generation

Run `dart run build_runner build --delete-conflicting-outputs` after modifying:

- Models with `@freezed` or `@JsonSerializable`
- Riverpod providers with `@riverpod`
- Any files with `part` directives

## JavaScript Development

- Use `debug.html` for standalone JavaScript debugging
- Modify `src/` files, then run `npm run build` to generate `dist/bundle.js`
- Test changes in the Flutter app after rebuilding

## Cross-Platform Considerations

- Use `Platform.isXXX` checks for platform-specific code
- Window management for desktop platforms via `window_manager`
- Platform-specific file paths via `path_provider`

## Audio Session Management

- TTS uses `audio_service` and `audio_session` for proper audio handling
- Configuration for mixing with other audio apps via user preferences
- Global `audioHandler` initialized in `main.dart`

## Testing Strategy

- Unit tests in `test/` directory
- Focus on business logic in services and utilities
- Use `flutter test` to run all tests
- Test database operations and data models

## Development Workflow Guidelines

### Changelog Management

- File: `assets/CHANGELOG.md`
- Format:
  - Always update under the current version header (or create a new one if specified).
  - Use `- Type: Description` format.
  - Maintain both English and Chinese sections. The bottom section of each version block is for Chinese.
- Examples:
  - `Feat: Support replacing book file`
  - `Fix: Fix app crash when disabling AI`
  - `Feat: 支持替换书籍文件`
  - `Fix: 修复关闭 AI 时的应用崩溃`

### Commit Messages

- Use Conventional Commits format: `type(scope): description`
- Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`
- Scope: Optional, indicates the module affected (e.g., `bookshelf`, `reader`, `settings`, `l10n`)
- Description: Concise summary (imperative, lower case)
- Example: `feat(bookshelf): add replace book file feature`

### Localization (L10n)

When adding new UI strings:

1. Add keys to `app_en.arb` (English) and `app_zh-CN.arb` (Simplified Chinese) only.
2. Add keys to all other supported ARB files only when explicitly requested.
3. Run `flutter gen-l10n` to regenerate Dart code.

Supported languages: `en` (Base), `zh`, `zh-CN`, `zh-HK`, `zh-TW`, `zh-LZH` (Classical), `ar`, `de`, `es`, `fr`, `it`, `ja`, `ko`, `pt`, `ro`, `ru`, `tr`.

### Code Style

- Comments: All code comments must be written in English.

## Adding New Reading Configuration Options

When adding new reading configuration options (like text alignment, writing mode, etc.), follow this flow:

1. **Create Enumeration**
   - Create enum file in `lib/enums/` (e.g., `text_alignment.dart`)
   - Use string codes for values (e.g., `auto('auto')`, `left('left')`)
   - Include `fromCode` static method for deserialization
2. **Configuration Storage**
   - Add to `lib/config/shared_preference_provider.dart`:
     - Import the new enum
     - Add getter that uses `fromCode()` with default value
     - Add setter that stores `enum.code` and calls `notifyListeners()`
3. **Dart-side Integration**
   - `epub_player.dart`: Add parameter to `changeStyle()` function call
   - `generate_url.dart`: Add parameter to style map using `Prefs().configName.code`
4. **JavaScript-side Processing**
   - `book.js`:
     - Add parameter to `getCSS()` function signature
     - Update CSS generation logic to use the new parameter
     - Add parameter to all `getCSS()` calls (`footNoteStyle` and `setStyle` calls)

## UI Implementation (Reading Settings)

- In `reading_settings.dart`:
  - Import the new enum
  - Create a widget function following existing patterns (e.g., `writingMode()`)
  - Use `SegmentedButton` with enum values as segments
  - In `onSelectionChanged`, update `Prefs()` and call `epubPlayerKey.currentState?.changeStyle()`
  - Add the widget to the main build column

## Localization

- Add translation keys to ARB files in `lib/l10n/`:
  - Primary key (e.g., `"textAlignment": "Text Alignment"`)
  - Option keys for each enum value (e.g., `"textAlignmentLeft": "Left"`)
- Important: Add to **all supported languages** (see [Localization](#localization-l10n) section).

## Code Generation

- Run `flutter gen-l10n` to generate localization files
- Run `dart run build_runner build --delete-conflicting-outputs` if using generated models

## Example Implementation Reference

See the `textAlignment` implementation:

- Enum: `lib/enums/text_alignment.dart`
- Config: `shared_preference_provider.dart:928-935`
- Dart integration: `epub_player.dart:172`, `generate_url.dart:82`
- JS processing: `book.js:302, 368, 516, 1070`
- UI: `reading_settings.dart:226-279`
- i18n: `app_en.arb:406-411`, `app_zh-CN.arb:406-411`

## Key Patterns

- Always use enum codes for persistence and JS communication
- Maintain backward compatibility with existing configurations
- Follow reactive patterns: UI change → Prefs update → notifyListeners → immediate application
- Use consistent naming: `configName` in Dart, `config_name` in preferences, `configName` in JS
