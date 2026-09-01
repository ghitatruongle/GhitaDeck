// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Ghita PPT Converter';

  @override
  String get homeTitle => 'Home';

  @override
  String get editorTitle => 'Editor';

  @override
  String get projectsTitle => 'Projects';

  @override
  String get templatesTitle => 'Templates';

  @override
  String get aiChatTitle => 'AI Chat';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get newSlide => 'New Slide';

  @override
  String get duplicate => 'Duplicate';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get export => 'Export';

  @override
  String get import => 'Import';

  @override
  String get undo => 'Undo';

  @override
  String get redo => 'Redo';

  @override
  String get present => 'Present';

  @override
  String get presentFromCurrent => 'From Current';

  @override
  String get presentation => 'Presentation';

  @override
  String get slides => 'Slides';

  @override
  String slideCount(int count) {
    return 'Slides ($count)';
  }

  @override
  String get noSlidesYet => 'No slides yet';

  @override
  String get clickToAddSlide => 'Click + to add a slide';

  @override
  String get title => 'Title';

  @override
  String get content => 'Content';

  @override
  String get notes => 'Notes';

  @override
  String get addSlideTooltip => 'Add new slide';

  @override
  String get deleteSlideTooltip => 'Delete slide';

  @override
  String get duplicateSlideTooltip => 'Duplicate slide';

  @override
  String get previewTooltip => 'Preview slide';

  @override
  String get editSlide => 'Edit Slide';

  @override
  String get preview => 'Preview';

  @override
  String get cancel => 'Cancel';

  @override
  String get ok => 'OK';

  @override
  String get apply => 'Apply';

  @override
  String get close => 'Close';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Error';

  @override
  String get success => 'Success';

  @override
  String get warning => 'Warning';

  @override
  String get info => 'Information';

  @override
  String get connectionError =>
      'Network connection error. Please check your internet.';

  @override
  String get timeoutError => 'Request timed out. Please try again.';

  @override
  String get invalidFile => 'Invalid file format.';

  @override
  String get fileNotFound => 'File not found.';

  @override
  String get permissionDenied => 'Permission denied.';

  @override
  String get unknownError => 'Unknown error';

  @override
  String get saveSuccess => 'Saved successfully';

  @override
  String get exportSuccess => 'Exported successfully';

  @override
  String get importSuccess => 'Imported successfully';

  @override
  String get deleteSuccess => 'Deleted successfully';

  @override
  String get duplicateSuccess => 'Duplicated successfully';

  @override
  String deletedWithUndo(String title) {
    return 'Deleted \"$title\"';
  }

  @override
  String get undoAction => 'Undo';

  @override
  String get addNewProvider => 'Add New';

  @override
  String get details => 'Details';

  @override
  String apiKeySaved(String name) {
    return 'API Key saved for $name';
  }

  @override
  String get apiKeyHint => 'API Key...';

  @override
  String get saveApiKeyTooltip => 'Save API Key';

  @override
  String get exportBackup => 'Export Configuration (JSON)';

  @override
  String get importBackup => 'Import Configuration (JSON)';

  @override
  String get saveBackup => 'Save backup';

  @override
  String get restoreSettings => 'Restore settings?';

  @override
  String restoreSettingsMessage(String date, int count) {
    return 'Backup from $date.\nNumber of providers: $count\n\nCurrent settings will be overwritten. Continue?';
  }

  @override
  String get restore => 'Restore';

  @override
  String backupExported(String filename) {
    return 'Backup exported successfully: $filename';
  }

  @override
  String get settingsRestored => 'Settings restored successfully!';

  @override
  String get about => 'About';

  @override
  String get appearance => 'Appearance';

  @override
  String get interfaceMode => 'Interface Mode';

  @override
  String currentMode(String mode) {
    return 'Current: $mode';
  }

  @override
  String get lightMode => 'Light';

  @override
  String get darkMode => 'Dark';

  @override
  String get autoMode => 'Auto';

  @override
  String get lightModeFull => 'Light Mode';

  @override
  String get darkModeFull => 'Dark Mode';

  @override
  String get systemMode => 'System (Auto)';

  @override
  String get themeSettings => 'Theme Settings';

  @override
  String get customTheme => 'Customize Theme';

  @override
  String get customThemeSubtitle => 'Colors, fonts, preset themes';

  @override
  String get presetThemes => 'Preset Themes';

  @override
  String get customColors => 'Custom Colors';

  @override
  String get primaryColor => 'Primary Color';

  @override
  String get accentColor => 'Accent Color';

  @override
  String get typography => 'Typography';

  @override
  String get fontFamily => 'Font Family';

  @override
  String get exportTheme => 'Export theme';

  @override
  String get importTheme => 'Import theme';

  @override
  String get resetToDefault => 'Reset to default';

  @override
  String get themeResetMessage => 'Theme reset to Office Blue';

  @override
  String themeAppliedMessage(String name) {
    return 'Applied $name preset';
  }

  @override
  String get themeCopied => 'Theme copied to clipboard!';

  @override
  String get themeImported => 'Theme imported successfully!';

  @override
  String get themeImportFailed => 'Failed to import theme. Invalid format.';

  @override
  String get clipboardEmpty => 'Clipboard is empty';

  @override
  String get pickColor => 'Pick a color';

  @override
  String get pickColorTooltip => 'Pick color';

  @override
  String get officeBlue => 'Office Blue';

  @override
  String get officeBlueDesc => 'Classic Microsoft Office';

  @override
  String get darkProfessional => 'Dark Professional';

  @override
  String get darkProfessionalDesc => 'Elegant dark theme';

  @override
  String get lightMinimal => 'Light Minimal';

  @override
  String get lightMinimalDesc => 'Clean and minimal';

  @override
  String get custom => 'Custom';

  @override
  String get customDesc => 'Your custom theme';

  @override
  String get version => 'Version';

  @override
  String versionInfo(String version, String year) {
    return '$version • Build $year';
  }

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get vietnamese => 'Tiếng Việt';

  @override
  String get aiProvider => 'API Key & AI Provider';

  @override
  String get backupRestore => 'Backup & Restore';

  @override
  String get infoSection => 'Information';

  @override
  String get addNew => 'Add New';

  @override
  String get recentProjects => 'Recent Projects';

  @override
  String get noRecentProjects => 'No recent projects';

  @override
  String get openProject => 'Open Project';

  @override
  String get removeFromList => 'Remove from list';

  @override
  String get removeAll => 'Remove All';

  @override
  String get confirmRemoveAll => 'Remove all recent projects?';

  @override
  String get search => 'Search';

  @override
  String get templates => 'Templates';

  @override
  String get noTemplates => 'No templates available';

  @override
  String get useTemplate => 'Use Template';

  @override
  String get aiChat => 'AI Chat';

  @override
  String get typeMessage => 'Type your message...';

  @override
  String get send => 'Send';

  @override
  String get regenerate => 'Regenerate';

  @override
  String get stop => 'Stop';

  @override
  String get clearChat => 'Clear Chat';

  @override
  String get clearChatConfirm => 'Clear chat history?';

  @override
  String get selectProvider => 'Select AI Provider';

  @override
  String get noProviders => 'No AI providers configured';

  @override
  String get addProviderFirst => 'Add a provider in Settings first';

  @override
  String get copy => 'Copy';

  @override
  String get paste => 'Paste';

  @override
  String get cut => 'Cut';

  @override
  String get selectAll => 'Select All';

  @override
  String get bold => 'Bold';

  @override
  String get italic => 'Italic';

  @override
  String get underline => 'Underline';

  @override
  String get strikethrough => 'Strikethrough';

  @override
  String get alignLeft => 'Align Left';

  @override
  String get alignCenter => 'Align Center';

  @override
  String get alignRight => 'Align Right';

  @override
  String get alignJustify => 'Justify';

  @override
  String get bulletList => 'Bullet List';

  @override
  String get numberedList => 'Numbered List';

  @override
  String get indent => 'Indent';

  @override
  String get outdent => 'Outdent';

  @override
  String get link => 'Link';

  @override
  String get image => 'Image';

  @override
  String get table => 'Table';

  @override
  String get code => 'Code';

  @override
  String get format => 'Format';

  @override
  String get help => 'Help';

  @override
  String get shortcuts => 'Keyboard Shortcuts';

  @override
  String get exitPresentation => 'Exit Presentation';

  @override
  String get nextSlide => 'Next Slide';

  @override
  String get previousSlide => 'Previous Slide';

  @override
  String get firstSlide => 'First Slide';

  @override
  String get lastSlide => 'Last Slide';

  @override
  String get aiTools => 'AI Tools';

  @override
  String get improveWriting => 'Improve Writing';

  @override
  String get fixGrammar => 'Fix Grammar';

  @override
  String get makeShorter => 'Make Shorter';

  @override
  String get makeLonger => 'Make Longer';

  @override
  String translateTo(String language) {
    return 'Translate to $language';
  }

  @override
  String get summary => 'Summary';

  @override
  String get generateSlides => 'Generate Slides';

  @override
  String get fromText => 'From Text';

  @override
  String get fromTopic => 'From Topic';

  @override
  String get topic => 'Topic';

  @override
  String get slideCountQuestion => 'How many slides?';

  @override
  String get style => 'Style';

  @override
  String get professional => 'Professional';

  @override
  String get casual => 'Casual';

  @override
  String get academic => 'Academic';

  @override
  String get creative => 'Creative';

  @override
  String get files => 'Files';

  @override
  String get addFiles => 'Add Files';

  @override
  String get noFiles => 'No files';

  @override
  String get fileName => 'File Name';

  @override
  String get fileSize => 'Size';

  @override
  String get fileType => 'Type';

  @override
  String get uploadedAt => 'Uploaded';

  @override
  String get collaboration => 'Collaboration';

  @override
  String get startSession => 'Start Session';

  @override
  String get joinSession => 'Join Session';

  @override
  String get sessionCode => 'Session Code';

  @override
  String get host => 'Host';

  @override
  String get join => 'Join';

  @override
  String get leave => 'Leave';

  @override
  String get audio => 'Audio';

  @override
  String get startRecording => 'Start Recording';

  @override
  String get stopRecording => 'Stop Recording';

  @override
  String get playRecording => 'Play Recording';

  @override
  String get deleteRecording => 'Delete Recording';

  @override
  String get audioRecorded => 'Audio recorded';

  @override
  String get recordings => 'Recordings';

  @override
  String get noRecordings => 'No recordings yet';

  @override
  String get advancedExport => 'Advanced Export';

  @override
  String get exportFormat => 'Export Format';

  @override
  String get aspectRatio => 'Aspect Ratio';

  @override
  String get quality => 'Quality';

  @override
  String get exportOptions => 'Options';

  @override
  String get includeSpeakerNotes => 'Include speaker notes';

  @override
  String get includeBackgrounds => 'Include backgrounds';

  @override
  String get slidesToExport => 'Slides to Export';

  @override
  String get allSlides => 'All slides';

  @override
  String selectedSlides(int count) {
    return 'Selected ($count)';
  }

  @override
  String get exporting => 'Exporting...';

  @override
  String exportSuccessful(String summary) {
    return 'Export successful: $summary';
  }

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get chooseAtLeastOneSlide =>
      'Select at least one slide or choose \"All slides\".';

  @override
  String get chooseTemplate => 'Choose a Template';

  @override
  String get htmlPreview => 'HTML Preview:';

  @override
  String get useThisTemplate => 'Use This Template';

  @override
  String get clearAllSlides => 'Clear All Slides';

  @override
  String clearAllSlidesMessage(int count) {
    return 'Are you sure you want to delete all $count slides? This action cannot be undone.';
  }

  @override
  String get deletedAllSlides => 'Deleted all slides';

  @override
  String get untitledPresentation => 'Untitled Presentation';

  @override
  String get hideSidebar => 'Hide Sidebar';

  @override
  String get showSidebar => 'Show Sidebar';

  @override
  String get toggleTheme => 'Toggle Theme';

  @override
  String get slideEditor => 'Slide Editor';

  @override
  String get navigation => 'Navigation';

  @override
  String get system => 'System';

  @override
  String get noSlides => 'There are no slides to present.';

  @override
  String get startCollaboration => 'Start collaboration';

  @override
  String get stopCollaboration => 'Stop collaboration';

  @override
  String get leaveCollaboration => 'Leave session';

  @override
  String get hostCollaboration => 'Host a collaboration session';

  @override
  String get hostCollaborationDescription =>
      'Share the current presentation with trusted people on this local network.';

  @override
  String get joinCollaboration => 'Join a session';

  @override
  String get hostOrShareLink => 'Host IP or share link';

  @override
  String get port => 'Port';

  @override
  String get displayName => 'Display name';

  @override
  String get sessionToken => 'Session token';

  @override
  String get connect => 'Connect';

  @override
  String get collaborationHosting => 'Hosting a protected session';

  @override
  String get collaborationConnected => 'Connected and syncing';

  @override
  String collaborationRevision(int revision) {
    return 'Revision $revision';
  }

  @override
  String collaborationParticipants(int count) {
    return 'Participants: $count';
  }

  @override
  String get collaborationSecurityNotice =>
      'Only share the link or token with trusted people on your local network.';

  @override
  String get collaborationStartFailed =>
      'Could not start the protected local server. Check the port and firewall.';

  @override
  String get collaborationJoinFields =>
      'Enter a host/share link and session token.';

  @override
  String get collaborationJoinFailed =>
      'Could not authenticate or connect to this session.';

  @override
  String get collaborationJoined => 'Connected. Slides are now synchronized.';

  @override
  String get collaborationLinkCopied => 'Protected share link copied.';

  @override
  String get collaborationConflict =>
      'A newer revision was found. The authoritative host version was restored.';

  @override
  String get collaborationAuthFailed =>
      'The collaboration token is no longer valid.';

  @override
  String slideListSemantics(int count) {
    return 'Slide list, $count slides';
  }

  @override
  String slideSemanticLabel(int number, String title) {
    return 'Slide $number: $title';
  }

  @override
  String get slideSemanticHint =>
      'Activate to edit. Long press for more actions.';

  @override
  String get workspaceSemantics => 'GhitaPPT presentation workspace';

  @override
  String exportProgress(int done, int total) {
    return 'Exporting… $done/$total';
  }

  @override
  String get exportCancel => 'Cancel export';

  @override
  String get exportCancelDescription =>
      'Stop the running export and discard its output.';

  @override
  String get fitContent => 'Fit content on slides';

  @override
  String get fitContentDescription =>
      'Shrink overflowing text so the whole deck fits its slides.';

  @override
  String get loadingRemoteImages => 'Loading images from the web…';

  @override
  String remoteImageLoadFailed(String name) {
    return 'Could not load image $name';
  }

  @override
  String get exportThemePreview => 'Exported files will use this theme';

  @override
  String get exportThemePreviewDescription =>
      'Shows the clrScheme and fonts written into exported PPTX files.';

  @override
  String get layout => 'Layout';

  @override
  String get layoutBlank => 'Blank';

  @override
  String get layoutTitleSlide => 'Title Slide';

  @override
  String get layoutTitleAndContent => 'Title and Content';

  @override
  String get layoutSectionHeader => 'Section Header';

  @override
  String get layoutTwoContent => 'Two Content';

  @override
  String get layoutComparison => 'Comparison';

  @override
  String get layoutTitleOnly => 'Title Only';

  @override
  String get layoutContentAndCaption => 'Content and Caption';

  @override
  String get layoutPictureAndCaption => 'Picture with Caption';

  @override
  String layoutApplied(String name) {
    return 'Layout applied: $name';
  }

  @override
  String get pdfPaperSize => 'PDF paper size';

  @override
  String get pdfPaperMatchSlide => 'Match slide';

  @override
  String get pdfPaperA4 => 'A4';

  @override
  String get pdfPaperLetter => 'Letter';

  @override
  String get pdfMargins => 'Page margins';

  @override
  String get pdfMarginCompact => 'Compact';

  @override
  String get pdfMarginStandard => 'Standard';

  @override
  String get pdfMarginWide => 'Wide';

  @override
  String get pdfScaleToFit => 'Scale to fit page';

  @override
  String get includeHiddenSlides => 'Include hidden slides';

  @override
  String get insertChart => 'Insert chart';

  @override
  String get editChart => 'Edit chart';

  @override
  String get chartTitle => 'Chart title';

  @override
  String get chartCategories => 'Categories (comma separated)';

  @override
  String get chartSeriesName => 'Series name';

  @override
  String get chartSeriesValues => 'Values (comma separated)';

  @override
  String get chartLegend => 'Legend';

  @override
  String get chartDataLabels => 'Data labels';

  @override
  String get chartStacked => 'Stacked';

  @override
  String get chartExisting => 'Charts in this slide';

  @override
  String get chartPreview => 'Preview';

  @override
  String get chartInserted => 'Chart inserted';

  @override
  String get chartUpdated => 'Chart updated';

  @override
  String get chartAddSeries => 'Add series';

  @override
  String get chartUpdate => 'Update chart';

  @override
  String get chartColumn => 'Column';

  @override
  String get chartBar => 'Bar';

  @override
  String get chartLine => 'Line';

  @override
  String get chartPie => 'Pie';

  @override
  String get chartArea => 'Area';

  @override
  String get chartDonut => 'Donut';

  @override
  String get chartCombo => 'Combo';

  @override
  String get chartTreemap => 'Treemap';

  @override
  String get chartSunburst => 'Sunburst';

  @override
  String get chartHistogram => 'Histogram';

  @override
  String get chartBoxWhisker => 'Box & Whisker';

  @override
  String get chartWaterfall => 'Waterfall';

  @override
  String get chartFunnel => 'Funnel';

  @override
  String get chartMap => 'Map';

  @override
  String get chartData => 'Chart data';

  @override
  String get gridAddRow => 'Add row';

  @override
  String get gridRemoveRow => 'Remove row';

  @override
  String get gridAddSeries => 'Add series';

  @override
  String get gridRemoveSeries => 'Remove series';

  @override
  String get gridQuickFill => 'Quick fill';

  @override
  String get gridPasteCsv => 'Paste CSV';

  @override
  String get insertSmartArt => 'Insert SmartArt';

  @override
  String get editSmartArt => 'Edit SmartArt';

  @override
  String get smartartTitle => 'Diagram title';

  @override
  String get smartartLayouts => 'Layouts';

  @override
  String get smartartNodes => 'Text pane';

  @override
  String get smartartNode => 'Node';

  @override
  String get smartartAddNode => 'Add node';

  @override
  String get smartartRemoveNode => 'Remove node';

  @override
  String get smartartColorTheme => 'Color theme';

  @override
  String get smartartExisting => 'SmartArt in this slide';

  @override
  String get smartartInserted => 'SmartArt inserted';

  @override
  String get smartartUpdated => 'SmartArt updated';

  @override
  String get smartartGroupList => 'List';

  @override
  String get smartartGroupProcess => 'Process';

  @override
  String get smartartGroupCycle => 'Cycle';

  @override
  String get smartartGroupHierarchy => 'Hierarchy';

  @override
  String get smartartGroupRelationship => 'Relationship';

  @override
  String get smartartGroupMatrix => 'Matrix';

  @override
  String get smartartGroupPyramid => 'Pyramid';

  @override
  String get smartartGroupPicture => 'Picture';

  @override
  String get insertVideo => 'Insert video';

  @override
  String get editVideo => 'Edit video';

  @override
  String get videoInserted => 'Video inserted';

  @override
  String get videoUpdated => 'Video updated';

  @override
  String get videoExisting => 'Videos in this slide';

  @override
  String get videoFromFile => 'MP4 file';

  @override
  String get videoFromYoutube => 'YouTube link';

  @override
  String get videoPickFile => 'Choose MP4 file…';

  @override
  String get videoYoutubeUrl => 'YouTube URL';

  @override
  String get videoInvalidUrl => 'This is not a valid YouTube link';

  @override
  String get videoTrimStart => 'Start (m:ss)';

  @override
  String get videoTrimEnd => 'End (m:ss)';

  @override
  String get videoNoFfmpeg =>
      'FFmpeg not found — trim timestamps are kept for the HTML player only';

  @override
  String get videoAutoplay => 'Play automatically';

  @override
  String get videoLoop => 'Loop';

  @override
  String get videoPoster => 'Poster frame';

  @override
  String get videoChoosePoster => 'Choose poster…';

  @override
  String get videoChangePoster => 'Change poster…';

  @override
  String get videoRemovePoster => 'Remove poster';

  @override
  String get videoBookmarks => 'Bookmarks';

  @override
  String get videoAddBookmark => 'Add bookmark';

  @override
  String get videoRemoveBookmark => 'Remove bookmark';

  @override
  String get videoBookmarkLabel => 'Label';

  @override
  String get videoBookmarkTime => 'Time (m:ss)';

  @override
  String get recordScreen => 'Record screen';

  @override
  String get recordInserted => 'Recording inserted';

  @override
  String get recordModeFullscreen => 'Full screen';

  @override
  String get recordModeWindow => 'Window';

  @override
  String get recordModeRegion => 'Region';

  @override
  String get recordWindowSelect => 'Window';

  @override
  String get recordWindowEmpty =>
      'No visible windows found — minimize or restore a window and retry.';

  @override
  String get recordWindowRequired => 'Choose a window to record.';

  @override
  String get recordRegionX => 'X';

  @override
  String get recordRegionY => 'Y';

  @override
  String get recordRegionW => 'Width';

  @override
  String get recordRegionH => 'Height';

  @override
  String get recordRegionRequired =>
      'Enter a region width and height greater than 0.';

  @override
  String get recordRegionHint =>
      'Coordinates are in screen pixels (top-left origin).';

  @override
  String get recordStart => 'Start recording';

  @override
  String get recordCountdown => 'Recording starts in…';

  @override
  String get recordRecording => 'recording';

  @override
  String get recordPaused => 'paused';

  @override
  String get recordPause => 'Pause';

  @override
  String get recordResume => 'Resume';

  @override
  String get recordStop => 'Stop';

  @override
  String get recordDuration => 'Duration';

  @override
  String get recordSize => 'Size';

  @override
  String get recordLimit => 'Limit';

  @override
  String get recordMinutes => 'min';

  @override
  String get recordPreviewHint =>
      'Poster frame preview — insert this recording into the slide.';

  @override
  String get recordInsert => 'Insert into slide';

  @override
  String get recordDiscard => 'Discard';

  @override
  String get recordNoFfmpeg =>
      'Screen recording needs FFmpeg on this computer. Install FFmpeg (ffmpeg.org) and add it to PATH, then restart the app.';

  @override
  String get recordFailed => 'Recording failed — please try again.';

  @override
  String get recordDiskLowTitle => 'Low disk space';

  @override
  String get recordDiskLowBody =>
      'Less than 500 MB of free space on the drive. Recording may stop unexpectedly.';

  @override
  String get recordContinue => 'Record anyway';

  @override
  String get recordMaxDurationReached =>
      'Maximum recording duration reached — stopped automatically.';

  @override
  String get recordMaxSizeReached =>
      'Maximum file size reached — stopped automatically.';

  @override
  String get audioRecordNarration => 'Record narration for this slide';

  @override
  String get audioNoNarration => 'No narration yet';

  @override
  String get audioDuration => 'Duration';

  @override
  String get audioTrimApply => 'Trim';

  @override
  String get audioTrimNoFfmpeg =>
      'FFmpeg not found — trim timestamps kept for the HTML player only';

  @override
  String get audioAutoplay => 'Auto';

  @override
  String get audioLoop => 'Loop';

  @override
  String get audioAcrossSlides => 'Across slides';

  @override
  String get audioHideIcon => 'Hide icon';

  @override
  String get audioRemove => 'Remove narration';

  @override
  String get insertModel3d => 'Insert 3D model';

  @override
  String get editModel3d => 'Edit 3D model';

  @override
  String get model3dInserted => '3D model inserted';

  @override
  String get model3dUpdated => '3D model updated';

  @override
  String get model3dExisting => '3D models in this slide';

  @override
  String get model3dPickFile => 'Choose GLB file…';

  @override
  String get model3dInvalidFile => 'This is not a valid GLB (glTF binary) file';

  @override
  String get model3dName => 'Model name';

  @override
  String get model3dRotate => 'Auto-rotate on slide entry';

  @override
  String get model3dRotateHint =>
      'Plays the model\'s first embedded animation (requires a GLB with animations)';

  @override
  String get insertIcon => 'Insert icon';

  @override
  String get iconSearch => 'Search icons...';

  @override
  String get iconRecent => 'Recent';

  @override
  String get iconColor => 'Color';

  @override
  String get iconNoResults => 'No icons match your search';

  @override
  String get iconInserted => 'Icon inserted';

  @override
  String get insertStockMedia => 'Stock media';

  @override
  String get mediaSearch => 'Search images...';

  @override
  String get mediaNoResults => 'No images match your search';

  @override
  String get mediaInserted => 'Image inserted';

  @override
  String get screenshot => 'Screenshot';

  @override
  String get screenshotFullscreen => 'Full screen';

  @override
  String get screenshotWindow => 'Window';

  @override
  String get screenshotRegion => 'Region';

  @override
  String get screenshotRegionHint =>
      'Coordinates are in screen pixels (top-left origin).';

  @override
  String get screenshotCapture => 'Capture';

  @override
  String get screenshotRecapture => 'Recapture';

  @override
  String get screenshotFailed =>
      'Screenshot failed. Check that a display is active, then retry.';

  @override
  String get screenshotUse => 'Use screenshot';

  @override
  String get screenshotInserted => 'Screenshot inserted';

  @override
  String get screenshotCropHint =>
      'You can crop the screenshot in the next step.';

  @override
  String get photoAlbum => 'Photo Album';

  @override
  String get photoAlbumEmpty =>
      'Choose images to build your photo album slides.';

  @override
  String get photoAlbumPick => 'Choose images...';

  @override
  String get photoAlbumCount => 'images';

  @override
  String get photoAlbumCaption => 'Caption';

  @override
  String get photoAlbumFrame => 'Frame';

  @override
  String get photoAlbumTransition => 'Transition';

  @override
  String get photoAlbumCreate => 'Create slides';

  @override
  String photoAlbumCreated(Object count) {
    return 'Created $count slides from photos';
  }

  @override
  String get freeTextAdd => 'Add text box';

  @override
  String get freeTextEdit => 'Edit text box';

  @override
  String get freeTextContent => 'Text content';

  @override
  String get freeTextFontSize => 'Font size';

  @override
  String get freeTextColor => 'Color';

  @override
  String get freeTextBg => 'Background';

  @override
  String get freeTextBorder => 'Border';

  @override
  String get freeTextShadow => 'Shadow';

  @override
  String get freeTextWordArt => 'WordArt style';

  @override
  String get freeTextAdded => 'Text box added';

  @override
  String get actionButton => 'Action button';

  @override
  String get actionButtonKind => 'Button type';

  @override
  String get actionButtonAction => 'Action';

  @override
  String get actionButtonLabel => 'Label';

  @override
  String get actionButtonUrl => 'URL';

  @override
  String get actionButtonColor => 'Color';

  @override
  String get actionButtonInsert => 'Insert button';

  @override
  String get actionButtonInserted => 'Action button inserted';

  @override
  String get equation => 'Equation';

  @override
  String get equationTemplate => 'Template';

  @override
  String get equationCustom => 'Custom MathML';

  @override
  String get equationInsert => 'Insert equation';

  @override
  String get equationInserted => 'Equation inserted';

  @override
  String get symbol => 'Symbol';

  @override
  String get symbolSearch => 'Search symbols';

  @override
  String get symbolNoResults => 'No symbols match';

  @override
  String get symbolInserted => 'Symbol inserted';

  @override
  String get ole => 'OLE object';

  @override
  String get olePickFile => 'Choose file... (xlsx, docx, pdf, pptx)';

  @override
  String get olePickHint =>
      'Embed a spreadsheet, document, or PDF into the slide. Double-click in PowerPoint to open it.';

  @override
  String get oleLabel => 'Icon label';

  @override
  String get oleInsert => 'Embed';

  @override
  String get oleInserted => 'OLE object embedded';

  @override
  String get headerFooter => 'Header & Footer';

  @override
  String get hfHeader => 'Header';

  @override
  String get hfFooter => 'Footer';

  @override
  String get hfSlideNumber => 'Slide number';

  @override
  String get hfDateTime => 'Date & time';

  @override
  String get hfDateTimeAuto => 'Update automatically (dynamic)';

  @override
  String get hfDateTimeFormat => 'Date format';

  @override
  String get hfExcludeFirst => 'Don\'t show on title slide';

  @override
  String get hfApplyToSlide => 'Apply to this slide';

  @override
  String get hfApplyToAll => 'Apply to all';

  @override
  String get hfApplied => 'Header & Footer updated';

  @override
  String get zoom => 'Slide Zoom';

  @override
  String get zoomTargetSlide => 'Target slide';

  @override
  String get zoomFrameStyle => 'Frame style';

  @override
  String get zoomLabel => 'Label';

  @override
  String get zoomLabelHint => 'Optional label';

  @override
  String get zoomInsert => 'Insert zoom';

  @override
  String get zoomInserted => 'Slide zoom inserted';

  @override
  String get cameo => 'Cameo';

  @override
  String get cameoLabel => 'Camera label';

  @override
  String get cameoInsert => 'Insert cameo';

  @override
  String get cameoInserted => 'Cameo inserted';

  @override
  String get shape => 'Shape';

  @override
  String get shapeInserted => 'Shape inserted';

  @override
  String get shapeType => 'Type';

  @override
  String get shapeFillColor => 'Fill color';

  @override
  String get shapeStrokeColor => 'Stroke color';

  @override
  String get shapeStrokeWidth => 'Stroke width';

  @override
  String get shapeInsert => 'Insert shape';

  @override
  String get shapeEditPoints => 'Edit Points';

  @override
  String get shapeAddPoint => 'Add point';

  @override
  String get shapeDeletePoint => 'Delete point';

  @override
  String get shapePoint => 'Point';

  @override
  String get shapeProperties => 'Shape Properties';

  @override
  String get shapePropertiesUpdated => 'Shape properties updated';

  @override
  String get shapeNoSelection => 'No shape selected';

  @override
  String get shapeTransparency => 'Transparency';

  @override
  String get shapeShadow => 'Shadow';

  @override
  String get shapeGradient => 'Gradient fill';

  @override
  String get shapeGradientStart => 'Gradient start';

  @override
  String get shapeGradientEnd => 'Gradient end';

  @override
  String get shapeGradientAngle => 'Gradient angle';

  @override
  String get shapeMerge => 'Merge shapes';

  @override
  String get shapeMergeNeedTwo => 'Add at least two shapes to merge';

  @override
  String get shapeMergeHint =>
      'Select two shapes (click, Shift+click for multi-select), then choose the boolean operation:';

  @override
  String get shapeMergeUnion => 'Union';

  @override
  String get shapeMergeCombine => 'Combine (XOR)';

  @override
  String get shapeMergeIntersect => 'Intersect';

  @override
  String get shapeMergeSubtract => 'Subtract';

  @override
  String get shapeMergeEmpty => 'The merge produced an empty result';

  @override
  String get shapeMerged => 'Shapes merged';

  @override
  String get shapeScribble => 'Draw freeform';

  @override
  String get zoomSlide => 'Slide Zoom';

  @override
  String get zoomSection => 'Section / Summary Zoom';

  @override
  String get zoomPickSlides =>
      'Pick the slides to include in the grid (min 2):';

  @override
  String get zoomColumns => 'Columns:';

  @override
  String get imageTabBasic => 'Basic';

  @override
  String get imageTabCrop => 'Crop';

  @override
  String get imageTabBackground => 'Remove BG';

  @override
  String get imageTabAdjust => 'Adjust';

  @override
  String get imageTabArtistic => 'Artistic';

  @override
  String get imageCropAspect => 'Aspect ratio';

  @override
  String get imageAspectNone => 'Free';

  @override
  String get imageAspectSquare => '1:1';

  @override
  String get imageAspect169 => '16:9';

  @override
  String get imageAspect32 => '3:2';

  @override
  String get imageAspect43 => '4:3';

  @override
  String get imageCropApply => 'Apply crop';

  @override
  String get imageCropShape => 'Crop to shape';

  @override
  String get imageShapeRect => 'Rectangle';

  @override
  String get imageShapeOval => 'Oval';

  @override
  String get imageShapeRounded => 'Rounded rect';

  @override
  String get imageShapeTriangle => 'Triangle';

  @override
  String get imageShapeDiamond => 'Diamond';

  @override
  String get imageShapeHeart => 'Heart';

  @override
  String get imageRemoveBg => 'Remove background';

  @override
  String get imageBgHint =>
      'The flood-fill removes the colour around the seed point. Pick the seed position and tolerance, then apply.';

  @override
  String get imageTolerance => 'Tolerance';

  @override
  String get imageSeedX => 'Seed X (%)';

  @override
  String get imageSeedY => 'Seed Y (%)';

  @override
  String get imageBrush => 'Brush (refine)';

  @override
  String get imageBrushSize => 'Brush size';

  @override
  String get imageErase => 'Erase';

  @override
  String get imageRestore => 'Restore';

  @override
  String get imageBrushHint =>
      'Click the preview? Not in this build — use sliders and Apply.';

  @override
  String get imageSaturation => 'Saturation';

  @override
  String get imageTone => 'Temperature';

  @override
  String get imageSharpness => 'Sharpness';

  @override
  String get imageDuotoneA => 'Recolor A';

  @override
  String get imageDuotoneB => 'Recolor B';

  @override
  String get imageEffect => 'Artistic effect';

  @override
  String get imageIntensity => 'Intensity';

  @override
  String get imageEffectBlur => 'Blur';

  @override
  String get imageEffectMosaic => 'Mosaic';

  @override
  String get imageEffectPencil => 'Pencil sketch';

  @override
  String get imageEffectOil => 'Oil paint';

  @override
  String get imageEffectFilm => 'Old film';

  @override
  String get imagePreset => 'Quick presets';

  @override
  String get imagePresetBw => 'B&W';

  @override
  String get imagePresetVintage => 'Vintage';

  @override
  String get imagePresetCool => 'Cool';

  @override
  String get imagePresetWarm => 'Warm';

  @override
  String get imagePresetSoft => 'Soft';

  @override
  String get imagePresetVivid => 'Vivid';

  @override
  String get imageApply => 'Apply';

  @override
  String get imageEditTitle => 'Edit image';

  @override
  String get imageCancel => 'Cancel';

  @override
  String get imageUse => 'Use this image';

  @override
  String get imageSize => 'Size';

  @override
  String get imageRotate => 'Rotate';

  @override
  String get imageFlip => 'Flip';

  @override
  String get imageFlipH => 'Horizontal';

  @override
  String get imageFlipV => 'Vertical';

  @override
  String get imageBrightness => 'Brightness';

  @override
  String get imageContrast => 'Contrast';

  @override
  String get imageCropX => 'Crop X';

  @override
  String get imageCropY => 'Crop Y';

  @override
  String get imageCropW => 'Crop width';

  @override
  String get imageCropH => 'Crop height';

  @override
  String get imageRadius => 'Corner radius';

  @override
  String get fxTitle => 'Effects';

  @override
  String get fxShadow => 'Shadow';

  @override
  String get fxShadowOffsetX => 'Offset X';

  @override
  String get fxShadowOffsetY => 'Offset Y';

  @override
  String get fxShadowBlur => 'Blur';

  @override
  String get fxShadowAlpha => 'Opacity';

  @override
  String get fxShadowColor => 'Shadow color';

  @override
  String get fxGlow => 'Glow';

  @override
  String get fxGlowColor => 'Glow color';

  @override
  String get fxGlowSize => 'Glow size';

  @override
  String get fxSoftEdge => 'Soft edge';

  @override
  String get fxBevel => 'Bevel / 3D preset';

  @override
  String get fxRot3d => '3D rotation (X/Y/Z)';

  @override
  String get fxPresets => 'Quick presets';

  @override
  String get fxPresetNone => 'No effect';

  @override
  String get fxPresetSoft => 'Soft';

  @override
  String get fxPresetHard => 'Hard';

  @override
  String get fxPresetGlow => 'Glow';

  @override
  String get fxPresetNeumorphism => 'Neumorphism';

  @override
  String get selectionPane => 'Selection Pane';

  @override
  String get alignGuides => 'Align & Guides';

  @override
  String get textLayout => 'Text Layout';

  @override
  String get animationPane => 'Animations';

  @override
  String get transitions => 'Transitions';

  @override
  String get presentExit => 'Exit';

  @override
  String get presentLaunchFailed => 'Could not start the presentation';

  @override
  String get webviewRuntimeMissing =>
      'WebView2 runtime not found — install Microsoft Edge WebView2 to present smoothly';

  @override
  String get presentHelp => 'Keyboard shortcuts';

  @override
  String get presentHelpClose => 'Click anywhere to close this help.';

  @override
  String get presentHelpKeysG => 'Open slide grid navigator';

  @override
  String get presentHelpKeysB => 'Black / white screen';

  @override
  String get presentHelpKeysP => 'Pen';

  @override
  String get presentHelpKeysL => 'Laser pointer';

  @override
  String get presentHelpKeysM => 'Magnifier';

  @override
  String get presentHelpKeysNumber => 'Jump straight to a slide';

  @override
  String get presentHelpKeysEsc => 'Exit presentation';

  @override
  String get presentGridTitle => 'Jump to slide';

  @override
  String get presentPen => 'Pen';

  @override
  String get presentHighlighter => 'Highlighter';

  @override
  String get presentLaser => 'Laser pointer';

  @override
  String get presentMagnifier => 'Magnifier';

  @override
  String get presentClearInk => 'Clear drawings';

  @override
  String get presenterNextSlide => 'Next slide';

  @override
  String get presenterSpeakerNotes => 'Speaker notes';

  @override
  String get presenterNoNotes => 'No notes for this slide';

  @override
  String get presenterEndOfPresentation => 'End of presentation';

  @override
  String get slide => 'Slide';

  @override
  String get setupShowTitle => 'Set Up Show';

  @override
  String get setupShowMode => 'Show type';

  @override
  String get setupShowModePresenter => 'Presented by a speaker (full screen)';

  @override
  String get setupShowModeBrowsed => 'Browsed by an individual (window)';

  @override
  String get setupShowModeKiosk => 'Kiosk (full screen, loops)';

  @override
  String get setupShowLoop => 'Loop continuously until Esc';

  @override
  String get setupShowNoNarration => 'Show without narration';

  @override
  String get setupShowNoAnimation => 'Show without animations';

  @override
  String get setupShowAdvance => 'Advance every';

  @override
  String get setupShowPenColor => 'Default pen colour';

  @override
  String get setupShowCustomShow => 'Custom show';

  @override
  String get setupShowCustomShowAll => 'All slides (default)';

  @override
  String get startShow => 'Start Show';

  @override
  String get customShowsTitle => 'Custom Shows';

  @override
  String get customShowName => 'Show name';

  @override
  String get customShowPickSlides =>
      'Tap slides to include (tap again to remove)';

  @override
  String get customShowCreate => 'Create';

  @override
  String get customShowEmpty => 'No custom shows yet';

  @override
  String get done => 'Done';

  @override
  String get exportingInProgress => 'Exporting…';

  @override
  String get m6Title =>
      'Milestone 6 — Xuất nâng cao (video / ảnh / in / định dạng / bảo mật)';

  @override
  String get m6Video => 'Video/GIF';

  @override
  String get m6Images => 'Ảnh slide';

  @override
  String get m6Print => 'In (Windows)';

  @override
  String get m6Formats => 'Định dạng';

  @override
  String get m6Protect => 'Bảo mật';

  @override
  String get m6MovieFormat => 'Định dạng phim';

  @override
  String get m6IncludeNarration => 'Gộp narration (audio từng slide) vào MP4';

  @override
  String get m6FfmpegMissing =>
      'FFmpeg không tìm thấy — MP4 cần FFmpeg cài trên máy; GIF vẫn hoạt động.';

  @override
  String get m6ExportMovie => 'Xuất video / GIF';

  @override
  String get m6ImageFormat => 'Định dạng ảnh';

  @override
  String get m6TransparentPng => 'Nền trong suốt (PNG)';

  @override
  String get m6ContactSheet => 'Tạo 1 sheet ảnh tổng hợp (contact sheet)';

  @override
  String get m6ExportImages => 'Xuất ảnh hàng loạt';

  @override
  String get m6ChooseFolder => 'Chọn thư mục xuất ảnh';

  @override
  String get m6HandoutsPerPage => 'Handouts: số slide mỗi trang';

  @override
  String get m6PrintNotes => 'In ghi chú speaker dưới slide';

  @override
  String get m6Grayscale => 'In đen trắng (grayscale)';

  @override
  String get m6OutlineRtf => 'Outline RTF cho Word';

  @override
  String get m6PrintDone => 'Đã gửi tới máy in';

  @override
  String get m6Inspect => 'Quét metadata (Inspector)';

  @override
  String get m6Package => 'Đóng gói thư mục + ZIP';

  @override
  String get m6InspectorClean => 'Không phát hiện dữ liệu ẩn.';

  @override
  String m6InspectorFound(Object count) {
    return 'Phát hiện $count dữ liệu ẩn (tác giả/email/phone/slide trống).';
  }

  @override
  String get m6CleanExport => 'Xuất deck đã làm sạch (.pptx)';

  @override
  String get m6ModifyPassword => 'Mật khẩu chống sửa (để trống = không đặt)';

  @override
  String get m6MarkFinal => 'Mark as Final';

  @override
  String get m6ApplyPassword => 'Đặt mật khẩu chống sửa';

  @override
  String get m6PptFallback =>
      'Cần LibreOffice trên máy để xuất .ppt — dùng .pptx và Save As từ PowerPoint.';

  @override
  String get collabViewLink => 'View-only link';

  @override
  String get collabViewLinkHint =>
      'Anyone with this link can watch but not edit.';

  @override
  String get collabCopyViewLink => 'Copy view link';

  @override
  String get collabRole => 'Role';

  @override
  String get collabRoleHost => 'Host';

  @override
  String get collabRoleEditor => 'Editor';

  @override
  String get collabRoleViewer => 'Viewer';

  @override
  String get collabViewModeNotice => 'View mode — this session is read-only.';

  @override
  String get collabKick => 'Remove from session';

  @override
  String get collabLockSession => 'Lock session (refuse new joins)';

  @override
  String get collabUnlockSession => 'Unlock session';

  @override
  String get collabLockSlide => 'Editing…';

  @override
  String get collabHistory => 'Sync history';

  @override
  String collabHistoryEntry(Object name, Object slide) {
    return '$name edited slide $slide';
  }

  @override
  String collabReconnecting(Object attempt) {
    return 'Reconnecting… (attempt $attempt)';
  }

  @override
  String get collabReconnected => 'Connection restored.';

  @override
  String get collabConnectionLost => 'Connection lost — retrying…';

  @override
  String collabLockedBy(Object name) {
    return 'This slide is being edited by $name';
  }

  @override
  String collabConflictDetail(Object name, Object slide, Object time) {
    return '$name changed slide $slide at $time';
  }

  @override
  String get comments => 'Comments';

  @override
  String get commentsAdd => 'Add comment';

  @override
  String get commentsEmpty => 'No comments on this slide yet.';

  @override
  String get commentsResolve => 'Resolve';

  @override
  String get commentsUnresolve => 'Reopen';

  @override
  String get commentsReply => 'Reply';

  @override
  String get commentsDelete => 'Delete';

  @override
  String get commentsMentionHint => 'Type @ to mention a collaborator';

  @override
  String get commentsNewChip => 'New comments';

  @override
  String get commentsExportNote => 'Discussion notes';

  @override
  String get profileTitle => 'Your profile';

  @override
  String get profileName => 'Display name';

  @override
  String get profileAvatar => 'Avatar';

  @override
  String get profileSave => 'Save profile';

  @override
  String get profileSaved => 'Profile saved.';

  @override
  String get profileAuthorHint => 'Used as comment author and export metadata.';

  @override
  String get cloudTitle => 'Cloud sync';

  @override
  String get cloudUrl => 'WebDAV server URL';

  @override
  String get cloudUsername => 'Username';

  @override
  String get cloudPassword => 'Password';

  @override
  String get cloudSave => 'Save cloud account';

  @override
  String get cloudSaved => 'Cloud account saved.';

  @override
  String get cloudSyncNow => 'Sync now';

  @override
  String get cloudSyncing => 'Syncing…';

  @override
  String get cloudSynced => 'Synced.';

  @override
  String get cloudConflictSaved => 'Conflict saved as .conflict';

  @override
  String get cloudNoAccount => 'No cloud account configured.';

  @override
  String get versions => 'Versions';

  @override
  String get versionsRestore => 'Restore';

  @override
  String get versionsDelete => 'Delete';

  @override
  String get versionsEmpty => 'No versions yet.';

  @override
  String get versionsMax => 'Up to 20 versions kept per project';

  @override
  String get reuseTitle => 'Reuse slides';

  @override
  String get designerTitle => 'Designer';

  @override
  String get designerSelectSlide => 'Select a slide to see design ideas';

  @override
  String get designerUndo => 'Undo design';

  @override
  String get designerDark => 'Dark';

  @override
  String get designerApply => 'Apply';

  @override
  String get reusePasteHint =>
      'Paste a .ghita bundle (JSON) or plain text/HTML. Slides split on --- or h1/h2.';

  @override
  String get reuseKeepOriginal => 'Keep original formatting';

  @override
  String get reuseParse => 'Parse';

  @override
  String get reuseCompare => 'Compare / Merge';

  @override
  String get reuseInserted => 'Inserted slide(s)';

  @override
  String get compareVersionA => 'Version A (.ghita JSON)';

  @override
  String get compareVersionB => 'Version B (.ghita JSON)';

  @override
  String get compareRun => 'Compare';

  @override
  String get compareMergeIntoDeck => 'Merge into deck';

  @override
  String get copilotCreateDeck => 'Create presentation';

  @override
  String get copilotSummarize => 'Summarize deck';

  @override
  String get copilotAskDeck => 'Ask about deck';

  @override
  String get dictationMic => 'Dictation';

  @override
  String get dictationListening => 'Listening…';

  @override
  String get dictationStop => 'Stop dictation';

  @override
  String get translateDeck => 'Translate deck';

  @override
  String get aiContextToggle => 'AI uses deck context';

  @override
  String get findReplace => 'Find / Replace';

  @override
  String get accessibilityTitle => 'Accessibility';

  @override
  String get addinsTitle => 'Add-ins';

  @override
  String get readAloudTitle => 'Read aloud';

  @override
  String get ribbonCustomize => 'Customize ribbon';

  @override
  String get viewNormal => 'Normal';

  @override
  String get viewSorter => 'Slide Sorter';

  @override
  String get viewNotes => 'Notes';

  @override
  String get viewReading => 'Reading view';

  @override
  String get outlineView => 'Outline view';

  @override
  String get spellcheck => 'Spell check';

  @override
  String get templateOnline => 'Online templates';

  @override
  String get versionsRestored => 'Version restored.';

  @override
  String get deckEmpty => 'Deck is empty — add slides first.';

  @override
  String get summarySlideAdded => 'Summary slide added.';

  @override
  String get askDeckHint => 'e.g. Which slide talks about budgets?';

  @override
  String get slideTitleHint => 'Slide title...';

  @override
  String get slideUpdated => 'Slide updated!';

  @override
  String get slideAddedSuccess => 'Slide added successfully!';

  @override
  String get templateSearchHint => 'Search templates...';

  @override
  String get importSlides => 'Import Slides';

  @override
  String addAllSlides(Object count) {
    return 'Add All ($count)';
  }

  @override
  String addedSlideNotice(Object title) {
    return 'Added \"$title\" to slides!';
  }

  @override
  String get openGhitaFile => 'Open .ghita file';

  @override
  String openedProject(Object project) {
    return 'Opened: $project';
  }

  @override
  String get moreTools => 'More tools';

  @override
  String get collapseTools => 'Collapse tools';

  @override
  String get presenterBroadcastStart => 'Broadcast over Wi-Fi';

  @override
  String get presenterBroadcastStop => 'Stop Wi-Fi broadcast';

  @override
  String get presenterBroadcastCopy => 'Copy viewer link';

  @override
  String get presenterBroadcastCopied =>
      'Secure viewer link copied to the clipboard.';

  @override
  String get presenterBroadcastFailed =>
      'Could not start the Wi-Fi broadcast server.';

  @override
  String presenterViewerCount(int count) {
    return '$count viewers';
  }

  @override
  String get diagramDialogTitle => 'Insert Diagram';

  @override
  String get diagramModeFlowchart => 'Flowchart';

  @override
  String get diagramModeMindmap => 'Mindmap';

  @override
  String get diagramTopicLabel => 'Central topic';

  @override
  String get diagramAccentLabel => 'Accent colour';

  @override
  String get diagramStepsLabel => 'Steps (in order)';

  @override
  String get diagramSubtopicsLabel => 'Subtopics';

  @override
  String get diagramAddStep => 'Add step';

  @override
  String get diagramAddSubtopic => 'Add subtopic';

  @override
  String get diagramRemoveField => 'Remove last';

  @override
  String get diagramPreviewLabel => 'Preview';

  @override
  String get diagramCentralChip => 'Central topic';

  @override
  String get diagramInsert => 'Insert into slide';

  @override
  String get pdfNotesPages => 'Speaker-notes pages';

  @override
  String get pdfBookmarks => 'PDF bookmarks (outline)';

  @override
  String get engineTitle => 'Engine';

  @override
  String get engineSubtitle =>
      'Processing core for export and media. Rust is faster; Dart always works.';

  @override
  String get engineRust => 'Rust';

  @override
  String get engineDart => 'Dart';

  @override
  String engineStatusRust(String version) {
    return 'Running on the Rust engine ($version)';
  }

  @override
  String get engineStatusDart => 'Running on the Dart engine (compatible mode)';

  @override
  String engineRustAvailable(String version) {
    return 'Rust engine available ($version)';
  }

  @override
  String engineStatusFallback(String reason) {
    return 'Rust engine unavailable ($reason); running on Dart';
  }

  @override
  String get docxReportOptions => 'Word report options';

  @override
  String get docxIncludeSlideList =>
      'Include an index of all slides at the end';

  @override
  String get imageOptimizerBetaTitle => 'Image optimizer (beta)';

  @override
  String get imageOptimizerBetaSubtitle =>
      'Experimental: convert large opaque PNGs to JPEG on export (transparent PNGs stay PNG); shows savings in the export summary';

  @override
  String imageSavings(String summary, String count) {
    return 'Saved: $summary ($count images)';
  }
}
