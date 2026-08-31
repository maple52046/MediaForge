import 'package:flutter/widgets.dart';

import 'conversion_controller.dart';
import 'conversion_service.dart';
import 'media_metadata.dart';
import 'settings_controller.dart';

/// Bilingual presentation copy selected by the Flutter settings controller.
class MfStrings {
  /// Creates strings for one supported language.
  const MfStrings(this.language);

  /// Language represented by this string table.
  final MfLanguage language;

  bool get _zh => language == MfLanguage.traditionalChinese;

  /// Reads the active string table from the widget tree.
  static MfStrings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MfStringsScope>()?.strings ??
      const MfStrings(MfLanguage.english);

  /// Settings action label.
  String get settings => _zh ? '設定' : 'Settings';

  /// Settings popover title.
  String get interfaceSettings => _zh ? '介面設定' : 'Interface settings';

  /// Close action label.
  String get close => _zh ? '關閉' : 'Close';

  /// Appearance section label.
  String get appearance => _zh ? '外觀' : 'APPEARANCE';

  /// Language section label.
  String get languageLabel => _zh ? '語言' : 'LANGUAGE';

  /// System preference label.
  String get system => _zh ? '系統' : 'System';

  /// Light appearance label.
  String get light => _zh ? '淺色' : 'Light';

  /// Dark appearance label.
  String get dark => _zh ? '深色' : 'Dark';

  /// English language label.
  String get english => 'English';

  /// Traditional Chinese language label.
  String get traditionalChinese => '繁中';

  /// Preference persistence hint.
  String get preferencesPersisted =>
      _zh ? '選擇會自動儲存。' : 'Choices are saved automatically.';

  /// Accessible empty-source action description.
  String get openOrDropSemantics =>
      _zh ? '開啟或拖放影音檔案' : 'Open or drop a video or audio file';

  /// Empty-source headline.
  String get dropMedia => _zh ? '拖放影音檔案' : 'Drop a video or audio file';

  /// Supported source formats hint.
  String get supportedMediaHint => _zh
      ? 'MOV、MP4、M4A、WAV、MP3 · 一次一個來源'
      : 'MOV, MP4, M4A, WAV, and MP3 · one source at a time';

  /// Native source picker action.
  String get openMedia => _zh ? '開啟媒體' : 'Open media';

  /// Desktop drop alternative hint.
  String get fileMenuHint => _zh ? '或將檔案拖到視窗中' : 'or drop a file anywhere';

  /// Active drag headline for source replacement.
  String get dropToReplace =>
      _zh ? '放開以替換目前來源' : 'Drop to replace the current source';

  /// Active drag headline for an empty session.
  String get dropAnywhere =>
      _zh ? '放開以載入媒體' : 'Drop media anywhere in this window';

  /// Probe-before-commit contract shown during replacement.
  String get sourceProbeContract => _zh
      ? '通過 metadata 驗證前，目前來源不會改變。'
      : 'The current source remains unchanged until metadata validation succeeds.';

  /// Cancel action label.
  String get cancel => _zh ? '取消' : 'Cancel';

  /// Source selection action.
  String get chooseMedia => _zh ? '選擇媒體' : 'Choose media';

  /// In-progress probe label.
  String get inspectingMedia => _zh ? '檢查媒體中…' : 'Inspecting media…';

  /// Export pane title.
  String get export => _zh ? '輸出' : 'Export';

  /// Export pane description.
  String get exportCaption =>
      _zh ? '選擇格式與目的地' : 'Choose a format and destination';

  /// Source section label.
  String get source => _zh ? '來源' : 'SOURCE';

  /// Output-mode section label.
  String get outputMode => _zh ? '輸出模式' : 'OUTPUT MODE';

  /// Destination section label.
  String get destination => _zh ? '目的地' : 'DESTINATION';

  /// MP3 quality section label.
  String get mp3Quality => _zh ? 'MP3 品質' : 'MP3 QUALITY';

  /// Container metadata label.
  String get container => _zh ? '容器' : 'Container';

  /// Video metadata label.
  String get video => _zh ? '視訊' : 'Video';

