import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/dao/vocabulary.dart';
import 'package:anx_reader/enums/lang_list.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/page/reading_page.dart';
import 'package:anx_reader/service/dictionary/english_dictionary.dart';
import 'package:anx_reader/service/dictionary/pronunciation_player.dart';
import 'package:anx_reader/service/translate/index.dart';
import 'package:anx_reader/service/vocabulary_capture_service.dart';
import 'package:anx_reader/utils/toast/common.dart';
import 'package:anx_reader/widgets/common/axis_flex.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

class TranslationMenu extends StatefulWidget {
  const TranslationMenu({
    super.key,
    required this.content,
    required this.decoration,
    required this.axis,
    this.contextText,
    this.position,
  });
  final String content;
  final BoxDecoration decoration;
  final Axis axis;
  final String? contextText;
  final String? position;

  @override
  State<TranslationMenu> createState() => _TranslationMenuState();
}

class _TranslationMenuState extends State<TranslationMenu> {
  Widget? _translationWidget;
  bool _isAdded = false;
  bool _isAdding = false;
  bool _isLoadingPronunciation = false;
  EnglishDictionaryEntry? _dictionaryEntry;
  int _dictionaryLookupToken = 0;

  @override
  void initState() {
    super.initState();
    _initializeTranslation();
    _loadPronunciation();
    if (_isVocabularyEnabled) {
      _loadVocabularyState();
    }
  }

