enum AiDockSideEnum {
  left('left'),
  right('right'),
  bottom('bottom');

  final String code;

  const AiDockSideEnum(this.code);

  static AiDockSideEnum fromCode(String code) {
    switch (code) {
      case 'left':
        return AiDockSideEnum.left;
      case 'right':
        return AiDockSideEnum.right;
      case 'bottom':
        return AiDockSideEnum.bottom;
      default:
        return AiDockSideEnum.right;
    }
  }
}
