enum AiPadPanelModeEnum {
  auto('auto'),
  dock('dock'),
  bottomSheet('bottomSheet');

  final String code;

  const AiPadPanelModeEnum(this.code);

  static AiPadPanelModeEnum fromCode(String code) {
    switch (code) {
      case 'auto':
        return AiPadPanelModeEnum.auto;
      case 'dock':
        return AiPadPanelModeEnum.dock;
      case 'bottomSheet':
        return AiPadPanelModeEnum.bottomSheet;
      default:
        return AiPadPanelModeEnum.auto;
    }
  }
}