  /// Audio metadata label.
  String get audio => _zh ? '音訊' : 'Audio';

  /// Source replacement action.
  String get replace => _zh ? '替換' : 'Replace';

  /// Source clearing action.
  String get clear => _zh ? '清除' : 'Clear';

  /// Active-job source lock label.
  String get sourceLocked => _zh ? '來源已鎖定' : 'Source locked';

  /// Native directory picker action.
  String get chooseFolder => _zh ? '選擇資料夾' : 'Choose folder';

  /// Editable output filename label.
  String get outputFilename => _zh ? '輸出檔名' : 'Output filename';

  /// Successful terminal-state label.
  String get conversionCompleted => _zh ? '轉檔完成' : 'Conversion completed';

  /// Cancelled terminal-state label.
  String get conversionCancelled => _zh ? '已取消轉檔' : 'Conversion cancelled';

  /// Output estimate label.
  String get estimatedSize => _zh ? '預估大小' : 'Estimated size';

  /// Active conversion title.
  String get converting => _zh ? '轉檔中' : 'Converting';

  /// Cancellation stage label.
  String get cancelling => _zh ? '取消中' : 'Cancelling';

  /// Cancellation button label.
  String get cancellingEllipsis => _zh ? '取消中…' : 'Cancelling…';

  /// Initial conversion step.
  String get preparingMedia => _zh ? '準備媒體' : 'Preparing media';

  /// Existing-file confirmation title.
  String get overwriteTitle => _zh ? '覆寫既有檔案？' : 'Replace existing file?';

  /// Existing-file confirmation message containing the protected path.
  String overwriteMessage(String path) => _zh
      ? '目的地已存在：$path\n只有在你確認後才會覆寫。'
      : 'The destination already exists: $path\nIt will only be replaced after confirmation.';

  /// Confirmed overwrite action.
  String get overwrite => _zh ? '覆寫' : 'Replace';

  /// Video-with-audio mode label.
  String get videoWithAudio => _zh ? '視訊＋音訊' : 'Video + Audio';

  /// Video-only mode label.
  String get videoOnly => _zh ? '僅視訊' : 'Video Only';

  /// Audio-only mode label.
  String get audioOnly => _zh ? '音訊' : 'Audio';

  /// High MP3 quality label.
  String get high => _zh ? '高' : 'High';

  /// Medium MP3 quality label.
  String get medium => _zh ? '中' : 'Medium';

  /// Low MP3 quality label.
  String get low => _zh ? '低' : 'Low';

  /// Primary conversion action.
  String get convertVideoAudio => _zh ? '轉換視訊＋音訊' : 'Convert video + audio';

  /// Video-only conversion action.
  String get convertVideo => _zh ? '轉換視訊' : 'Convert video';

  /// Audio-only conversion action.
  String get convertAudio => _zh ? '轉換音訊' : 'Convert audio';

  /// Header status describing the current migration shell.
  String get flutterApp => _zh ? 'Flutter 應用程式' : 'Flutter app';

  /// Local-processing privacy statement.
  String get localProcessing => _zh
      ? '本機處理 · 媒體不會離開這台 Mac'
      : 'Local processing · your media never leaves this Mac';

  /// Volume label containing the current percentage.
  String volume(int percent) => _zh ? '音量  $percent%' : 'Volume  $percent%';

  /// Preview opening title.
  String get openingPreview => _zh ? '開啟預覽中…' : 'Opening preview…';

  /// Preview decoder initialization detail.
  String get preparingPreview =>
      _zh ? '準備原生 H.264／HEVC 播放' : 'Preparing native H.264 / HEVC playback';

  /// Compact preview-opening status.
  String get openingNativePreview => _zh ? '開啟原生預覽中' : 'Opening native preview';

  /// Compact preview-ready status.
  String get nativePreviewFit =>
      _zh ? '原生預覽  ·  符合視窗' : 'Native preview  ·  Fit';

  /// Preview fallback title.
  String get previewUnavailable => _zh ? '無法預覽' : 'Preview unavailable';

  /// Preview fallback conversion assurance.
  String get conversionStillAvailable =>
      _zh ? '此來源仍可繼續轉檔。' : 'Conversion remains available for this source.';

