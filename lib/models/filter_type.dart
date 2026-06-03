enum PageFilterType {
  color,
  grayscale,
  blackWhite;

  String get storageValue => name;

  static PageFilterType fromStorage(String? v) {
    switch (v) {
      case 'grayscale':
        return PageFilterType.grayscale;
      case 'blackWhite':
        return PageFilterType.blackWhite;
      default:
        return PageFilterType.color;
    }
  }
}