  @override
  void didUpdateWidget(covariant TranslationMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      _isAdded = false;
      _isAdding = false;
      _dictionaryEntry = null;
      _isLoadingPronunciation = false;
      _translationWidget = null;
      _loadPronunciation();
      _initializeTranslation();
      if (_isVocabularyEnabled) {
        _loadVocabularyState();
      }
    }
  }

  bool get _isVocabularyEnabled => Prefs().bottomNavigatorShowVocabulary;

  void _initializeTranslation() {
    final effectiveContextText = (widget.contextText?.trim().isEmpty ?? true)
        ? null
        : widget.contextText;
    final word = widget.content.trim();
    final preferredService = Prefs().translateService;

    _translationWidget = preferredService.isWebView &&
            EnglishDictionaryService.isEnglishWord(word)
        ? _FastSingleWordTranslation(
            word: word,
            contextText: effectiveContextText,
            preferredService: preferredService,
            fastService: resolveFastTextTranslateService(preferredService),
          )
        : translateText(
            widget.content,
            contextText: effectiveContextText,
          );
  }

  Future<void> _loadVocabularyState() async {
    final existing = await vocabularyDao.selectByWord(widget.content);
    if (!mounted) return;
    setState(() {
      _isAdded = existing != null;
    });
  }

  Future<void> _loadPronunciation() async {
    final word = widget.content.trim();
    final token = ++_dictionaryLookupToken;
    if (!EnglishDictionaryService.isEnglishWord(word)) {
      if (!mounted) return;
      setState(() {
        _dictionaryEntry = null;
        _isLoadingPronunciation = false;
      });
      return;
    }

    setState(() {
      _isLoadingPronunciation = true;
    });

    final entry = await EnglishDictionaryService.lookup(word);
    if (!mounted || token != _dictionaryLookupToken) return;
    setState(() {
      _dictionaryEntry = entry;
      _isLoadingPronunciation = false;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _addToVocabulary() async {
    if (!_isVocabularyEnabled) return;
    if (_isAdding) return;
    final l10n = L10n.of(context);

    final player = epubPlayerKey.currentState;
    final book = player?.book;
    final word = widget.content.trim();
    if (book == null || word.isEmpty) {
      AnxToast.show(l10n.commonFailed);
      return;
    }

    setState(() {
      _isAdding = true;
    });

    VocabularyCaptureResult result;
    try {
      result = await VocabularyCaptureService.capture(
        word: word,
        bookId: book.id.toString(),
        bookTitle: book.title,
        chapterId: player?.chapterHref,
        chapterTitle: player?.chapterTitle,
        contextText: _effectiveContextText,
        position: widget.position,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAdding = false;
      });
      AnxToast.show(l10n.commonFailed);
      return;
    }

    if (!mounted) return;
    setState(() {
      _isAdding = false;
      _isAdded = true;
    });
    AnxToast.show(
      result.created ? l10n.vocabularyAddedToast : l10n.vocabularyAlreadyExists,
    );
  }

  String? get _effectiveContextText {
    return (widget.contextText?.trim().isEmpty ?? true)
        ? null
        : widget.contextText!.trim();
  }

  String _buttonLabel(BuildContext context) {
    if (_isAdding) return L10n.of(context).vocabularyAdding;
    if (_isAdded) return L10n.of(context).vocabularyAdded;
    return L10n.of(context).vocabularyAdd;
  }

  Future<void> _playPronunciation() async {
    final word = widget.content.trim();
    if (word.isEmpty) return;

    try {
      await PronunciationPlayer().play(
        text: word,
        audioUrl: _dictionaryEntry?.audioUrl,
      );
    } catch (_) {
      if (!mounted) return;
      AnxToast.show(L10n.of(context).commonFailed);
    }
  }

  Widget _pronunciationLine(BuildContext context) {
    final entry = _dictionaryEntry;
    if (!_isLoadingPronunciation &&
        (entry == null || (entry.phonetic?.trim().isEmpty ?? true))) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
        );

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: InkWell(
        onTap: _isLoadingPronunciation ? null : _playPronunciation,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isLoadingPronunciation) ...[
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 6),
                Text('IPA ...', style: textStyle),
              ] else ...[
                const Icon(Icons.record_voice_over_outlined, size: 14),
                const SizedBox(width: 5),
                Text(entry!.phonetic!, style: textStyle),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _langPicker(bool isFrom) {
    final MenuController menuController = MenuController();

    return PointerInterceptor(
      child: MenuAnchor(
        style: MenuStyle(
          backgroundColor: WidgetStateProperty.all(
            Theme.of(context).colorScheme.secondaryContainer,
          ),
          maximumSize: WidgetStateProperty.all(const Size(300, 300)),
        ),
        controller: menuController,
        menuChildren: [
          for (var lang in LangListEnum.values)
            PointerInterceptor(
              child: MenuItemButton(
                onPressed: () {
                  if (isFrom) {
                    Prefs().translateFrom = lang;
                  } else {
                    Prefs().translateTo = lang;
                  }
                },
                child: Text(lang.getNative(context)),
              ),
            ),
        ],
        builder: (context, controller, child) {
          return GestureDetector(
            onTap: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            child: Text(
              isFrom
                  ? Prefs().translateFrom.getNative(context)
                  : Prefs().translateTo.getNative(context),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // print('Building TranslationMenu');
    final isVocabularyEnabled = _isVocabularyEnabled;
    return Expanded(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        child: Container(
          height: widget.axis == Axis.vertical ? double.infinity : 150,
          width: widget.axis == Axis.vertical ? 100 : double.infinity,
          decoration: widget.decoration,
          padding: const EdgeInsets.all(8),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.content,
                  style: const TextStyle(
                    fontSize: 16,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _pronunciationLine(context),
                const SizedBox(height: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Show translation widget if initialized, otherwise show loading placeholder
                    _translationWidget ??
                        const SizedBox(
                          height: 20,
                          child: Center(child: Text('...')),
                        ),
                    const Divider(),
                    AxisFlex(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      axis: widget.axis,
                      children: [
                        _langPicker(true),
                        Transform.rotate(
                            angle: widget.axis == Axis.horizontal ? 0 : 1.57,
                            child: Icon(Icons.arrow_forward_ios, size: 16)),
                        _langPicker(false),
                        if (widget.axis == Axis.horizontal) const Spacer(),
                      ],
                    ),
                    if (isVocabularyEnabled) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isAdding ? null : _addToVocabulary,
                          icon: Icon(_isAdded
                              ? Icons.check_circle_outline
                              : Icons.library_add_outlined),
                          label: Text(
                            _buttonLabel(context),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FastSingleWordTranslation extends StatefulWidget {
  const _FastSingleWordTranslation({
    required this.word,
    required this.contextText,
    required this.preferredService,
    required this.fastService,
  });

  final String word;
  final String? contextText;
  final TranslateService preferredService;
  final TranslateService? fastService;

  @override
  State<_FastSingleWordTranslation> createState() =>
      _FastSingleWordTranslationState();
}

class _FastSingleWordTranslationState
    extends State<_FastSingleWordTranslation> {
  late Future<_FastSingleWordData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _FastSingleWordTranslation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.word != widget.word ||
        oldWidget.contextText != widget.contextText ||
        oldWidget.preferredService != widget.preferredService ||
        oldWidget.fastService != widget.fastService) {
      _future = _load();
    }
  }

  Future<_FastSingleWordData> _load() async {
    final dictionaryFuture = EnglishDictionaryService.lookup(widget.word);
    String? translatedText;

    final fastService = widget.fastService;
    if (fastService != null) {
      try {
        translatedText = await translateTextOnlyCached(
          widget.word,
          service: fastService,
          contextText: widget.contextText,
        );
      } catch (_) {
        translatedText = null;
      }
    }

    final dictionaryEntry = await dictionaryFuture;
    return _FastSingleWordData(
      dictionaryEntry: dictionaryEntry,
      translatedText: translatedText,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_FastSingleWordData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final translatedText = data?.translatedText?.trim();
        final dictionaryEntry = data?.dictionaryEntry;
        final definitionEn = dictionaryEntry?.definitionEn?.trim();
        final partOfSpeech = dictionaryEntry?.partOfSpeech?.trim();

        if (translatedText != null && translatedText.isNotEmpty) {
          return Text(translatedText);
        }

        if (definitionEn != null && definitionEn.isNotEmpty) {
          final prefix = (partOfSpeech != null && partOfSpeech.isNotEmpty)
              ? '$partOfSpeech '
              : '';
          return Text('$prefix$definitionEn');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 20,
            child: Center(child: Text('...')),
          );
        }

        return translateText(
          widget.word,
          service: widget.preferredService,
          contextText: widget.contextText,
        );
      },
    );
  }
}

class _FastSingleWordData {
  const _FastSingleWordData({
    required this.dictionaryEntry,
    required this.translatedText,
  });

  final EnglishDictionaryEntry? dictionaryEntry;
  final String? translatedText;
}