  /// Timeline trim section title.
  String get trimRange => _zh ? '裁切範圍' : 'Trim range';

  /// Selected-duration label.
  String selectedDuration(String duration) =>
      _zh ? '已選擇 $duration' : '$duration selected';

  /// Start-boundary label.
  String get start => _zh ? '開始' : 'START';

  /// End-boundary label.
  String get end => _zh ? '結束' : 'END';

  /// Set-start action.
  String get setStart => _zh ? '設為開始' : 'Set Start';

  /// Set-end action.
  String get setEnd => _zh ? '設為結束' : 'Set End';

  /// Reset action.
  String get reset => _zh ? '重設' : 'Reset';

  /// Play-selection action.
  String get playSelection => _zh ? '播放選取範圍' : 'Play Selection';

  /// Video codec absence label.
  String get none => _zh ? '無' : 'None';

  /// Active video encoding stage.
  String get encodingVideo => _zh ? '編碼視訊' : 'Encoding video';

  /// Active audio encoding stage.
  String get encodingAudio => _zh ? '編碼音訊' : 'Encoding audio';

  /// H.264 and AAC encoding detail.
  String get encodingH264Aac => _zh ? '編碼 H.264＋AAC' : 'Encoding H.264 + AAC';

  /// H.264-only encoding detail.
  String get encodingH264 => _zh ? '編碼 H.264' : 'Encoding H.264';

  /// MP3 encoding detail containing its selected bitrate.
  String encodingMp3(String bitrate) =>
      _zh ? '編碼 MP3 · $bitrate' : 'Encoding MP3 · $bitrate';

  /// Accessible label for one editable trim boundary.
  String trimTime(String boundary) =>
      _zh ? '編輯$boundary裁切時間' : 'Trim ${boundary.toLowerCase()} time';

  /// MP4 finalization step.
  String get finalizingMp4 => _zh ? '完成 MP4' : 'Finalizing MP4';

  /// MP3 finalization step.
  String get finalizingMp3 => _zh ? '完成 MP3' : 'Finalizing MP3';

  /// Protected-output operational assurance.
  String get protectedOutput => _zh
      ? '正在寫入受保護的暫存檔；轉檔成功前，既有目的檔不會改變。'
      : 'Writing to a protected temporary file. Your existing destination remains unchanged until conversion succeeds.';

  /// Conversion cancellation action.
  String get cancelConversion => _zh ? '取消轉檔' : 'Cancel conversion';

  /// Timeline semantics label.
  String get trimTimeline => _zh ? '裁切時間軸' : 'Trim timeline';

  /// Start-handle semantics label.
  String get startHandle => _zh ? '開始控制點' : 'Start handle';

  /// End-handle semantics label.
  String get endHandle => _zh ? '結束控制點' : 'End handle';

  /// Playhead semantics label.
  String get playhead => _zh ? '播放位置' : 'Playhead';

  /// Selection semantics value containing precise boundaries.
  String selectionSemantics(String start, String end) =>
      _zh ? '選取範圍 $start 到 $end。' : 'Selection $start to $end.';

  /// Assistive action for the start handle.
  String get selectStartHandle => _zh ? '選擇開始控制點' : 'Select start handle';

  /// Assistive action for the end handle.
  String get selectEndHandle => _zh ? '選擇結束控制點' : 'Select end handle';

  /// Assistive action for the playhead.
  String get selectPlayhead => _zh ? '選擇播放位置' : 'Select playhead';

