import 'dart:io';

import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/page/iap_placeholder_page.dart';
import 'package:anx_reader/page/settings_page/appearance.dart';
import 'package:anx_reader/utils/env_var.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Onboarding screen for first-time users
/// Shows introduction pages covering key features and settings
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final GlobalKey<IntroductionScreenState> _introKey =
      GlobalKey<IntroductionScreenState>();
  bool _hasAcceptedPolicy = false;
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return IntroductionScreen(
      key: _introKey,
      globalBackgroundColor: Theme.of(context).scaffoldBackgroundColor,
      allowImplicitScrolling: true,
      infiniteAutoScroll: false,
      pages: [
        _buildWelcomePage(),
        _buildAppearancePage(),
        _buildSyncPage(),
        if (EnvVar.enableAIFeature) _buildAIPage(),
        _buildCompletePage(),
        if (EnvVar.showIapPlaceHolder) _buildIapPlanPage(),
      ],
      onDone: _onIntroEnd,
      onChange: (index) => setState(() => _currentPage = index),
      canProgress: (page) => _hasAcceptedPolicy || page == 0,
      isProgressTap: _hasAcceptedPolicy,
      scrollPhysics: _hasAcceptedPolicy
          ? const BouncingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      showSkipButton: false,
      showBackButton: true,
      showNextButton: true,
      skipOrBackFlex: 0,
      nextFlex: 0,
      showBottomPart: true,
      overrideNext: _buildNextButton(),
      curve: Curves.fastLinearToSlowEaseIn,
      controlsMargin: const EdgeInsets.all(16),
      controlsPadding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 4.0),
      dotsDecorator: DotsDecorator(
        size: const Size(10.0, 10.0),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        activeSize: const Size(22.0, 10.0),
        activeColor: Theme.of(context).colorScheme.primary,
        activeShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(25.0)),
        ),
      ),
      next: Icon(
        Icons.arrow_forward,
        color: Theme.of(context).colorScheme.primary,
      ),
      back: Icon(
        Icons.arrow_back,
        color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
      ),
      done: Text(
        L10n.of(context).onboardingDone,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildNextButton() {
    final bool isFirstPage = _currentPage == 0;
    final Widget child = isFirstPage
        ? const Text('同意')
        : Icon(
            Icons.arrow_forward,
            color: Theme.of(context).colorScheme.primary,
          );

    return TextButton(
      onPressed: () {
        if (isFirstPage && !_hasAcceptedPolicy) {
          setState(() {
            _hasAcceptedPolicy = true;
          });
        }
        _introKey.currentState?.next();
      },
      child: child,
    );
  }

  PageViewModel _buildWelcomePage() {
    return PageViewModel(
      title: '',
      bodyWidget: _buildWelcomeContent(),
      // image: ,
      decoration: _getPageDecoration(),
    );
  }

  Widget _buildWelcomeContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildIconPage(Icons.book_outlined, size: 80),
        SizedBox(height: 24),
        Text(
          L10n.of(context).onboardingWelcomeTitle,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          EnvVar.enableAIFeature
              ? L10n.of(context).onboardingWelcomeBody
              : '一款功能强大的电子书阅读器，支持多种格式，提供跨平台同步能力',
          style: TextStyle(
            fontSize: 19.0,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(200),
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 150),
        _buildAgreementSection(),
      ],
    );
  }

  Widget _buildAgreementSection() {
    final theme = Theme.of(context);
    final baseStyle = TextStyle(
      fontSize: 14,
      color: theme.colorScheme.onSurface,
    );
    final linkStyle = baseStyle.copyWith(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
    );

    return Column(
      children: [
        RichText(
          textAlign: TextAlign.start,
          text: TextSpan(
            style: baseStyle,
            children: [
              const TextSpan(
                text: '本应用不会收集或存储您的任何用户信息，更多细节请阅读并同意',
              ),
              TextSpan(
                text: '用户协议',
                style: linkStyle,
                recognizer: TapGestureRecognizer()
                  ..onTap =
                      () => _openExternalLink('https://anx.anxcye.com/terms'),
              ),
              const TextSpan(text: '和'),
              TextSpan(
                text: '隐私政策',
                style: linkStyle,
                recognizer: TapGestureRecognizer()
                  ..onTap =
                      () => _openExternalLink('https://anx.anxcye.com/privacy'),
              ),
              const TextSpan(text: '。'),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              exit(0);
            },
            child: const Text('拒绝并退出'),
          ),
        ),
      ],
    );
  }

  PageViewModel _buildAppearancePage() {
    return PageViewModel(
      title: '',
      bodyWidget: _buildAppearanceSettings(),
      decoration: _getPageDecoration(),
    );
  }

  PageViewModel _buildSyncPage() {
    return PageViewModel(
      title: L10n.of(context).onboardingSyncTitle,
      bodyWidget: _buildPageWithTip(
        L10n.of(context).onboardingSyncBody,
        L10n.of(context).onboardingSyncTip,
      ),
      image: _buildIconPage(Icons.sync_outlined),
      decoration: _getPageDecoration(),
    );
  }

  PageViewModel _buildAIPage() {
    return PageViewModel(
      title: L10n.of(context).onboardingAiTitle,
      bodyWidget: _buildPageWithTip(
        L10n.of(context).onboardingAiBody,
        L10n.of(context).onboardingAiTip,
      ),
      image: _buildIconPage(Icons.auto_awesome_outlined),
      decoration: _getPageDecoration(),
    );
  }

  PageViewModel _buildIapPlanPage() {
    return PageViewModel(
      title: '',
      bodyWidget: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: const IapPlaceholderContent(),
        ),
      ),
      decoration: _getPageDecoration(),
    );
  }

  PageViewModel _buildCompletePage() {
    return PageViewModel(
      title: L10n.of(context).onboardingCompleteTitle,
      body: L10n.of(context).onboardingCompleteBody,
      image: _buildIconPage(Icons.check_circle_outline),
      decoration: _getPageDecoration(),
    );
  }

  Widget _buildIconPage(IconData icon, {double size = 120}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withAlpha(50),
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(40),
      child: Icon(
        icon,
        size: size,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  PageDecoration _getPageDecoration() {
    return PageDecoration(
      titleTextStyle: TextStyle(
        fontSize: 28.0,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      bodyTextStyle: TextStyle(
        fontSize: 19.0,
        color: Theme.of(context).colorScheme.onSurface.withAlpha(200),
      ),
      bodyPadding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
      pageColor: Theme.of(context).scaffoldBackgroundColor,
      imagePadding: const EdgeInsets.symmetric(vertical: 40.0),
    );
  }

  Widget _buildAppearanceSettings() {
    Widget buildLanguageSelector() {
      final currentLocale = Prefs().locale;
      final currentLanguageCode = currentLocale?.languageCode ?? 'System';
      final currentCountryCode = currentLocale?.countryCode ?? '';
      final currentLanguageTag = currentLanguageCode +
          (currentCountryCode.isNotEmpty ? '-$currentCountryCode' : '');

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.language,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                L10n.of(context).settingsAppearanceLanguage,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withAlpha(100),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              isExpanded: true,
              underline: const SizedBox(),
              value: languageOptions.any(
                      (option) => option.values.first == currentLanguageTag)
                  ? currentLanguageTag
                  : 'system',
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    Prefs().saveLocaleToPrefs(newValue);
                  });
                }
              },
              items: languageOptions
                  .map<DropdownMenuItem<String>>((Map<String, String> option) {
                final displayName = option.keys.first;
                final languageCode = option.values.first;
                return DropdownMenuItem<String>(
                  value: languageCode,
                  child: Text(displayName),
                );
              }).toList(),
            ),
          ),
        ],
      );
    }

    Widget buildThemeColorSelector() {
      final List<Color> themeColors = [
        Colors.purple,
        Colors.indigo,
        Colors.blue,
        Colors.cyan,
        Colors.teal,
        Colors.green,
        Colors.lime,
        Colors.amber,
        Colors.orange,
        Colors.deepOrange,
        Colors.pink,
        Colors.red,
      ]..reversed.toList();

      final currentThemeColor = Prefs().themeColor;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.palette,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                L10n.of(context).settingsAppearanceThemeColor,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: themeColors.length,
            itemBuilder: (context, index) {
              final color = themeColors[index];
              final isSelected =
                  color.toARGB32() == currentThemeColor.toARGB32();

              return GestureDetector(
                onTap: () {
                  setState(() {
                    Prefs().saveThemeToPrefs(color.toARGB32());
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.onSurface
                          : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(30),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                      if (isSelected)
                        BoxShadow(
                          color: color.withAlpha(100),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                    ],
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          color: color.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                          size: 20,
                        )
                      : null,
                ),
              );
            },
          ),
        ],
      );
    }

    return Consumer<Prefs>(
      builder: (context, prefs, child) {
        return SingleChildScrollView(
          child: Column(
            children: [
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withAlpha(50),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.palette_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    L10n.of(context).settingsAppearance,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    L10n.of(context).customizeYourExperience,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha(150),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              buildLanguageSelector(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.contrast,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          L10n.of(context).eInkMode,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          L10n.of(context).optimizedForEInkDisplays,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withAlpha(150),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: prefs.eInkMode,
                    onChanged: (value) {
                      setState(() {
                        if (value) {
                          prefs.saveThemeModeToPrefs('light');
                        }
                        prefs.eInkMode = value;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              buildThemeColorSelector(),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withAlpha(50),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withAlpha(50),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        L10n.of(context).moreDisplayOptionsTip,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(150),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPageWithTip(String bodyText, String tipText) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          bodyText,
          style: TextStyle(
            fontSize: 19.0,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(200),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withAlpha(50),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withAlpha(50),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tipText,
                  style: TextStyle(
                    fontSize: 13,
                    color:
                        Theme.of(context).colorScheme.onSurface.withAlpha(150),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _onIntroEnd() async {
    widget.onComplete();
  }

  Future<void> _openExternalLink(String url) async {
    await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  }
}