  /// Localizes a stable media-probe failure without exposing its diagnostic cause.
  String mediaProbeError(MediaProbeErrorCode code) => switch (code) {
    MediaProbeErrorCode.unsupportedInput =>
      _zh ? '不支援的媒體來源' : 'Unsupported media source',
    MediaProbeErrorCode.cannotOpenInput =>
      _zh ? '無法開啟來源檔案' : 'Could not open the source file',
    MediaProbeErrorCode.decodeFailed =>
      _zh ? '無法讀取媒體串流' : 'Could not read the media streams',
    MediaProbeErrorCode.encoderUnavailable =>
      _zh ? '需要的編碼器不可用' : 'A required encoder is unavailable',
    MediaProbeErrorCode.invalidTrimRange =>
      _zh ? '裁切範圍無效' : 'The trim range is invalid',
    MediaProbeErrorCode.outputExists =>
      _zh ? '目的檔已存在' : 'The destination already exists',
    MediaProbeErrorCode.outputCreateFailed =>
      _zh ? '無法建立輸出檔案' : 'Could not create the output file',
    MediaProbeErrorCode.diskWriteFailed =>
      _zh ? '無法寫入輸出檔案' : 'Could not write the output file',
    MediaProbeErrorCode.jobActive =>
      _zh ? '已有轉檔工作執行中' : 'Another conversion is already active',
    MediaProbeErrorCode.jobNotFound =>
      _zh ? '找不到轉檔工作' : 'The conversion job was not found',
    MediaProbeErrorCode.cancelled =>
      _zh ? '工作已取消' : 'The operation was cancelled',
    MediaProbeErrorCode.unexpected =>
      _zh ? '發生未預期的錯誤' : 'An unexpected error occurred',
  };

  /// Localizes a stable conversion failure without exposing its diagnostic cause.
  String conversionError(ConversionErrorCode code) => switch (code) {
    ConversionErrorCode.unsupportedInput =>
      _zh ? '此來源不支援所選模式' : 'The source does not support this mode',
    ConversionErrorCode.cannotOpenInput =>
      _zh ? '無法開啟來源檔案' : 'Could not open the source file',
    ConversionErrorCode.decodeFailed =>
      _zh ? '無法解碼來源媒體' : 'Could not decode the source media',
    ConversionErrorCode.encoderUnavailable =>
      _zh ? '需要的編碼器不可用' : 'A required encoder is unavailable',
    ConversionErrorCode.invalidTrimRange =>
      _zh ? '裁切範圍無效' : 'The trim range is invalid',
    ConversionErrorCode.outputExists =>
      _zh ? '目的檔已存在' : 'The destination already exists',
    ConversionErrorCode.outputCreateFailed =>
      _zh ? '無法建立輸出檔案' : 'Could not create the output file',
    ConversionErrorCode.diskWriteFailed =>
      _zh ? '無法寫入輸出檔案' : 'Could not write the output file',
    ConversionErrorCode.jobActive =>
      _zh ? '已有轉檔工作執行中' : 'Another conversion is already active',
    ConversionErrorCode.jobNotFound =>
      _zh ? '找不到轉檔工作' : 'The conversion job was not found',
    ConversionErrorCode.cancelled =>
      _zh ? '轉檔已取消' : 'The conversion was cancelled',
    ConversionErrorCode.unexpected =>
      _zh ? '發生未預期的錯誤' : 'An unexpected error occurred',
  };

  /// Localizes destination validation owned by the Flutter controller.
  String destinationValidation(DestinationValidationError error) =>
      switch (error) {
        DestinationValidationError.emptyDirectory =>
          _zh ? '請選擇輸出資料夾' : 'Choose an output folder',
        DestinationValidationError.emptyFilename =>
          _zh ? '請輸入輸出檔名' : 'Enter an output filename',
        DestinationValidationError.pathSeparator =>
          _zh ? '檔名不能包含路徑分隔符號' : 'The filename cannot contain a path separator',
        DestinationValidationError.wrongExtension =>
          _zh ? '副檔名不符合輸出模式' : 'The extension does not match the output mode',
        DestinationValidationError.sourceCollision =>
          _zh ? '輸出不能覆蓋來源檔案' : 'The output cannot replace the source file',
      };
}

/// Exposes one immutable MediaForge string table to presentation widgets.
class MfStringsScope extends InheritedWidget {
  /// Creates a string-table scope around [child].
  const MfStringsScope({
    required this.strings,
    required super.child,
    super.key,
  });

  /// Active bilingual string table.
  final MfStrings strings;

  @override
  bool updateShouldNotify(MfStringsScope oldWidget) =>
      oldWidget.strings.language != strings.language;
}
