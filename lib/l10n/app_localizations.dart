import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi')
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'Ghita PPT Converter'**
  String get appTitle;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTitle;

  /// No description provided for @editorTitle.
  ///
  /// In en, this message translates to:
  /// **'Editor'**
  String get editorTitle;

  /// No description provided for @projectsTitle.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get projectsTitle;

  /// No description provided for @templatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get templatesTitle;

  /// No description provided for @aiChatTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Chat'**
  String get aiChatTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @newSlide.
  ///
  /// In en, this message translates to:
  /// **'New Slide'**
  String get newSlide;

  /// No description provided for @duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @redo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get redo;

  /// No description provided for @present.
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get present;

  /// No description provided for @presentFromCurrent.
  ///
  /// In en, this message translates to:
  /// **'From Current'**
  String get presentFromCurrent;

  /// No description provided for @presentation.
  ///
  /// In en, this message translates to:
  /// **'Presentation'**
  String get presentation;

  /// No description provided for @slides.
  ///
  /// In en, this message translates to:
  /// **'Slides'**
  String get slides;

  /// No description provided for @slideCount.
  ///
  /// In en, this message translates to:
  /// **'Slides ({count})'**
  String slideCount(int count);

  /// No description provided for @noSlidesYet.
  ///
  /// In en, this message translates to:
  /// **'No slides yet'**
  String get noSlidesYet;

  /// No description provided for @clickToAddSlide.
  ///
  /// In en, this message translates to:
  /// **'Click + to add a slide'**
  String get clickToAddSlide;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @content.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get content;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @addSlideTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add new slide'**
  String get addSlideTooltip;

  /// No description provided for @deleteSlideTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete slide'**
  String get deleteSlideTooltip;

  /// No description provided for @duplicateSlideTooltip.
  ///
  /// In en, this message translates to:
  /// **'Duplicate slide'**
  String get duplicateSlideTooltip;

  /// No description provided for @previewTooltip.
  ///
  /// In en, this message translates to:
  /// **'Preview slide'**
  String get previewTooltip;

  /// No description provided for @editSlide.
  ///
  /// In en, this message translates to:
  /// **'Edit Slide'**
  String get editSlide;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @warning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// No description provided for @info.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get info;

  /// No description provided for @connectionError.
  ///
  /// In en, this message translates to:
  /// **'Network connection error. Please check your internet.'**
  String get connectionError;

  /// No description provided for @timeoutError.
  ///
  /// In en, this message translates to:
  /// **'Request timed out. Please try again.'**
  String get timeoutError;

  /// No description provided for @invalidFile.
  ///
  /// In en, this message translates to:
  /// **'Invalid file format.'**
  String get invalidFile;

  /// No description provided for @fileNotFound.
  ///
  /// In en, this message translates to:
  /// **'File not found.'**
  String get fileNotFound;

  /// No description provided for @permissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission denied.'**
  String get permissionDenied;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get unknownError;

  /// No description provided for @saveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Saved successfully'**
  String get saveSuccess;

  /// No description provided for @exportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Exported successfully'**
  String get exportSuccess;

  /// No description provided for @importSuccess.
  ///
  /// In en, this message translates to:
  /// **'Imported successfully'**
  String get importSuccess;

  /// No description provided for @deleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Deleted successfully'**
  String get deleteSuccess;

  /// No description provided for @duplicateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Duplicated successfully'**
  String get duplicateSuccess;

  /// No description provided for @deletedWithUndo.
  ///
  /// In en, this message translates to:
  /// **'Deleted \"{title}\"'**
  String deletedWithUndo(String title);

  /// No description provided for @undoAction.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undoAction;

  /// No description provided for @addNewProvider.
  ///
  /// In en, this message translates to:
  /// **'Add New'**
  String get addNewProvider;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @apiKeySaved.
  ///
  /// In en, this message translates to:
  /// **'API Key saved for {name}'**
  String apiKeySaved(String name);

  /// No description provided for @apiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'API Key...'**
  String get apiKeyHint;

  /// No description provided for @saveApiKeyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Save API Key'**
  String get saveApiKeyTooltip;

  /// No description provided for @exportBackup.
  ///
  /// In en, this message translates to:
  /// **'Export Configuration (JSON)'**
  String get exportBackup;

  /// No description provided for @importBackup.
  ///
  /// In en, this message translates to:
  /// **'Import Configuration (JSON)'**
  String get importBackup;

  /// No description provided for @saveBackup.
  ///
  /// In en, this message translates to:
  /// **'Save backup'**
  String get saveBackup;

  /// No description provided for @restoreSettings.
  ///
  /// In en, this message translates to:
  /// **'Restore settings?'**
  String get restoreSettings;

  /// No description provided for @restoreSettingsMessage.
  ///
  /// In en, this message translates to:
  /// **'Backup from {date}.\nNumber of providers: {count}\n\nCurrent settings will be overwritten. Continue?'**
  String restoreSettingsMessage(String date, int count);

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @backupExported.
  ///
  /// In en, this message translates to:
  /// **'Backup exported successfully: {filename}'**
  String backupExported(String filename);

  /// No description provided for @settingsRestored.
  ///
  /// In en, this message translates to:
  /// **'Settings restored successfully!'**
  String get settingsRestored;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @interfaceMode.
  ///
  /// In en, this message translates to:
  /// **'Interface Mode'**
  String get interfaceMode;

  /// No description provided for @currentMode.
  ///
  /// In en, this message translates to:
  /// **'Current: {mode}'**
  String currentMode(String mode);

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightMode;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkMode;

  /// No description provided for @autoMode.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get autoMode;

  /// No description provided for @lightModeFull.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightModeFull;

  /// No description provided for @darkModeFull.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkModeFull;

  /// No description provided for @systemMode.
  ///
  /// In en, this message translates to:
  /// **'System (Auto)'**
  String get systemMode;

  /// No description provided for @themeSettings.
  ///
  /// In en, this message translates to:
  /// **'Theme Settings'**
  String get themeSettings;

  /// No description provided for @customTheme.
  ///
  /// In en, this message translates to:
  /// **'Customize Theme'**
  String get customTheme;

  /// No description provided for @customThemeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Colors, fonts, preset themes'**
  String get customThemeSubtitle;

  /// No description provided for @presetThemes.
  ///
  /// In en, this message translates to:
  /// **'Preset Themes'**
  String get presetThemes;

  /// No description provided for @customColors.
  ///
  /// In en, this message translates to:
  /// **'Custom Colors'**
  String get customColors;

  /// No description provided for @primaryColor.
  ///
  /// In en, this message translates to:
  /// **'Primary Color'**
  String get primaryColor;

  /// No description provided for @accentColor.
  ///
  /// In en, this message translates to:
  /// **'Accent Color'**
  String get accentColor;

  /// No description provided for @typography.
  ///
  /// In en, this message translates to:
  /// **'Typography'**
  String get typography;

  /// No description provided for @fontFamily.
  ///
  /// In en, this message translates to:
  /// **'Font Family'**
  String get fontFamily;

  /// No description provided for @exportTheme.
  ///
  /// In en, this message translates to:
  /// **'Export theme'**
  String get exportTheme;

  /// No description provided for @importTheme.
  ///
  /// In en, this message translates to:
  /// **'Import theme'**
  String get importTheme;

  /// No description provided for @resetToDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get resetToDefault;

  /// No description provided for @themeResetMessage.
  ///
  /// In en, this message translates to:
  /// **'Theme reset to Office Blue'**
  String get themeResetMessage;

  /// No description provided for @themeAppliedMessage.
  ///
  /// In en, this message translates to:
  /// **'Applied {name} preset'**
  String themeAppliedMessage(String name);

  /// No description provided for @themeCopied.
  ///
  /// In en, this message translates to:
  /// **'Theme copied to clipboard!'**
  String get themeCopied;

  /// No description provided for @themeImported.
  ///
  /// In en, this message translates to:
  /// **'Theme imported successfully!'**
  String get themeImported;

  /// No description provided for @themeImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to import theme. Invalid format.'**
  String get themeImportFailed;

  /// No description provided for @clipboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'Clipboard is empty'**
  String get clipboardEmpty;

  /// No description provided for @pickColor.
  ///
  /// In en, this message translates to:
  /// **'Pick a color'**
  String get pickColor;

  /// No description provided for @pickColorTooltip.
  ///
  /// In en, this message translates to:
  /// **'Pick color'**
  String get pickColorTooltip;

  /// No description provided for @officeBlue.
  ///
  /// In en, this message translates to:
  /// **'Office Blue'**
  String get officeBlue;

  /// No description provided for @officeBlueDesc.
  ///
  /// In en, this message translates to:
  /// **'Classic Microsoft Office'**
  String get officeBlueDesc;

  /// No description provided for @darkProfessional.
  ///
  /// In en, this message translates to:
  /// **'Dark Professional'**
  String get darkProfessional;

  /// No description provided for @darkProfessionalDesc.
  ///
  /// In en, this message translates to:
  /// **'Elegant dark theme'**
  String get darkProfessionalDesc;

  /// No description provided for @lightMinimal.
  ///
  /// In en, this message translates to:
  /// **'Light Minimal'**
  String get lightMinimal;

  /// No description provided for @lightMinimalDesc.
  ///
  /// In en, this message translates to:
  /// **'Clean and minimal'**
  String get lightMinimalDesc;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @customDesc.
  ///
  /// In en, this message translates to:
  /// **'Your custom theme'**
  String get customDesc;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @versionInfo.
  ///
  /// In en, this message translates to:
  /// **'{version} • Build {year}'**
  String versionInfo(String version, String year);

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @vietnamese.
  ///
  /// In en, this message translates to:
  /// **'Tiếng Việt'**
  String get vietnamese;

  /// No description provided for @aiProvider.
  ///
  /// In en, this message translates to:
  /// **'API Key & AI Provider'**
  String get aiProvider;

  /// No description provided for @backupRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get backupRestore;

  /// No description provided for @infoSection.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get infoSection;

  /// No description provided for @addNew.
  ///
  /// In en, this message translates to:
  /// **'Add New'**
  String get addNew;

  /// No description provided for @recentProjects.
  ///
  /// In en, this message translates to:
  /// **'Recent Projects'**
  String get recentProjects;

  /// No description provided for @noRecentProjects.
  ///
  /// In en, this message translates to:
  /// **'No recent projects'**
  String get noRecentProjects;

  /// No description provided for @openProject.
  ///
  /// In en, this message translates to:
  /// **'Open Project'**
  String get openProject;

  /// No description provided for @removeFromList.
  ///
  /// In en, this message translates to:
  /// **'Remove from list'**
  String get removeFromList;

  /// No description provided for @removeAll.
  ///
  /// In en, this message translates to:
  /// **'Remove All'**
  String get removeAll;

  /// No description provided for @confirmRemoveAll.
  ///
  /// In en, this message translates to:
  /// **'Remove all recent projects?'**
  String get confirmRemoveAll;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @templates.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get templates;

  /// No description provided for @noTemplates.
  ///
  /// In en, this message translates to:
  /// **'No templates available'**
  String get noTemplates;

  /// No description provided for @useTemplate.
  ///
  /// In en, this message translates to:
  /// **'Use Template'**
  String get useTemplate;

  /// No description provided for @aiChat.
  ///
  /// In en, this message translates to:
  /// **'AI Chat'**
  String get aiChat;

  /// No description provided for @typeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type your message...'**
  String get typeMessage;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @regenerate.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get regenerate;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @clearChat.
  ///
  /// In en, this message translates to:
  /// **'Clear Chat'**
  String get clearChat;

  /// No description provided for @clearChatConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear chat history?'**
  String get clearChatConfirm;

  /// No description provided for @selectProvider.
  ///
  /// In en, this message translates to:
  /// **'Select AI Provider'**
  String get selectProvider;

  /// No description provided for @noProviders.
  ///
  /// In en, this message translates to:
  /// **'No AI providers configured'**
  String get noProviders;

  /// No description provided for @addProviderFirst.
  ///
  /// In en, this message translates to:
  /// **'Add a provider in Settings first'**
  String get addProviderFirst;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// No description provided for @cut.
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get cut;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get selectAll;

  /// No description provided for @bold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get bold;

  /// No description provided for @italic.
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get italic;

  /// No description provided for @underline.
  ///
  /// In en, this message translates to:
  /// **'Underline'**
  String get underline;

  /// No description provided for @strikethrough.
  ///
  /// In en, this message translates to:
  /// **'Strikethrough'**
  String get strikethrough;

  /// No description provided for @alignLeft.
  ///
  /// In en, this message translates to:
  /// **'Align Left'**
  String get alignLeft;

  /// No description provided for @alignCenter.
  ///
  /// In en, this message translates to:
  /// **'Align Center'**
  String get alignCenter;

  /// No description provided for @alignRight.
  ///
  /// In en, this message translates to:
  /// **'Align Right'**
  String get alignRight;

  /// No description provided for @alignJustify.
  ///
  /// In en, this message translates to:
  /// **'Justify'**
  String get alignJustify;

  /// No description provided for @bulletList.
  ///
  /// In en, this message translates to:
  /// **'Bullet List'**
  String get bulletList;

  /// No description provided for @numberedList.
  ///
  /// In en, this message translates to:
  /// **'Numbered List'**
  String get numberedList;

  /// No description provided for @indent.
  ///
  /// In en, this message translates to:
  /// **'Indent'**
  String get indent;

  /// No description provided for @outdent.
  ///
  /// In en, this message translates to:
  /// **'Outdent'**
  String get outdent;

  /// No description provided for @link.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get link;

  /// No description provided for @image.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get image;

  /// No description provided for @table.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get table;

  /// No description provided for @code.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get code;

  /// No description provided for @format.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get format;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @shortcuts.
  ///
  /// In en, this message translates to:
  /// **'Keyboard Shortcuts'**
  String get shortcuts;

  /// No description provided for @exitPresentation.
  ///
  /// In en, this message translates to:
  /// **'Exit Presentation'**
  String get exitPresentation;

  /// No description provided for @nextSlide.
  ///
  /// In en, this message translates to:
  /// **'Next Slide'**
  String get nextSlide;

  /// No description provided for @previousSlide.
  ///
  /// In en, this message translates to:
  /// **'Previous Slide'**
  String get previousSlide;

  /// No description provided for @firstSlide.
  ///
  /// In en, this message translates to:
  /// **'First Slide'**
  String get firstSlide;

  /// No description provided for @lastSlide.
  ///
  /// In en, this message translates to:
  /// **'Last Slide'**
  String get lastSlide;

  /// No description provided for @aiTools.
  ///
  /// In en, this message translates to:
  /// **'AI Tools'**
  String get aiTools;

  /// No description provided for @improveWriting.
  ///
  /// In en, this message translates to:
  /// **'Improve Writing'**
  String get improveWriting;

  /// No description provided for @fixGrammar.
  ///
  /// In en, this message translates to:
  /// **'Fix Grammar'**
  String get fixGrammar;

  /// No description provided for @makeShorter.
  ///
  /// In en, this message translates to:
  /// **'Make Shorter'**
  String get makeShorter;

  /// No description provided for @makeLonger.
  ///
  /// In en, this message translates to:
  /// **'Make Longer'**
  String get makeLonger;

  /// No description provided for @translateTo.
  ///
  /// In en, this message translates to:
  /// **'Translate to {language}'**
  String translateTo(String language);

  /// No description provided for @summary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summary;

  /// No description provided for @generateSlides.
  ///
  /// In en, this message translates to:
  /// **'Generate Slides'**
  String get generateSlides;

  /// No description provided for @fromText.
  ///
  /// In en, this message translates to:
  /// **'From Text'**
  String get fromText;

  /// No description provided for @fromTopic.
  ///
  /// In en, this message translates to:
  /// **'From Topic'**
  String get fromTopic;

  /// No description provided for @topic.
  ///
  /// In en, this message translates to:
  /// **'Topic'**
  String get topic;

  /// No description provided for @slideCountQuestion.
  ///
  /// In en, this message translates to:
  /// **'How many slides?'**
  String get slideCountQuestion;

  /// No description provided for @style.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get style;

  /// No description provided for @professional.
  ///
  /// In en, this message translates to:
  /// **'Professional'**
  String get professional;

  /// No description provided for @casual.
  ///
  /// In en, this message translates to:
  /// **'Casual'**
  String get casual;

  /// No description provided for @academic.
  ///
  /// In en, this message translates to:
  /// **'Academic'**
  String get academic;

  /// No description provided for @creative.
  ///
  /// In en, this message translates to:
  /// **'Creative'**
  String get creative;

  /// No description provided for @files.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get files;

  /// No description provided for @addFiles.
  ///
  /// In en, this message translates to:
  /// **'Add Files'**
  String get addFiles;

  /// No description provided for @noFiles.
  ///
  /// In en, this message translates to:
  /// **'No files'**
  String get noFiles;

  /// No description provided for @fileName.
  ///
  /// In en, this message translates to:
  /// **'File Name'**
  String get fileName;

  /// No description provided for @fileSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get fileSize;

  /// No description provided for @fileType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get fileType;

  /// No description provided for @uploadedAt.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get uploadedAt;

  /// No description provided for @collaboration.
  ///
  /// In en, this message translates to:
  /// **'Collaboration'**
  String get collaboration;

  /// No description provided for @startSession.
  ///
  /// In en, this message translates to:
  /// **'Start Session'**
  String get startSession;

  /// No description provided for @joinSession.
  ///
  /// In en, this message translates to:
  /// **'Join Session'**
  String get joinSession;

  /// No description provided for @sessionCode.
  ///
  /// In en, this message translates to:
  /// **'Session Code'**
  String get sessionCode;

  /// No description provided for @host.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get host;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @audio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get audio;

  /// No description provided for @startRecording.
  ///
  /// In en, this message translates to:
  /// **'Start Recording'**
  String get startRecording;

  /// No description provided for @stopRecording.
  ///
  /// In en, this message translates to:
  /// **'Stop Recording'**
  String get stopRecording;

  /// No description provided for @playRecording.
  ///
  /// In en, this message translates to:
  /// **'Play Recording'**
  String get playRecording;

  /// No description provided for @deleteRecording.
  ///
  /// In en, this message translates to:
  /// **'Delete Recording'**
  String get deleteRecording;

  /// No description provided for @audioRecorded.
  ///
  /// In en, this message translates to:
  /// **'Audio recorded'**
  String get audioRecorded;

  /// No description provided for @recordings.
  ///
  /// In en, this message translates to:
  /// **'Recordings'**
  String get recordings;

  /// No description provided for @noRecordings.
  ///
  /// In en, this message translates to:
  /// **'No recordings yet'**
  String get noRecordings;

  /// No description provided for @advancedExport.
  ///
  /// In en, this message translates to:
  /// **'Advanced Export'**
  String get advancedExport;

  /// No description provided for @exportFormat.
  ///
  /// In en, this message translates to:
  /// **'Export Format'**
  String get exportFormat;

  /// No description provided for @aspectRatio.
  ///
  /// In en, this message translates to:
  /// **'Aspect Ratio'**
  String get aspectRatio;

  /// No description provided for @quality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get quality;

  /// No description provided for @exportOptions.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get exportOptions;

  /// No description provided for @includeSpeakerNotes.
  ///
  /// In en, this message translates to:
  /// **'Include speaker notes'**
  String get includeSpeakerNotes;

  /// No description provided for @includeBackgrounds.
  ///
  /// In en, this message translates to:
  /// **'Include backgrounds'**
  String get includeBackgrounds;

  /// No description provided for @slidesToExport.
  ///
  /// In en, this message translates to:
  /// **'Slides to Export'**
  String get slidesToExport;

  /// No description provided for @allSlides.
  ///
  /// In en, this message translates to:
  /// **'All slides'**
  String get allSlides;

  /// No description provided for @selectedSlides.
  ///
  /// In en, this message translates to:
  /// **'Selected ({count})'**
  String selectedSlides(int count);

  /// No description provided for @exporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting...'**
  String get exporting;

  /// No description provided for @exportSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Export successful: {summary}'**
  String exportSuccessful(String summary);

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(String error);

  /// No description provided for @chooseAtLeastOneSlide.
  ///
  /// In en, this message translates to:
  /// **'Select at least one slide or choose \"All slides\".'**
  String get chooseAtLeastOneSlide;

  /// No description provided for @chooseTemplate.
  ///
  /// In en, this message translates to:
  /// **'Choose a Template'**
  String get chooseTemplate;

  /// No description provided for @htmlPreview.
  ///
  /// In en, this message translates to:
  /// **'HTML Preview:'**
  String get htmlPreview;

  /// No description provided for @useThisTemplate.
  ///
  /// In en, this message translates to:
  /// **'Use This Template'**
  String get useThisTemplate;

  /// No description provided for @clearAllSlides.
  ///
  /// In en, this message translates to:
  /// **'Clear All Slides'**
  String get clearAllSlides;

  /// No description provided for @clearAllSlidesMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete all {count} slides? This action cannot be undone.'**
  String clearAllSlidesMessage(int count);

  /// No description provided for @deletedAllSlides.
  ///
  /// In en, this message translates to:
  /// **'Deleted all slides'**
  String get deletedAllSlides;

  /// No description provided for @untitledPresentation.
  ///
  /// In en, this message translates to:
  /// **'Untitled Presentation'**
  String get untitledPresentation;

  /// No description provided for @hideSidebar.
  ///
  /// In en, this message translates to:
  /// **'Hide Sidebar'**
  String get hideSidebar;

  /// No description provided for @showSidebar.
  ///
  /// In en, this message translates to:
  /// **'Show Sidebar'**
  String get showSidebar;

  /// No description provided for @toggleTheme.
  ///
  /// In en, this message translates to:
  /// **'Toggle Theme'**
  String get toggleTheme;

  /// No description provided for @slideEditor.
  ///
  /// In en, this message translates to:
  /// **'Slide Editor'**
  String get slideEditor;

  /// No description provided for @navigation.
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get navigation;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @noSlides.
  ///
  /// In en, this message translates to:
  /// **'There are no slides to present.'**
  String get noSlides;

  /// No description provided for @startCollaboration.
  ///
  /// In en, this message translates to:
  /// **'Start collaboration'**
  String get startCollaboration;

  /// No description provided for @stopCollaboration.
  ///
  /// In en, this message translates to:
  /// **'Stop collaboration'**
  String get stopCollaboration;

  /// No description provided for @leaveCollaboration.
  ///
  /// In en, this message translates to:
  /// **'Leave session'**
  String get leaveCollaboration;

  /// No description provided for @hostCollaboration.
  ///
  /// In en, this message translates to:
  /// **'Host a collaboration session'**
  String get hostCollaboration;

  /// No description provided for @hostCollaborationDescription.
  ///
  /// In en, this message translates to:
  /// **'Share the current presentation with trusted people on this local network.'**
  String get hostCollaborationDescription;

  /// No description provided for @joinCollaboration.
  ///
  /// In en, this message translates to:
  /// **'Join a session'**
  String get joinCollaboration;

  /// No description provided for @hostOrShareLink.
  ///
  /// In en, this message translates to:
  /// **'Host IP or share link'**
  String get hostOrShareLink;

  /// No description provided for @port.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get port;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// No description provided for @sessionToken.
  ///
  /// In en, this message translates to:
  /// **'Session token'**
  String get sessionToken;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @collaborationHosting.
  ///
  /// In en, this message translates to:
  /// **'Hosting a protected session'**
  String get collaborationHosting;

  /// No description provided for @collaborationConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected and syncing'**
  String get collaborationConnected;

  /// No description provided for @collaborationRevision.
  ///
  /// In en, this message translates to:
  /// **'Revision {revision}'**
  String collaborationRevision(int revision);

  /// No description provided for @collaborationParticipants.
  ///
  /// In en, this message translates to:
  /// **'Participants: {count}'**
  String collaborationParticipants(int count);

  /// No description provided for @collaborationSecurityNotice.
  ///
  /// In en, this message translates to:
  /// **'Only share the link or token with trusted people on your local network.'**
  String get collaborationSecurityNotice;

  /// No description provided for @collaborationStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start the protected local server. Check the port and firewall.'**
  String get collaborationStartFailed;

  /// No description provided for @collaborationJoinFields.
  ///
  /// In en, this message translates to:
  /// **'Enter a host/share link and session token.'**
  String get collaborationJoinFields;

  /// No description provided for @collaborationJoinFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not authenticate or connect to this session.'**
  String get collaborationJoinFailed;

  /// No description provided for @collaborationJoined.
  ///
  /// In en, this message translates to:
  /// **'Connected. Slides are now synchronized.'**
  String get collaborationJoined;

  /// No description provided for @collaborationLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Protected share link copied.'**
  String get collaborationLinkCopied;

  /// No description provided for @collaborationConflict.
  ///
  /// In en, this message translates to:
  /// **'A newer revision was found. The authoritative host version was restored.'**
  String get collaborationConflict;

  /// No description provided for @collaborationAuthFailed.
  ///
  /// In en, this message translates to:
  /// **'The collaboration token is no longer valid.'**
  String get collaborationAuthFailed;

  /// No description provided for @slideListSemantics.
  ///
  /// In en, this message translates to:
  /// **'Slide list, {count} slides'**
  String slideListSemantics(int count);

  /// No description provided for @slideSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Slide {number}: {title}'**
  String slideSemanticLabel(int number, String title);

  /// No description provided for @slideSemanticHint.
  ///
  /// In en, this message translates to:
  /// **'Activate to edit. Long press for more actions.'**
  String get slideSemanticHint;

  /// No description provided for @workspaceSemantics.
  ///
  /// In en, this message translates to:
  /// **'GhitaPPT presentation workspace'**
  String get workspaceSemantics;

  /// Export progress indicator with the current slide number and the deck size.
  ///
  /// In en, this message translates to:
  /// **'Exporting… {done}/{total}'**
  String exportProgress(int done, int total);

  /// No description provided for @exportCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel export'**
  String get exportCancel;

  /// No description provided for @exportCancelDescription.
  ///
  /// In en, this message translates to:
  /// **'Stop the running export and discard its output.'**
  String get exportCancelDescription;

  /// No description provided for @fitContent.
  ///
  /// In en, this message translates to:
  /// **'Fit content on slides'**
  String get fitContent;

  /// No description provided for @fitContentDescription.
  ///
  /// In en, this message translates to:
  /// **'Shrink overflowing text so the whole deck fits its slides.'**
  String get fitContentDescription;

  /// No description provided for @loadingRemoteImages.
  ///
  /// In en, this message translates to:
  /// **'Loading images from the web…'**
  String get loadingRemoteImages;

  /// An image referenced by a slide could not be downloaded.
  ///
  /// In en, this message translates to:
  /// **'Could not load image {name}'**
  String remoteImageLoadFailed(String name);

  /// No description provided for @exportThemePreview.
  ///
  /// In en, this message translates to:
  /// **'Exported files will use this theme'**
  String get exportThemePreview;

  /// No description provided for @exportThemePreviewDescription.
  ///
  /// In en, this message translates to:
  /// **'Shows the clrScheme and fonts written into exported PPTX files.'**
  String get exportThemePreviewDescription;

  /// No description provided for @layout.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get layout;

  /// No description provided for @layoutBlank.
  ///
  /// In en, this message translates to:
  /// **'Blank'**
  String get layoutBlank;

  /// No description provided for @layoutTitleSlide.
  ///
  /// In en, this message translates to:
  /// **'Title Slide'**
  String get layoutTitleSlide;

  /// No description provided for @layoutTitleAndContent.
  ///
  /// In en, this message translates to:
  /// **'Title and Content'**
  String get layoutTitleAndContent;

  /// No description provided for @layoutSectionHeader.
  ///
  /// In en, this message translates to:
  /// **'Section Header'**
  String get layoutSectionHeader;

  /// No description provided for @layoutTwoContent.
  ///
  /// In en, this message translates to:
  /// **'Two Content'**
  String get layoutTwoContent;

  /// No description provided for @layoutComparison.
  ///
  /// In en, this message translates to:
  /// **'Comparison'**
  String get layoutComparison;

  /// No description provided for @layoutTitleOnly.
  ///
  /// In en, this message translates to:
  /// **'Title Only'**
  String get layoutTitleOnly;

  /// No description provided for @layoutContentAndCaption.
  ///
  /// In en, this message translates to:
  /// **'Content and Caption'**
  String get layoutContentAndCaption;

  /// No description provided for @layoutPictureAndCaption.
  ///
  /// In en, this message translates to:
  /// **'Picture with Caption'**
  String get layoutPictureAndCaption;

  /// Confirmation after applying a slide layout.
  ///
  /// In en, this message translates to:
  /// **'Layout applied: {name}'**
  String layoutApplied(String name);

  /// No description provided for @pdfPaperSize.
  ///
  /// In en, this message translates to:
  /// **'PDF paper size'**
  String get pdfPaperSize;

  /// No description provided for @pdfPaperMatchSlide.
  ///
  /// In en, this message translates to:
  /// **'Match slide'**
  String get pdfPaperMatchSlide;

  /// No description provided for @pdfPaperA4.
  ///
  /// In en, this message translates to:
  /// **'A4'**
  String get pdfPaperA4;

  /// No description provided for @pdfPaperLetter.
  ///
  /// In en, this message translates to:
  /// **'Letter'**
  String get pdfPaperLetter;

  /// No description provided for @pdfMargins.
  ///
  /// In en, this message translates to:
  /// **'Page margins'**
  String get pdfMargins;

  /// No description provided for @pdfMarginCompact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get pdfMarginCompact;

  /// No description provided for @pdfMarginStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get pdfMarginStandard;

  /// No description provided for @pdfMarginWide.
  ///
  /// In en, this message translates to:
  /// **'Wide'**
  String get pdfMarginWide;

  /// No description provided for @pdfScaleToFit.
  ///
  /// In en, this message translates to:
  /// **'Scale to fit page'**
  String get pdfScaleToFit;

  /// No description provided for @includeHiddenSlides.
  ///
  /// In en, this message translates to:
  /// **'Include hidden slides'**
  String get includeHiddenSlides;

  /// No description provided for @insertChart.
  ///
  /// In en, this message translates to:
  /// **'Insert chart'**
  String get insertChart;

  /// No description provided for @editChart.
  ///
  /// In en, this message translates to:
  /// **'Edit chart'**
  String get editChart;

  /// No description provided for @chartTitle.
  ///
  /// In en, this message translates to:
  /// **'Chart title'**
  String get chartTitle;

  /// No description provided for @chartCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories (comma separated)'**
  String get chartCategories;

  /// No description provided for @chartSeriesName.
  ///
  /// In en, this message translates to:
  /// **'Series name'**
  String get chartSeriesName;

  /// No description provided for @chartSeriesValues.
  ///
  /// In en, this message translates to:
  /// **'Values (comma separated)'**
  String get chartSeriesValues;

  /// No description provided for @chartLegend.
  ///
  /// In en, this message translates to:
  /// **'Legend'**
  String get chartLegend;

  /// No description provided for @chartDataLabels.
  ///
  /// In en, this message translates to:
  /// **'Data labels'**
  String get chartDataLabels;

  /// No description provided for @chartStacked.
  ///
  /// In en, this message translates to:
  /// **'Stacked'**
  String get chartStacked;

  /// No description provided for @chartExisting.
  ///
  /// In en, this message translates to:
  /// **'Charts in this slide'**
  String get chartExisting;

  /// No description provided for @chartPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get chartPreview;

  /// No description provided for @chartInserted.
  ///
  /// In en, this message translates to:
  /// **'Chart inserted'**
  String get chartInserted;

  /// No description provided for @chartUpdated.
  ///
  /// In en, this message translates to:
  /// **'Chart updated'**
  String get chartUpdated;

  /// No description provided for @chartAddSeries.
  ///
  /// In en, this message translates to:
  /// **'Add series'**
  String get chartAddSeries;

  /// No description provided for @chartUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update chart'**
  String get chartUpdate;

  /// No description provided for @chartColumn.
  ///
  /// In en, this message translates to:
  /// **'Column'**
  String get chartColumn;

  /// No description provided for @chartBar.
  ///
  /// In en, this message translates to:
  /// **'Bar'**
  String get chartBar;

  /// No description provided for @chartLine.
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get chartLine;

  /// No description provided for @chartPie.
  ///
  /// In en, this message translates to:
  /// **'Pie'**
  String get chartPie;

  /// No description provided for @chartArea.
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get chartArea;

  /// No description provided for @chartDonut.
  ///
  /// In en, this message translates to:
  /// **'Donut'**
  String get chartDonut;

  /// No description provided for @chartCombo.
  ///
  /// In en, this message translates to:
  /// **'Combo'**
  String get chartCombo;

  /// No description provided for @chartTreemap.
  ///
  /// In en, this message translates to:
  /// **'Treemap'**
  String get chartTreemap;

  /// No description provided for @chartSunburst.
  ///
  /// In en, this message translates to:
  /// **'Sunburst'**
  String get chartSunburst;

  /// No description provided for @chartHistogram.
  ///
  /// In en, this message translates to:
  /// **'Histogram'**
  String get chartHistogram;

  /// No description provided for @chartBoxWhisker.
  ///
  /// In en, this message translates to:
  /// **'Box & Whisker'**
  String get chartBoxWhisker;

  /// No description provided for @chartWaterfall.
  ///
  /// In en, this message translates to:
  /// **'Waterfall'**
  String get chartWaterfall;

  /// No description provided for @chartFunnel.
  ///
  /// In en, this message translates to:
  /// **'Funnel'**
  String get chartFunnel;

  /// No description provided for @chartMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get chartMap;

  /// No description provided for @chartData.
  ///
  /// In en, this message translates to:
  /// **'Chart data'**
  String get chartData;

  /// No description provided for @gridAddRow.
  ///
  /// In en, this message translates to:
  /// **'Add row'**
  String get gridAddRow;

  /// No description provided for @gridRemoveRow.
  ///
  /// In en, this message translates to:
  /// **'Remove row'**
  String get gridRemoveRow;

  /// No description provided for @gridAddSeries.
  ///
  /// In en, this message translates to:
  /// **'Add series'**
  String get gridAddSeries;

  /// No description provided for @gridRemoveSeries.
  ///
  /// In en, this message translates to:
  /// **'Remove series'**
  String get gridRemoveSeries;

  /// No description provided for @gridQuickFill.
  ///
  /// In en, this message translates to:
  /// **'Quick fill'**
  String get gridQuickFill;

  /// No description provided for @gridPasteCsv.
  ///
  /// In en, this message translates to:
  /// **'Paste CSV'**
  String get gridPasteCsv;

  /// No description provided for @insertSmartArt.
  ///
  /// In en, this message translates to:
  /// **'Insert SmartArt'**
  String get insertSmartArt;

  /// No description provided for @editSmartArt.
  ///
  /// In en, this message translates to:
  /// **'Edit SmartArt'**
  String get editSmartArt;

  /// No description provided for @smartartTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagram title'**
  String get smartartTitle;

  /// No description provided for @smartartLayouts.
  ///
  /// In en, this message translates to:
  /// **'Layouts'**
  String get smartartLayouts;

  /// No description provided for @smartartNodes.
  ///
  /// In en, this message translates to:
  /// **'Text pane'**
  String get smartartNodes;

  /// No description provided for @smartartNode.
  ///
  /// In en, this message translates to:
  /// **'Node'**
  String get smartartNode;

  /// No description provided for @smartartAddNode.
  ///
  /// In en, this message translates to:
  /// **'Add node'**
  String get smartartAddNode;

  /// No description provided for @smartartRemoveNode.
  ///
  /// In en, this message translates to:
  /// **'Remove node'**
  String get smartartRemoveNode;

  /// No description provided for @smartartColorTheme.
  ///
  /// In en, this message translates to:
  /// **'Color theme'**
  String get smartartColorTheme;

  /// No description provided for @smartartExisting.
  ///
  /// In en, this message translates to:
  /// **'SmartArt in this slide'**
  String get smartartExisting;

  /// No description provided for @smartartInserted.
  ///
  /// In en, this message translates to:
  /// **'SmartArt inserted'**
  String get smartartInserted;

  /// No description provided for @smartartUpdated.
  ///
  /// In en, this message translates to:
  /// **'SmartArt updated'**
  String get smartartUpdated;

  /// No description provided for @smartartGroupList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get smartartGroupList;

  /// No description provided for @smartartGroupProcess.
  ///
  /// In en, this message translates to:
  /// **'Process'**
  String get smartartGroupProcess;

  /// No description provided for @smartartGroupCycle.
  ///
  /// In en, this message translates to:
  /// **'Cycle'**
  String get smartartGroupCycle;

  /// No description provided for @smartartGroupHierarchy.
  ///
  /// In en, this message translates to:
  /// **'Hierarchy'**
  String get smartartGroupHierarchy;

  /// No description provided for @smartartGroupRelationship.
  ///
  /// In en, this message translates to:
  /// **'Relationship'**
  String get smartartGroupRelationship;

  /// No description provided for @smartartGroupMatrix.
  ///
  /// In en, this message translates to:
  /// **'Matrix'**
  String get smartartGroupMatrix;

  /// No description provided for @smartartGroupPyramid.
  ///
  /// In en, this message translates to:
  /// **'Pyramid'**
  String get smartartGroupPyramid;

  /// No description provided for @smartartGroupPicture.
  ///
  /// In en, this message translates to:
  /// **'Picture'**
  String get smartartGroupPicture;

  /// No description provided for @insertVideo.
  ///
  /// In en, this message translates to:
  /// **'Insert video'**
  String get insertVideo;

  /// No description provided for @editVideo.
  ///
  /// In en, this message translates to:
  /// **'Edit video'**
  String get editVideo;

  /// No description provided for @videoInserted.
  ///
  /// In en, this message translates to:
  /// **'Video inserted'**
  String get videoInserted;

  /// No description provided for @videoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Video updated'**
  String get videoUpdated;

  /// No description provided for @videoExisting.
  ///
  /// In en, this message translates to:
  /// **'Videos in this slide'**
  String get videoExisting;

  /// No description provided for @videoFromFile.
  ///
  /// In en, this message translates to:
  /// **'MP4 file'**
  String get videoFromFile;

  /// No description provided for @videoFromYoutube.
  ///
  /// In en, this message translates to:
  /// **'YouTube link'**
  String get videoFromYoutube;

  /// No description provided for @videoPickFile.
  ///
  /// In en, this message translates to:
  /// **'Choose MP4 file…'**
  String get videoPickFile;

  /// No description provided for @videoYoutubeUrl.
  ///
  /// In en, this message translates to:
  /// **'YouTube URL'**
  String get videoYoutubeUrl;

  /// No description provided for @videoInvalidUrl.
  ///
  /// In en, this message translates to:
  /// **'This is not a valid YouTube link'**
  String get videoInvalidUrl;

  /// No description provided for @videoTrimStart.
  ///
  /// In en, this message translates to:
  /// **'Start (m:ss)'**
  String get videoTrimStart;

  /// No description provided for @videoTrimEnd.
  ///
  /// In en, this message translates to:
  /// **'End (m:ss)'**
  String get videoTrimEnd;

  /// No description provided for @videoNoFfmpeg.
  ///
  /// In en, this message translates to:
  /// **'FFmpeg not found — trim timestamps are kept for the HTML player only'**
  String get videoNoFfmpeg;

  /// No description provided for @videoAutoplay.
  ///
  /// In en, this message translates to:
  /// **'Play automatically'**
  String get videoAutoplay;

  /// No description provided for @videoLoop.
  ///
  /// In en, this message translates to:
  /// **'Loop'**
  String get videoLoop;

  /// No description provided for @videoPoster.
  ///
  /// In en, this message translates to:
  /// **'Poster frame'**
  String get videoPoster;

  /// No description provided for @videoChoosePoster.
  ///
  /// In en, this message translates to:
  /// **'Choose poster…'**
  String get videoChoosePoster;

  /// No description provided for @videoChangePoster.
  ///
  /// In en, this message translates to:
  /// **'Change poster…'**
  String get videoChangePoster;

  /// No description provided for @videoRemovePoster.
  ///
  /// In en, this message translates to:
  /// **'Remove poster'**
  String get videoRemovePoster;

  /// No description provided for @videoBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get videoBookmarks;

  /// No description provided for @videoAddBookmark.
  ///
  /// In en, this message translates to:
  /// **'Add bookmark'**
  String get videoAddBookmark;

  /// No description provided for @videoRemoveBookmark.
  ///
  /// In en, this message translates to:
  /// **'Remove bookmark'**
  String get videoRemoveBookmark;

  /// No description provided for @videoBookmarkLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get videoBookmarkLabel;

  /// No description provided for @videoBookmarkTime.
  ///
  /// In en, this message translates to:
  /// **'Time (m:ss)'**
  String get videoBookmarkTime;

  /// No description provided for @recordScreen.
  ///
  /// In en, this message translates to:
  /// **'Record screen'**
  String get recordScreen;

  /// No description provided for @recordInserted.
  ///
  /// In en, this message translates to:
  /// **'Recording inserted'**
  String get recordInserted;

  /// No description provided for @recordModeFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get recordModeFullscreen;

  /// No description provided for @recordModeWindow.
  ///
  /// In en, this message translates to:
  /// **'Window'**
  String get recordModeWindow;

  /// No description provided for @recordModeRegion.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get recordModeRegion;

  /// No description provided for @recordWindowSelect.
  ///
  /// In en, this message translates to:
  /// **'Window'**
  String get recordWindowSelect;

  /// No description provided for @recordWindowEmpty.
  ///
  /// In en, this message translates to:
  /// **'No visible windows found — minimize or restore a window and retry.'**
  String get recordWindowEmpty;

  /// No description provided for @recordWindowRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose a window to record.'**
  String get recordWindowRequired;

  /// No description provided for @recordRegionX.
  ///
  /// In en, this message translates to:
  /// **'X'**
  String get recordRegionX;

  /// No description provided for @recordRegionY.
  ///
  /// In en, this message translates to:
  /// **'Y'**
  String get recordRegionY;

  /// No description provided for @recordRegionW.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get recordRegionW;

  /// No description provided for @recordRegionH.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get recordRegionH;

  /// No description provided for @recordRegionRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a region width and height greater than 0.'**
  String get recordRegionRequired;

  /// No description provided for @recordRegionHint.
  ///
  /// In en, this message translates to:
  /// **'Coordinates are in screen pixels (top-left origin).'**
  String get recordRegionHint;

  /// No description provided for @recordStart.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get recordStart;

  /// No description provided for @recordCountdown.
  ///
  /// In en, this message translates to:
  /// **'Recording starts in…'**
  String get recordCountdown;

  /// No description provided for @recordRecording.
  ///
  /// In en, this message translates to:
  /// **'recording'**
  String get recordRecording;

  /// No description provided for @recordPaused.
  ///
  /// In en, this message translates to:
  /// **'paused'**
  String get recordPaused;

  /// No description provided for @recordPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get recordPause;

  /// No description provided for @recordResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get recordResume;

  /// No description provided for @recordStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get recordStop;

  /// No description provided for @recordDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get recordDuration;

  /// No description provided for @recordSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get recordSize;

  /// No description provided for @recordLimit.
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get recordLimit;

  /// No description provided for @recordMinutes.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get recordMinutes;

  /// No description provided for @recordPreviewHint.
  ///
  /// In en, this message translates to:
  /// **'Poster frame preview — insert this recording into the slide.'**
  String get recordPreviewHint;

  /// No description provided for @recordInsert.
  ///
  /// In en, this message translates to:
  /// **'Insert into slide'**
  String get recordInsert;

  /// No description provided for @recordDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get recordDiscard;

  /// No description provided for @recordNoFfmpeg.
  ///
  /// In en, this message translates to:
  /// **'Screen recording needs FFmpeg on this computer. Install FFmpeg (ffmpeg.org) and add it to PATH, then restart the app.'**
  String get recordNoFfmpeg;

  /// No description provided for @recordFailed.
  ///
  /// In en, this message translates to:
  /// **'Recording failed — please try again.'**
  String get recordFailed;

  /// No description provided for @recordDiskLowTitle.
  ///
  /// In en, this message translates to:
  /// **'Low disk space'**
  String get recordDiskLowTitle;

  /// No description provided for @recordDiskLowBody.
  ///
  /// In en, this message translates to:
  /// **'Less than 500 MB of free space on the drive. Recording may stop unexpectedly.'**
  String get recordDiskLowBody;

  /// No description provided for @recordContinue.
  ///
  /// In en, this message translates to:
  /// **'Record anyway'**
  String get recordContinue;

  /// No description provided for @recordMaxDurationReached.
  ///
  /// In en, this message translates to:
  /// **'Maximum recording duration reached — stopped automatically.'**
  String get recordMaxDurationReached;

  /// No description provided for @recordMaxSizeReached.
  ///
  /// In en, this message translates to:
  /// **'Maximum file size reached — stopped automatically.'**
  String get recordMaxSizeReached;

  /// No description provided for @audioRecordNarration.
  ///
  /// In en, this message translates to:
  /// **'Record narration for this slide'**
  String get audioRecordNarration;

  /// No description provided for @audioNoNarration.
  ///
  /// In en, this message translates to:
  /// **'No narration yet'**
  String get audioNoNarration;

  /// No description provided for @audioDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get audioDuration;

  /// No description provided for @audioTrimApply.
  ///
  /// In en, this message translates to:
  /// **'Trim'**
  String get audioTrimApply;

  /// No description provided for @audioTrimNoFfmpeg.
  ///
  /// In en, this message translates to:
  /// **'FFmpeg not found — trim timestamps kept for the HTML player only'**
  String get audioTrimNoFfmpeg;

  /// No description provided for @audioAutoplay.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get audioAutoplay;

  /// No description provided for @audioLoop.
  ///
  /// In en, this message translates to:
  /// **'Loop'**
  String get audioLoop;

  /// No description provided for @audioAcrossSlides.
  ///
  /// In en, this message translates to:
  /// **'Across slides'**
  String get audioAcrossSlides;

  /// No description provided for @audioHideIcon.
  ///
  /// In en, this message translates to:
  /// **'Hide icon'**
  String get audioHideIcon;

  /// No description provided for @audioRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove narration'**
  String get audioRemove;

  /// No description provided for @insertModel3d.
  ///
  /// In en, this message translates to:
  /// **'Insert 3D model'**
  String get insertModel3d;

  /// No description provided for @editModel3d.
  ///
  /// In en, this message translates to:
  /// **'Edit 3D model'**
  String get editModel3d;

  /// No description provided for @model3dInserted.
  ///
  /// In en, this message translates to:
  /// **'3D model inserted'**
  String get model3dInserted;

  /// No description provided for @model3dUpdated.
  ///
  /// In en, this message translates to:
  /// **'3D model updated'**
  String get model3dUpdated;

  /// No description provided for @model3dExisting.
  ///
  /// In en, this message translates to:
  /// **'3D models in this slide'**
  String get model3dExisting;

  /// No description provided for @model3dPickFile.
  ///
  /// In en, this message translates to:
  /// **'Choose GLB file…'**
  String get model3dPickFile;

  /// No description provided for @model3dInvalidFile.
  ///
  /// In en, this message translates to:
  /// **'This is not a valid GLB (glTF binary) file'**
  String get model3dInvalidFile;

  /// No description provided for @model3dName.
  ///
  /// In en, this message translates to:
  /// **'Model name'**
  String get model3dName;

  /// No description provided for @model3dRotate.
  ///
  /// In en, this message translates to:
  /// **'Auto-rotate on slide entry'**
  String get model3dRotate;

  /// No description provided for @model3dRotateHint.
  ///
  /// In en, this message translates to:
  /// **'Plays the model\'s first embedded animation (requires a GLB with animations)'**
  String get model3dRotateHint;

  /// No description provided for @insertIcon.
  ///
  /// In en, this message translates to:
  /// **'Insert icon'**
  String get insertIcon;

  /// No description provided for @iconSearch.
  ///
  /// In en, this message translates to:
  /// **'Search icons...'**
  String get iconSearch;

  /// No description provided for @iconRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get iconRecent;

  /// No description provided for @iconColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get iconColor;

  /// No description provided for @iconNoResults.
  ///
  /// In en, this message translates to:
  /// **'No icons match your search'**
  String get iconNoResults;

  /// No description provided for @iconInserted.
  ///
  /// In en, this message translates to:
  /// **'Icon inserted'**
  String get iconInserted;

  /// No description provided for @insertStockMedia.
  ///
  /// In en, this message translates to:
  /// **'Stock media'**
  String get insertStockMedia;

  /// No description provided for @mediaSearch.
  ///
  /// In en, this message translates to:
  /// **'Search images...'**
  String get mediaSearch;

  /// No description provided for @mediaNoResults.
  ///
  /// In en, this message translates to:
  /// **'No images match your search'**
  String get mediaNoResults;

  /// No description provided for @mediaInserted.
  ///
  /// In en, this message translates to:
  /// **'Image inserted'**
  String get mediaInserted;

  /// No description provided for @screenshot.
  ///
  /// In en, this message translates to:
  /// **'Screenshot'**
  String get screenshot;

  /// No description provided for @screenshotFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get screenshotFullscreen;

  /// No description provided for @screenshotWindow.
  ///
  /// In en, this message translates to:
  /// **'Window'**
  String get screenshotWindow;

  /// No description provided for @screenshotRegion.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get screenshotRegion;

  /// No description provided for @screenshotRegionHint.
  ///
  /// In en, this message translates to:
  /// **'Coordinates are in screen pixels (top-left origin).'**
  String get screenshotRegionHint;

  /// No description provided for @screenshotCapture.
  ///
  /// In en, this message translates to:
  /// **'Capture'**
  String get screenshotCapture;

  /// No description provided for @screenshotRecapture.
  ///
  /// In en, this message translates to:
  /// **'Recapture'**
  String get screenshotRecapture;

  /// No description provided for @screenshotFailed.
  ///
  /// In en, this message translates to:
  /// **'Screenshot failed. Check that a display is active, then retry.'**
  String get screenshotFailed;

  /// No description provided for @screenshotUse.
  ///
  /// In en, this message translates to:
  /// **'Use screenshot'**
  String get screenshotUse;

  /// No description provided for @screenshotInserted.
  ///
  /// In en, this message translates to:
  /// **'Screenshot inserted'**
  String get screenshotInserted;

  /// No description provided for @screenshotCropHint.
  ///
  /// In en, this message translates to:
  /// **'You can crop the screenshot in the next step.'**
  String get screenshotCropHint;

  /// No description provided for @photoAlbum.
  ///
  /// In en, this message translates to:
  /// **'Photo Album'**
  String get photoAlbum;

  /// No description provided for @photoAlbumEmpty.
  ///
  /// In en, this message translates to:
  /// **'Choose images to build your photo album slides.'**
  String get photoAlbumEmpty;

  /// No description provided for @photoAlbumPick.
  ///
  /// In en, this message translates to:
  /// **'Choose images...'**
  String get photoAlbumPick;

  /// No description provided for @photoAlbumCount.
  ///
  /// In en, this message translates to:
  /// **'images'**
  String get photoAlbumCount;

  /// No description provided for @photoAlbumCaption.
  ///
  /// In en, this message translates to:
  /// **'Caption'**
  String get photoAlbumCaption;

  /// No description provided for @photoAlbumFrame.
  ///
  /// In en, this message translates to:
  /// **'Frame'**
  String get photoAlbumFrame;

  /// No description provided for @photoAlbumTransition.
  ///
  /// In en, this message translates to:
  /// **'Transition'**
  String get photoAlbumTransition;

  /// No description provided for @photoAlbumCreate.
  ///
  /// In en, this message translates to:
  /// **'Create slides'**
  String get photoAlbumCreate;

  /// No description provided for @photoAlbumCreated.
  ///
  /// In en, this message translates to:
  /// **'Created {count} slides from photos'**
  String photoAlbumCreated(Object count);

  /// No description provided for @freeTextAdd.
  ///
  /// In en, this message translates to:
  /// **'Add text box'**
  String get freeTextAdd;

  /// No description provided for @freeTextEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit text box'**
  String get freeTextEdit;

  /// No description provided for @freeTextContent.
  ///
  /// In en, this message translates to:
  /// **'Text content'**
  String get freeTextContent;

  /// No description provided for @freeTextFontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get freeTextFontSize;

  /// No description provided for @freeTextColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get freeTextColor;

  /// No description provided for @freeTextBg.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get freeTextBg;

  /// No description provided for @freeTextBorder.
  ///
  /// In en, this message translates to:
  /// **'Border'**
  String get freeTextBorder;

  /// No description provided for @freeTextShadow.
  ///
  /// In en, this message translates to:
  /// **'Shadow'**
  String get freeTextShadow;

  /// No description provided for @freeTextWordArt.
  ///
  /// In en, this message translates to:
  /// **'WordArt style'**
  String get freeTextWordArt;

  /// No description provided for @freeTextAdded.
  ///
  /// In en, this message translates to:
  /// **'Text box added'**
  String get freeTextAdded;

  /// No description provided for @actionButton.
  ///
  /// In en, this message translates to:
  /// **'Action button'**
  String get actionButton;

  /// No description provided for @actionButtonKind.
  ///
  /// In en, this message translates to:
  /// **'Button type'**
  String get actionButtonKind;

  /// No description provided for @actionButtonAction.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get actionButtonAction;

  /// No description provided for @actionButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get actionButtonLabel;

  /// No description provided for @actionButtonUrl.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get actionButtonUrl;

  /// No description provided for @actionButtonColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get actionButtonColor;

  /// No description provided for @actionButtonInsert.
  ///
  /// In en, this message translates to:
  /// **'Insert button'**
  String get actionButtonInsert;

  /// No description provided for @actionButtonInserted.
  ///
  /// In en, this message translates to:
  /// **'Action button inserted'**
  String get actionButtonInserted;

  /// No description provided for @equation.
  ///
  /// In en, this message translates to:
  /// **'Equation'**
  String get equation;

  /// No description provided for @equationTemplate.
  ///
  /// In en, this message translates to:
  /// **'Template'**
  String get equationTemplate;

  /// No description provided for @equationCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom MathML'**
  String get equationCustom;

  /// No description provided for @equationInsert.
  ///
  /// In en, this message translates to:
  /// **'Insert equation'**
  String get equationInsert;

  /// No description provided for @equationInserted.
  ///
  /// In en, this message translates to:
  /// **'Equation inserted'**
  String get equationInserted;

  /// No description provided for @symbol.
  ///
  /// In en, this message translates to:
  /// **'Symbol'**
  String get symbol;

  /// No description provided for @symbolSearch.
  ///
  /// In en, this message translates to:
  /// **'Search symbols'**
  String get symbolSearch;

  /// No description provided for @symbolNoResults.
  ///
  /// In en, this message translates to:
  /// **'No symbols match'**
  String get symbolNoResults;

  /// No description provided for @symbolInserted.
  ///
  /// In en, this message translates to:
  /// **'Symbol inserted'**
  String get symbolInserted;

  /// No description provided for @ole.
  ///
  /// In en, this message translates to:
  /// **'OLE object'**
  String get ole;

  /// No description provided for @olePickFile.
  ///
  /// In en, this message translates to:
  /// **'Choose file... (xlsx, docx, pdf, pptx)'**
  String get olePickFile;

  /// No description provided for @olePickHint.
  ///
  /// In en, this message translates to:
  /// **'Embed a spreadsheet, document, or PDF into the slide. Double-click in PowerPoint to open it.'**
  String get olePickHint;

  /// No description provided for @oleLabel.
  ///
  /// In en, this message translates to:
  /// **'Icon label'**
  String get oleLabel;

  /// No description provided for @oleInsert.
  ///
  /// In en, this message translates to:
  /// **'Embed'**
  String get oleInsert;

  /// No description provided for @oleInserted.
  ///
  /// In en, this message translates to:
  /// **'OLE object embedded'**
  String get oleInserted;

  /// No description provided for @headerFooter.
  ///
  /// In en, this message translates to:
  /// **'Header & Footer'**
  String get headerFooter;

  /// No description provided for @hfHeader.
  ///
  /// In en, this message translates to:
  /// **'Header'**
  String get hfHeader;

  /// No description provided for @hfFooter.
  ///
  /// In en, this message translates to:
  /// **'Footer'**
  String get hfFooter;

  /// No description provided for @hfSlideNumber.
  ///
  /// In en, this message translates to:
  /// **'Slide number'**
  String get hfSlideNumber;

  /// No description provided for @hfDateTime.
  ///
  /// In en, this message translates to:
  /// **'Date & time'**
  String get hfDateTime;

  /// No description provided for @hfDateTimeAuto.
  ///
  /// In en, this message translates to:
  /// **'Update automatically (dynamic)'**
  String get hfDateTimeAuto;

  /// No description provided for @hfDateTimeFormat.
  ///
  /// In en, this message translates to:
  /// **'Date format'**
  String get hfDateTimeFormat;

  /// No description provided for @hfExcludeFirst.
  ///
  /// In en, this message translates to:
  /// **'Don\'t show on title slide'**
  String get hfExcludeFirst;

  /// No description provided for @hfApplyToSlide.
  ///
  /// In en, this message translates to:
  /// **'Apply to this slide'**
  String get hfApplyToSlide;

  /// No description provided for @hfApplyToAll.
  ///
  /// In en, this message translates to:
  /// **'Apply to all'**
  String get hfApplyToAll;

  /// No description provided for @hfApplied.
  ///
  /// In en, this message translates to:
  /// **'Header & Footer updated'**
  String get hfApplied;

  /// No description provided for @zoom.
  ///
  /// In en, this message translates to:
  /// **'Slide Zoom'**
  String get zoom;

  /// No description provided for @zoomTargetSlide.
  ///
  /// In en, this message translates to:
  /// **'Target slide'**
  String get zoomTargetSlide;

  /// No description provided for @zoomFrameStyle.
  ///
  /// In en, this message translates to:
  /// **'Frame style'**
  String get zoomFrameStyle;

  /// No description provided for @zoomLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get zoomLabel;

  /// No description provided for @zoomLabelHint.
  ///
  /// In en, this message translates to:
  /// **'Optional label'**
  String get zoomLabelHint;

  /// No description provided for @zoomInsert.
  ///
  /// In en, this message translates to:
  /// **'Insert zoom'**
  String get zoomInsert;

  /// No description provided for @zoomInserted.
  ///
  /// In en, this message translates to:
  /// **'Slide zoom inserted'**
  String get zoomInserted;

  /// No description provided for @cameo.
  ///
  /// In en, this message translates to:
  /// **'Cameo'**
  String get cameo;

  /// No description provided for @cameoLabel.
  ///
  /// In en, this message translates to:
  /// **'Camera label'**
  String get cameoLabel;

  /// No description provided for @cameoInsert.
  ///
  /// In en, this message translates to:
  /// **'Insert cameo'**
  String get cameoInsert;

  /// No description provided for @cameoInserted.
  ///
  /// In en, this message translates to:
  /// **'Cameo inserted'**
  String get cameoInserted;

  /// No description provided for @shape.
  ///
  /// In en, this message translates to:
  /// **'Shape'**
  String get shape;

  /// No description provided for @shapeInserted.
  ///
  /// In en, this message translates to:
  /// **'Shape inserted'**
  String get shapeInserted;

  /// No description provided for @shapeType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get shapeType;

  /// No description provided for @shapeFillColor.
  ///
  /// In en, this message translates to:
  /// **'Fill color'**
  String get shapeFillColor;

  /// No description provided for @shapeStrokeColor.
  ///
  /// In en, this message translates to:
  /// **'Stroke color'**
  String get shapeStrokeColor;

  /// No description provided for @shapeStrokeWidth.
  ///
  /// In en, this message translates to:
  /// **'Stroke width'**
  String get shapeStrokeWidth;

  /// No description provided for @shapeInsert.
  ///
  /// In en, this message translates to:
  /// **'Insert shape'**
  String get shapeInsert;

  /// No description provided for @shapeEditPoints.
  ///
  /// In en, this message translates to:
  /// **'Edit Points'**
  String get shapeEditPoints;

  /// No description provided for @shapeAddPoint.
  ///
  /// In en, this message translates to:
  /// **'Add point'**
  String get shapeAddPoint;

  /// No description provided for @shapeDeletePoint.
  ///
  /// In en, this message translates to:
  /// **'Delete point'**
  String get shapeDeletePoint;

  /// No description provided for @shapePoint.
  ///
  /// In en, this message translates to:
  /// **'Point'**
  String get shapePoint;

  /// No description provided for @shapeProperties.
  ///
  /// In en, this message translates to:
  /// **'Shape Properties'**
  String get shapeProperties;

  /// No description provided for @shapePropertiesUpdated.
  ///
  /// In en, this message translates to:
  /// **'Shape properties updated'**
  String get shapePropertiesUpdated;

  /// No description provided for @shapeNoSelection.
  ///
  /// In en, this message translates to:
  /// **'No shape selected'**
  String get shapeNoSelection;

  /// No description provided for @shapeTransparency.
  ///
  /// In en, this message translates to:
  /// **'Transparency'**
  String get shapeTransparency;

  /// No description provided for @shapeShadow.
  ///
  /// In en, this message translates to:
  /// **'Shadow'**
  String get shapeShadow;

  /// No description provided for @shapeGradient.
  ///
  /// In en, this message translates to:
  /// **'Gradient fill'**
  String get shapeGradient;

  /// No description provided for @shapeGradientStart.
  ///
  /// In en, this message translates to:
  /// **'Gradient start'**
  String get shapeGradientStart;

  /// No description provided for @shapeGradientEnd.
  ///
  /// In en, this message translates to:
  /// **'Gradient end'**
  String get shapeGradientEnd;

  /// No description provided for @shapeGradientAngle.
  ///
  /// In en, this message translates to:
  /// **'Gradient angle'**
  String get shapeGradientAngle;

  /// No description provided for @shapeMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge shapes'**
  String get shapeMerge;

  /// No description provided for @shapeMergeNeedTwo.
  ///
  /// In en, this message translates to:
  /// **'Add at least two shapes to merge'**
  String get shapeMergeNeedTwo;

  /// No description provided for @shapeMergeHint.
  ///
  /// In en, this message translates to:
  /// **'Select two shapes (click, Shift+click for multi-select), then choose the boolean operation:'**
  String get shapeMergeHint;

  /// No description provided for @shapeMergeUnion.
  ///
  /// In en, this message translates to:
  /// **'Union'**
  String get shapeMergeUnion;

  /// No description provided for @shapeMergeCombine.
  ///
  /// In en, this message translates to:
  /// **'Combine (XOR)'**
  String get shapeMergeCombine;

  /// No description provided for @shapeMergeIntersect.
  ///
  /// In en, this message translates to:
  /// **'Intersect'**
  String get shapeMergeIntersect;

  /// No description provided for @shapeMergeSubtract.
  ///
  /// In en, this message translates to:
  /// **'Subtract'**
  String get shapeMergeSubtract;

  /// No description provided for @shapeMergeEmpty.
  ///
  /// In en, this message translates to:
  /// **'The merge produced an empty result'**
  String get shapeMergeEmpty;

  /// No description provided for @shapeMerged.
  ///
  /// In en, this message translates to:
  /// **'Shapes merged'**
  String get shapeMerged;

  /// No description provided for @shapeScribble.
  ///
  /// In en, this message translates to:
  /// **'Draw freeform'**
  String get shapeScribble;

  /// No description provided for @zoomSlide.
  ///
  /// In en, this message translates to:
  /// **'Slide Zoom'**
  String get zoomSlide;

  /// No description provided for @zoomSection.
  ///
  /// In en, this message translates to:
  /// **'Section / Summary Zoom'**
  String get zoomSection;

  /// No description provided for @zoomPickSlides.
  ///
  /// In en, this message translates to:
  /// **'Pick the slides to include in the grid (min 2):'**
  String get zoomPickSlides;

  /// No description provided for @zoomColumns.
  ///
  /// In en, this message translates to:
  /// **'Columns:'**
  String get zoomColumns;

  /// No description provided for @imageTabBasic.
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get imageTabBasic;

  /// No description provided for @imageTabCrop.
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get imageTabCrop;

  /// No description provided for @imageTabBackground.
  ///
  /// In en, this message translates to:
  /// **'Remove BG'**
  String get imageTabBackground;

  /// No description provided for @imageTabAdjust.
  ///
  /// In en, this message translates to:
  /// **'Adjust'**
  String get imageTabAdjust;

  /// No description provided for @imageTabArtistic.
  ///
  /// In en, this message translates to:
  /// **'Artistic'**
  String get imageTabArtistic;

  /// No description provided for @imageCropAspect.
  ///
  /// In en, this message translates to:
  /// **'Aspect ratio'**
  String get imageCropAspect;

  /// No description provided for @imageAspectNone.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get imageAspectNone;

  /// No description provided for @imageAspectSquare.
  ///
  /// In en, this message translates to:
  /// **'1:1'**
  String get imageAspectSquare;

  /// No description provided for @imageAspect169.
  ///
  /// In en, this message translates to:
  /// **'16:9'**
  String get imageAspect169;

  /// No description provided for @imageAspect32.
  ///
  /// In en, this message translates to:
  /// **'3:2'**
  String get imageAspect32;

  /// No description provided for @imageAspect43.
  ///
  /// In en, this message translates to:
  /// **'4:3'**
  String get imageAspect43;

  /// No description provided for @imageCropApply.
  ///
  /// In en, this message translates to:
  /// **'Apply crop'**
  String get imageCropApply;

  /// No description provided for @imageCropShape.
  ///
  /// In en, this message translates to:
  /// **'Crop to shape'**
  String get imageCropShape;

  /// No description provided for @imageShapeRect.
  ///
  /// In en, this message translates to:
  /// **'Rectangle'**
  String get imageShapeRect;

  /// No description provided for @imageShapeOval.
  ///
  /// In en, this message translates to:
  /// **'Oval'**
  String get imageShapeOval;

  /// No description provided for @imageShapeRounded.
  ///
  /// In en, this message translates to:
  /// **'Rounded rect'**
  String get imageShapeRounded;

  /// No description provided for @imageShapeTriangle.
  ///
  /// In en, this message translates to:
  /// **'Triangle'**
  String get imageShapeTriangle;

  /// No description provided for @imageShapeDiamond.
  ///
  /// In en, this message translates to:
  /// **'Diamond'**
  String get imageShapeDiamond;

  /// No description provided for @imageShapeHeart.
  ///
  /// In en, this message translates to:
  /// **'Heart'**
  String get imageShapeHeart;

  /// No description provided for @imageRemoveBg.
  ///
  /// In en, this message translates to:
  /// **'Remove background'**
  String get imageRemoveBg;

  /// No description provided for @imageBgHint.
  ///
  /// In en, this message translates to:
  /// **'The flood-fill removes the colour around the seed point. Pick the seed position and tolerance, then apply.'**
  String get imageBgHint;

  /// No description provided for @imageTolerance.
  ///
  /// In en, this message translates to:
  /// **'Tolerance'**
  String get imageTolerance;

  /// No description provided for @imageSeedX.
  ///
  /// In en, this message translates to:
  /// **'Seed X (%)'**
  String get imageSeedX;

  /// No description provided for @imageSeedY.
  ///
  /// In en, this message translates to:
  /// **'Seed Y (%)'**
  String get imageSeedY;

  /// No description provided for @imageBrush.
  ///
  /// In en, this message translates to:
  /// **'Brush (refine)'**
  String get imageBrush;

  /// No description provided for @imageBrushSize.
  ///
  /// In en, this message translates to:
  /// **'Brush size'**
  String get imageBrushSize;

  /// No description provided for @imageErase.
  ///
  /// In en, this message translates to:
  /// **'Erase'**
  String get imageErase;

  /// No description provided for @imageRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get imageRestore;

  /// No description provided for @imageBrushHint.
  ///
  /// In en, this message translates to:
  /// **'Click the preview? Not in this build — use sliders and Apply.'**
  String get imageBrushHint;

  /// No description provided for @imageSaturation.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get imageSaturation;

  /// No description provided for @imageTone.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get imageTone;

  /// No description provided for @imageSharpness.
  ///
  /// In en, this message translates to:
  /// **'Sharpness'**
  String get imageSharpness;

  /// No description provided for @imageDuotoneA.
  ///
  /// In en, this message translates to:
  /// **'Recolor A'**
  String get imageDuotoneA;

  /// No description provided for @imageDuotoneB.
  ///
  /// In en, this message translates to:
  /// **'Recolor B'**
  String get imageDuotoneB;

  /// No description provided for @imageEffect.
  ///
  /// In en, this message translates to:
  /// **'Artistic effect'**
  String get imageEffect;

  /// No description provided for @imageIntensity.
  ///
  /// In en, this message translates to:
  /// **'Intensity'**
  String get imageIntensity;

  /// No description provided for @imageEffectBlur.
  ///
  /// In en, this message translates to:
  /// **'Blur'**
  String get imageEffectBlur;

  /// No description provided for @imageEffectMosaic.
  ///
  /// In en, this message translates to:
  /// **'Mosaic'**
  String get imageEffectMosaic;

  /// No description provided for @imageEffectPencil.
  ///
  /// In en, this message translates to:
  /// **'Pencil sketch'**
  String get imageEffectPencil;

  /// No description provided for @imageEffectOil.
  ///
  /// In en, this message translates to:
  /// **'Oil paint'**
  String get imageEffectOil;

  /// No description provided for @imageEffectFilm.
  ///
  /// In en, this message translates to:
  /// **'Old film'**
  String get imageEffectFilm;

  /// No description provided for @imagePreset.
  ///
  /// In en, this message translates to:
  /// **'Quick presets'**
  String get imagePreset;

  /// No description provided for @imagePresetBw.
  ///
  /// In en, this message translates to:
  /// **'B&W'**
  String get imagePresetBw;

  /// No description provided for @imagePresetVintage.
  ///
  /// In en, this message translates to:
  /// **'Vintage'**
  String get imagePresetVintage;

  /// No description provided for @imagePresetCool.
  ///
  /// In en, this message translates to:
  /// **'Cool'**
  String get imagePresetCool;

  /// No description provided for @imagePresetWarm.
  ///
  /// In en, this message translates to:
  /// **'Warm'**
  String get imagePresetWarm;

  /// No description provided for @imagePresetSoft.
  ///
  /// In en, this message translates to:
  /// **'Soft'**
  String get imagePresetSoft;

  /// No description provided for @imagePresetVivid.
  ///
  /// In en, this message translates to:
  /// **'Vivid'**
  String get imagePresetVivid;

  /// No description provided for @imageApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get imageApply;

  /// No description provided for @imageEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit image'**
  String get imageEditTitle;

  /// No description provided for @imageCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get imageCancel;

  /// No description provided for @imageUse.
  ///
  /// In en, this message translates to:
  /// **'Use this image'**
  String get imageUse;

  /// No description provided for @imageSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get imageSize;

  /// No description provided for @imageRotate.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get imageRotate;

  /// No description provided for @imageFlip.
  ///
  /// In en, this message translates to:
  /// **'Flip'**
  String get imageFlip;

  /// No description provided for @imageFlipH.
  ///
  /// In en, this message translates to:
  /// **'Horizontal'**
  String get imageFlipH;

  /// No description provided for @imageFlipV.
  ///
  /// In en, this message translates to:
  /// **'Vertical'**
  String get imageFlipV;

  /// No description provided for @imageBrightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get imageBrightness;

  /// No description provided for @imageContrast.
  ///
  /// In en, this message translates to:
  /// **'Contrast'**
  String get imageContrast;

  /// No description provided for @imageCropX.
  ///
  /// In en, this message translates to:
  /// **'Crop X'**
  String get imageCropX;

  /// No description provided for @imageCropY.
  ///
  /// In en, this message translates to:
  /// **'Crop Y'**
  String get imageCropY;

  /// No description provided for @imageCropW.
  ///
  /// In en, this message translates to:
  /// **'Crop width'**
  String get imageCropW;

  /// No description provided for @imageCropH.
  ///
  /// In en, this message translates to:
  /// **'Crop height'**
  String get imageCropH;

  /// No description provided for @imageRadius.
  ///
  /// In en, this message translates to:
  /// **'Corner radius'**
  String get imageRadius;

  /// No description provided for @fxTitle.
  ///
  /// In en, this message translates to:
  /// **'Effects'**
  String get fxTitle;

  /// No description provided for @fxShadow.
  ///
  /// In en, this message translates to:
  /// **'Shadow'**
  String get fxShadow;

  /// No description provided for @fxShadowOffsetX.
  ///
  /// In en, this message translates to:
  /// **'Offset X'**
  String get fxShadowOffsetX;

  /// No description provided for @fxShadowOffsetY.
  ///
  /// In en, this message translates to:
  /// **'Offset Y'**
  String get fxShadowOffsetY;

  /// No description provided for @fxShadowBlur.
  ///
  /// In en, this message translates to:
  /// **'Blur'**
  String get fxShadowBlur;

  /// No description provided for @fxShadowAlpha.
  ///
  /// In en, this message translates to:
  /// **'Opacity'**
  String get fxShadowAlpha;

  /// No description provided for @fxShadowColor.
  ///
  /// In en, this message translates to:
  /// **'Shadow color'**
  String get fxShadowColor;

  /// No description provided for @fxGlow.
  ///
  /// In en, this message translates to:
  /// **'Glow'**
  String get fxGlow;

  /// No description provided for @fxGlowColor.
  ///
  /// In en, this message translates to:
  /// **'Glow color'**
  String get fxGlowColor;

  /// No description provided for @fxGlowSize.
  ///
  /// In en, this message translates to:
  /// **'Glow size'**
  String get fxGlowSize;

  /// No description provided for @fxSoftEdge.
  ///
  /// In en, this message translates to:
  /// **'Soft edge'**
  String get fxSoftEdge;

  /// No description provided for @fxBevel.
  ///
  /// In en, this message translates to:
  /// **'Bevel / 3D preset'**
  String get fxBevel;

  /// No description provided for @fxRot3d.
  ///
  /// In en, this message translates to:
  /// **'3D rotation (X/Y/Z)'**
  String get fxRot3d;

  /// No description provided for @fxPresets.
  ///
  /// In en, this message translates to:
  /// **'Quick presets'**
  String get fxPresets;

  /// No description provided for @fxPresetNone.
  ///
  /// In en, this message translates to:
  /// **'No effect'**
  String get fxPresetNone;

  /// No description provided for @fxPresetSoft.
  ///
  /// In en, this message translates to:
  /// **'Soft'**
  String get fxPresetSoft;

  /// No description provided for @fxPresetHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get fxPresetHard;

  /// No description provided for @fxPresetGlow.
  ///
  /// In en, this message translates to:
  /// **'Glow'**
  String get fxPresetGlow;

  /// No description provided for @fxPresetNeumorphism.
  ///
  /// In en, this message translates to:
  /// **'Neumorphism'**
  String get fxPresetNeumorphism;

  /// No description provided for @selectionPane.
  ///
  /// In en, this message translates to:
  /// **'Selection Pane'**
  String get selectionPane;

  /// No description provided for @alignGuides.
  ///
  /// In en, this message translates to:
  /// **'Align & Guides'**
  String get alignGuides;

  /// No description provided for @textLayout.
  ///
  /// In en, this message translates to:
  /// **'Text Layout'**
  String get textLayout;

  /// No description provided for @animationPane.
  ///
  /// In en, this message translates to:
  /// **'Animations'**
  String get animationPane;

  /// No description provided for @transitions.
  ///
  /// In en, this message translates to:
  /// **'Transitions'**
  String get transitions;

  /// No description provided for @presentExit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get presentExit;

  /// No description provided for @presentLaunchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start the presentation'**
  String get presentLaunchFailed;

  /// No description provided for @webviewRuntimeMissing.
  ///
  /// In en, this message translates to:
  /// **'WebView2 runtime not found — install Microsoft Edge WebView2 to present smoothly'**
  String get webviewRuntimeMissing;

  /// No description provided for @presentHelp.
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get presentHelp;

  /// No description provided for @presentHelpClose.
  ///
  /// In en, this message translates to:
  /// **'Click anywhere to close this help.'**
  String get presentHelpClose;

  /// No description provided for @presentHelpKeysG.
  ///
  /// In en, this message translates to:
  /// **'Open slide grid navigator'**
  String get presentHelpKeysG;

  /// No description provided for @presentHelpKeysB.
  ///
  /// In en, this message translates to:
  /// **'Black / white screen'**
  String get presentHelpKeysB;

  /// No description provided for @presentHelpKeysP.
  ///
  /// In en, this message translates to:
  /// **'Pen'**
  String get presentHelpKeysP;

  /// No description provided for @presentHelpKeysL.
  ///
  /// In en, this message translates to:
  /// **'Laser pointer'**
  String get presentHelpKeysL;

  /// No description provided for @presentHelpKeysM.
  ///
  /// In en, this message translates to:
  /// **'Magnifier'**
  String get presentHelpKeysM;

  /// No description provided for @presentHelpKeysNumber.
  ///
  /// In en, this message translates to:
  /// **'Jump straight to a slide'**
  String get presentHelpKeysNumber;

  /// No description provided for @presentHelpKeysEsc.
  ///
  /// In en, this message translates to:
  /// **'Exit presentation'**
  String get presentHelpKeysEsc;

  /// No description provided for @presentGridTitle.
  ///
  /// In en, this message translates to:
  /// **'Jump to slide'**
  String get presentGridTitle;

  /// No description provided for @presentPen.
  ///
  /// In en, this message translates to:
  /// **'Pen'**
  String get presentPen;

  /// No description provided for @presentHighlighter.
  ///
  /// In en, this message translates to:
  /// **'Highlighter'**
  String get presentHighlighter;

  /// No description provided for @presentLaser.
  ///
  /// In en, this message translates to:
  /// **'Laser pointer'**
  String get presentLaser;

  /// No description provided for @presentMagnifier.
  ///
  /// In en, this message translates to:
  /// **'Magnifier'**
  String get presentMagnifier;

  /// No description provided for @presentClearInk.
  ///
  /// In en, this message translates to:
  /// **'Clear drawings'**
  String get presentClearInk;

  /// No description provided for @presenterNextSlide.
  ///
  /// In en, this message translates to:
  /// **'Next slide'**
  String get presenterNextSlide;

  /// No description provided for @presenterSpeakerNotes.
  ///
  /// In en, this message translates to:
  /// **'Speaker notes'**
  String get presenterSpeakerNotes;

  /// No description provided for @presenterNoNotes.
  ///
  /// In en, this message translates to:
  /// **'No notes for this slide'**
  String get presenterNoNotes;

  /// No description provided for @presenterEndOfPresentation.
  ///
  /// In en, this message translates to:
  /// **'End of presentation'**
  String get presenterEndOfPresentation;

  /// No description provided for @slide.
  ///
  /// In en, this message translates to:
  /// **'Slide'**
  String get slide;

  /// No description provided for @setupShowTitle.
  ///
  /// In en, this message translates to:
  /// **'Set Up Show'**
  String get setupShowTitle;

  /// No description provided for @setupShowMode.
  ///
  /// In en, this message translates to:
  /// **'Show type'**
  String get setupShowMode;

  /// No description provided for @setupShowModePresenter.
  ///
  /// In en, this message translates to:
  /// **'Presented by a speaker (full screen)'**
  String get setupShowModePresenter;

  /// No description provided for @setupShowModeBrowsed.
  ///
  /// In en, this message translates to:
  /// **'Browsed by an individual (window)'**
  String get setupShowModeBrowsed;

  /// No description provided for @setupShowModeKiosk.
  ///
  /// In en, this message translates to:
  /// **'Kiosk (full screen, loops)'**
  String get setupShowModeKiosk;

  /// No description provided for @setupShowLoop.
  ///
  /// In en, this message translates to:
  /// **'Loop continuously until Esc'**
  String get setupShowLoop;

  /// No description provided for @setupShowNoNarration.
  ///
  /// In en, this message translates to:
  /// **'Show without narration'**
  String get setupShowNoNarration;

  /// No description provided for @setupShowNoAnimation.
  ///
  /// In en, this message translates to:
  /// **'Show without animations'**
  String get setupShowNoAnimation;

  /// No description provided for @setupShowAdvance.
  ///
  /// In en, this message translates to:
  /// **'Advance every'**
  String get setupShowAdvance;

  /// No description provided for @setupShowPenColor.
  ///
  /// In en, this message translates to:
  /// **'Default pen colour'**
  String get setupShowPenColor;

  /// No description provided for @setupShowCustomShow.
  ///
  /// In en, this message translates to:
  /// **'Custom show'**
  String get setupShowCustomShow;

  /// No description provided for @setupShowCustomShowAll.
  ///
  /// In en, this message translates to:
  /// **'All slides (default)'**
  String get setupShowCustomShowAll;

  /// No description provided for @startShow.
  ///
  /// In en, this message translates to:
  /// **'Start Show'**
  String get startShow;

  /// No description provided for @customShowsTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom Shows'**
  String get customShowsTitle;

  /// No description provided for @customShowName.
  ///
  /// In en, this message translates to:
  /// **'Show name'**
  String get customShowName;

  /// No description provided for @customShowPickSlides.
  ///
  /// In en, this message translates to:
  /// **'Tap slides to include (tap again to remove)'**
  String get customShowPickSlides;

  /// No description provided for @customShowCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get customShowCreate;

  /// No description provided for @customShowEmpty.
  ///
  /// In en, this message translates to:
  /// **'No custom shows yet'**
  String get customShowEmpty;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @exportingInProgress.
  ///
  /// In en, this message translates to:
  /// **'Exporting…'**
  String get exportingInProgress;

  /// No description provided for @m6Title.
  ///
  /// In en, this message translates to:
  /// **'Milestone 6 — Xuất nâng cao (video / ảnh / in / định dạng / bảo mật)'**
  String get m6Title;

  /// No description provided for @m6Video.
  ///
  /// In en, this message translates to:
  /// **'Video/GIF'**
  String get m6Video;

  /// No description provided for @m6Images.
  ///
  /// In en, this message translates to:
  /// **'Ảnh slide'**
  String get m6Images;

  /// No description provided for @m6Print.
  ///
  /// In en, this message translates to:
  /// **'In (Windows)'**
  String get m6Print;

  /// No description provided for @m6Formats.
  ///
  /// In en, this message translates to:
  /// **'Định dạng'**
  String get m6Formats;

  /// No description provided for @m6Protect.
  ///
  /// In en, this message translates to:
  /// **'Bảo mật'**
  String get m6Protect;

  /// No description provided for @m6MovieFormat.
  ///
  /// In en, this message translates to:
  /// **'Định dạng phim'**
  String get m6MovieFormat;

  /// No description provided for @m6IncludeNarration.
  ///
  /// In en, this message translates to:
  /// **'Gộp narration (audio từng slide) vào MP4'**
  String get m6IncludeNarration;

  /// No description provided for @m6FfmpegMissing.
  ///
  /// In en, this message translates to:
  /// **'FFmpeg không tìm thấy — MP4 cần FFmpeg cài trên máy; GIF vẫn hoạt động.'**
  String get m6FfmpegMissing;

  /// No description provided for @m6ExportMovie.
  ///
  /// In en, this message translates to:
  /// **'Xuất video / GIF'**
  String get m6ExportMovie;

  /// No description provided for @m6ImageFormat.
  ///
  /// In en, this message translates to:
  /// **'Định dạng ảnh'**
  String get m6ImageFormat;

  /// No description provided for @m6TransparentPng.
  ///
  /// In en, this message translates to:
  /// **'Nền trong suốt (PNG)'**
  String get m6TransparentPng;

  /// No description provided for @m6ContactSheet.
  ///
  /// In en, this message translates to:
  /// **'Tạo 1 sheet ảnh tổng hợp (contact sheet)'**
  String get m6ContactSheet;

  /// No description provided for @m6ExportImages.
  ///
  /// In en, this message translates to:
  /// **'Xuất ảnh hàng loạt'**
  String get m6ExportImages;

  /// No description provided for @m6ChooseFolder.
  ///
  /// In en, this message translates to:
  /// **'Chọn thư mục xuất ảnh'**
  String get m6ChooseFolder;

  /// No description provided for @m6HandoutsPerPage.
  ///
  /// In en, this message translates to:
  /// **'Handouts: số slide mỗi trang'**
  String get m6HandoutsPerPage;

  /// No description provided for @m6PrintNotes.
  ///
  /// In en, this message translates to:
  /// **'In ghi chú speaker dưới slide'**
  String get m6PrintNotes;

  /// No description provided for @m6Grayscale.
  ///
  /// In en, this message translates to:
  /// **'In đen trắng (grayscale)'**
  String get m6Grayscale;

  /// No description provided for @m6OutlineRtf.
  ///
  /// In en, this message translates to:
  /// **'Outline RTF cho Word'**
  String get m6OutlineRtf;

  /// No description provided for @m6PrintDone.
  ///
  /// In en, this message translates to:
  /// **'Đã gửi tới máy in'**
  String get m6PrintDone;

  /// No description provided for @m6Inspect.
  ///
  /// In en, this message translates to:
  /// **'Quét metadata (Inspector)'**
  String get m6Inspect;

  /// No description provided for @m6Package.
  ///
  /// In en, this message translates to:
  /// **'Đóng gói thư mục + ZIP'**
  String get m6Package;

  /// No description provided for @m6InspectorClean.
  ///
  /// In en, this message translates to:
  /// **'Không phát hiện dữ liệu ẩn.'**
  String get m6InspectorClean;

  /// No description provided for @m6InspectorFound.
  ///
  /// In en, this message translates to:
  /// **'Phát hiện {count} dữ liệu ẩn (tác giả/email/phone/slide trống).'**
  String m6InspectorFound(Object count);

  /// No description provided for @m6CleanExport.
  ///
  /// In en, this message translates to:
  /// **'Xuất deck đã làm sạch (.pptx)'**
  String get m6CleanExport;

  /// No description provided for @m6ModifyPassword.
  ///
  /// In en, this message translates to:
  /// **'Mật khẩu chống sửa (để trống = không đặt)'**
  String get m6ModifyPassword;

  /// No description provided for @m6MarkFinal.
  ///
  /// In en, this message translates to:
  /// **'Mark as Final'**
  String get m6MarkFinal;

  /// No description provided for @m6ApplyPassword.
  ///
  /// In en, this message translates to:
  /// **'Đặt mật khẩu chống sửa'**
  String get m6ApplyPassword;

  /// No description provided for @m6PptFallback.
  ///
  /// In en, this message translates to:
  /// **'Cần LibreOffice trên máy để xuất .ppt — dùng .pptx và Save As từ PowerPoint.'**
  String get m6PptFallback;

  /// No description provided for @collabViewLink.
  ///
  /// In en, this message translates to:
  /// **'View-only link'**
  String get collabViewLink;

  /// No description provided for @collabViewLinkHint.
  ///
  /// In en, this message translates to:
  /// **'Anyone with this link can watch but not edit.'**
  String get collabViewLinkHint;

  /// No description provided for @collabCopyViewLink.
  ///
  /// In en, this message translates to:
  /// **'Copy view link'**
  String get collabCopyViewLink;

  /// No description provided for @collabRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get collabRole;

  /// No description provided for @collabRoleHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get collabRoleHost;

  /// No description provided for @collabRoleEditor.
  ///
  /// In en, this message translates to:
  /// **'Editor'**
  String get collabRoleEditor;

  /// No description provided for @collabRoleViewer.
  ///
  /// In en, this message translates to:
  /// **'Viewer'**
  String get collabRoleViewer;

  /// No description provided for @collabViewModeNotice.
  ///
  /// In en, this message translates to:
  /// **'View mode — this session is read-only.'**
  String get collabViewModeNotice;

  /// No description provided for @collabKick.
  ///
  /// In en, this message translates to:
  /// **'Remove from session'**
  String get collabKick;

  /// No description provided for @collabLockSession.
  ///
  /// In en, this message translates to:
  /// **'Lock session (refuse new joins)'**
  String get collabLockSession;

  /// No description provided for @collabUnlockSession.
  ///
  /// In en, this message translates to:
  /// **'Unlock session'**
  String get collabUnlockSession;

  /// No description provided for @collabLockSlide.
  ///
  /// In en, this message translates to:
  /// **'Editing…'**
  String get collabLockSlide;

  /// No description provided for @collabHistory.
  ///
  /// In en, this message translates to:
  /// **'Sync history'**
  String get collabHistory;

  /// No description provided for @collabHistoryEntry.
  ///
  /// In en, this message translates to:
  /// **'{name} edited slide {slide}'**
  String collabHistoryEntry(Object name, Object slide);

  /// No description provided for @collabReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting… (attempt {attempt})'**
  String collabReconnecting(Object attempt);

  /// No description provided for @collabReconnected.
  ///
  /// In en, this message translates to:
  /// **'Connection restored.'**
  String get collabReconnected;

  /// No description provided for @collabConnectionLost.
  ///
  /// In en, this message translates to:
  /// **'Connection lost — retrying…'**
  String get collabConnectionLost;

  /// No description provided for @collabLockedBy.
  ///
  /// In en, this message translates to:
  /// **'This slide is being edited by {name}'**
  String collabLockedBy(Object name);

  /// No description provided for @collabConflictDetail.
  ///
  /// In en, this message translates to:
  /// **'{name} changed slide {slide} at {time}'**
  String collabConflictDetail(Object name, Object slide, Object time);

  /// No description provided for @comments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get comments;

  /// No description provided for @commentsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add comment'**
  String get commentsAdd;

  /// No description provided for @commentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No comments on this slide yet.'**
  String get commentsEmpty;

  /// No description provided for @commentsResolve.
  ///
  /// In en, this message translates to:
  /// **'Resolve'**
  String get commentsResolve;

  /// No description provided for @commentsUnresolve.
  ///
  /// In en, this message translates to:
  /// **'Reopen'**
  String get commentsUnresolve;

  /// No description provided for @commentsReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get commentsReply;

  /// No description provided for @commentsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commentsDelete;

  /// No description provided for @commentsMentionHint.
  ///
  /// In en, this message translates to:
  /// **'Type @ to mention a collaborator'**
  String get commentsMentionHint;

  /// No description provided for @commentsNewChip.
  ///
  /// In en, this message translates to:
  /// **'New comments'**
  String get commentsNewChip;

  /// No description provided for @commentsExportNote.
  ///
  /// In en, this message translates to:
  /// **'Discussion notes'**
  String get commentsExportNote;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Your profile'**
  String get profileTitle;

  /// No description provided for @profileName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get profileName;

  /// No description provided for @profileAvatar.
  ///
  /// In en, this message translates to:
  /// **'Avatar'**
  String get profileAvatar;

  /// No description provided for @profileSave.
  ///
  /// In en, this message translates to:
  /// **'Save profile'**
  String get profileSave;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved.'**
  String get profileSaved;

  /// No description provided for @profileAuthorHint.
  ///
  /// In en, this message translates to:
  /// **'Used as comment author and export metadata.'**
  String get profileAuthorHint;

  /// No description provided for @cloudTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync'**
  String get cloudTitle;

  /// No description provided for @cloudUrl.
  ///
  /// In en, this message translates to:
  /// **'WebDAV server URL'**
  String get cloudUrl;

  /// No description provided for @cloudUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get cloudUsername;

  /// No description provided for @cloudPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get cloudPassword;

  /// No description provided for @cloudSave.
  ///
  /// In en, this message translates to:
  /// **'Save cloud account'**
  String get cloudSave;

  /// No description provided for @cloudSaved.
  ///
  /// In en, this message translates to:
  /// **'Cloud account saved.'**
  String get cloudSaved;

  /// No description provided for @cloudSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get cloudSyncNow;

  /// No description provided for @cloudSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get cloudSyncing;

  /// No description provided for @cloudSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced.'**
  String get cloudSynced;

  /// No description provided for @cloudConflictSaved.
  ///
  /// In en, this message translates to:
  /// **'Conflict saved as .conflict'**
  String get cloudConflictSaved;

  /// No description provided for @cloudNoAccount.
  ///
  /// In en, this message translates to:
  /// **'No cloud account configured.'**
  String get cloudNoAccount;

  /// No description provided for @versions.
  ///
  /// In en, this message translates to:
  /// **'Versions'**
  String get versions;

  /// No description provided for @versionsRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get versionsRestore;

  /// No description provided for @versionsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get versionsDelete;

  /// No description provided for @versionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No versions yet.'**
  String get versionsEmpty;

  /// No description provided for @versionsMax.
  ///
  /// In en, this message translates to:
  /// **'Up to 20 versions kept per project'**
  String get versionsMax;

  /// No description provided for @reuseTitle.
  ///
  /// In en, this message translates to:
  /// **'Reuse slides'**
  String get reuseTitle;

  /// No description provided for @designerTitle.
  ///
  /// In en, this message translates to:
  /// **'Designer'**
  String get designerTitle;

  /// No description provided for @designerSelectSlide.
  ///
  /// In en, this message translates to:
  /// **'Select a slide to see design ideas'**
  String get designerSelectSlide;

  /// No description provided for @designerUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo design'**
  String get designerUndo;

  /// No description provided for @designerDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get designerDark;

  /// No description provided for @designerApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get designerApply;

  /// No description provided for @reusePasteHint.
  ///
  /// In en, this message translates to:
  /// **'Paste a .ghita bundle (JSON) or plain text/HTML. Slides split on --- or h1/h2.'**
  String get reusePasteHint;

  /// No description provided for @reuseKeepOriginal.
  ///
  /// In en, this message translates to:
  /// **'Keep original formatting'**
  String get reuseKeepOriginal;

  /// No description provided for @reuseParse.
  ///
  /// In en, this message translates to:
  /// **'Parse'**
  String get reuseParse;

  /// No description provided for @reuseCompare.
  ///
  /// In en, this message translates to:
  /// **'Compare / Merge'**
  String get reuseCompare;

  /// No description provided for @reuseInserted.
  ///
  /// In en, this message translates to:
  /// **'Inserted slide(s)'**
  String get reuseInserted;

  /// No description provided for @compareVersionA.
  ///
  /// In en, this message translates to:
  /// **'Version A (.ghita JSON)'**
  String get compareVersionA;

  /// No description provided for @compareVersionB.
  ///
  /// In en, this message translates to:
  /// **'Version B (.ghita JSON)'**
  String get compareVersionB;

  /// No description provided for @compareRun.
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get compareRun;

  /// No description provided for @compareMergeIntoDeck.
  ///
  /// In en, this message translates to:
  /// **'Merge into deck'**
  String get compareMergeIntoDeck;

  /// No description provided for @copilotCreateDeck.
  ///
  /// In en, this message translates to:
  /// **'Create presentation'**
  String get copilotCreateDeck;

  /// No description provided for @copilotSummarize.
  ///
  /// In en, this message translates to:
  /// **'Summarize deck'**
  String get copilotSummarize;

  /// No description provided for @copilotAskDeck.
  ///
  /// In en, this message translates to:
  /// **'Ask about deck'**
  String get copilotAskDeck;

  /// No description provided for @dictationMic.
  ///
  /// In en, this message translates to:
  /// **'Dictation'**
  String get dictationMic;

  /// No description provided for @dictationListening.
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get dictationListening;

  /// No description provided for @dictationStop.
  ///
  /// In en, this message translates to:
  /// **'Stop dictation'**
  String get dictationStop;

  /// No description provided for @translateDeck.
  ///
  /// In en, this message translates to:
  /// **'Translate deck'**
  String get translateDeck;

  /// No description provided for @aiContextToggle.
  ///
  /// In en, this message translates to:
  /// **'AI uses deck context'**
  String get aiContextToggle;

  /// No description provided for @findReplace.
  ///
  /// In en, this message translates to:
  /// **'Find / Replace'**
  String get findReplace;

  /// No description provided for @accessibilityTitle.
  ///
  /// In en, this message translates to:
  /// **'Accessibility'**
  String get accessibilityTitle;

  /// No description provided for @addinsTitle.
  ///
  /// In en, this message translates to:
  /// **'Add-ins'**
  String get addinsTitle;

  /// No description provided for @readAloudTitle.
  ///
  /// In en, this message translates to:
  /// **'Read aloud'**
  String get readAloudTitle;

  /// No description provided for @ribbonCustomize.
  ///
  /// In en, this message translates to:
  /// **'Customize ribbon'**
  String get ribbonCustomize;

  /// No description provided for @viewNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get viewNormal;

  /// No description provided for @viewSorter.
  ///
  /// In en, this message translates to:
  /// **'Slide Sorter'**
  String get viewSorter;

  /// No description provided for @viewNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get viewNotes;

  /// No description provided for @viewReading.
  ///
  /// In en, this message translates to:
  /// **'Reading view'**
  String get viewReading;

  /// No description provided for @outlineView.
  ///
  /// In en, this message translates to:
  /// **'Outline view'**
  String get outlineView;

  /// No description provided for @spellcheck.
  ///
  /// In en, this message translates to:
  /// **'Spell check'**
  String get spellcheck;

  /// No description provided for @templateOnline.
  ///
  /// In en, this message translates to:
  /// **'Online templates'**
  String get templateOnline;

  /// No description provided for @versionsRestored.
  ///
  /// In en, this message translates to:
  /// **'Version restored.'**
  String get versionsRestored;

  /// No description provided for @deckEmpty.
  ///
  /// In en, this message translates to:
  /// **'Deck is empty — add slides first.'**
  String get deckEmpty;

  /// No description provided for @summarySlideAdded.
  ///
  /// In en, this message translates to:
  /// **'Summary slide added.'**
  String get summarySlideAdded;

  /// No description provided for @askDeckHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Which slide talks about budgets?'**
  String get askDeckHint;

  /// No description provided for @slideTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Slide title...'**
  String get slideTitleHint;

  /// No description provided for @slideUpdated.
  ///
  /// In en, this message translates to:
  /// **'Slide updated!'**
  String get slideUpdated;

  /// No description provided for @slideAddedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Slide added successfully!'**
  String get slideAddedSuccess;

  /// No description provided for @templateSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search templates...'**
  String get templateSearchHint;

  /// No description provided for @importSlides.
  ///
  /// In en, this message translates to:
  /// **'Import Slides'**
  String get importSlides;

  /// No description provided for @addAllSlides.
  ///
  /// In en, this message translates to:
  /// **'Add All ({count})'**
  String addAllSlides(Object count);

  /// No description provided for @addedSlideNotice.
  ///
  /// In en, this message translates to:
  /// **'Added \"{title}\" to slides!'**
  String addedSlideNotice(Object title);

  /// No description provided for @openGhitaFile.
  ///
  /// In en, this message translates to:
  /// **'Open .ghita file'**
  String get openGhitaFile;

  /// No description provided for @openedProject.
  ///
  /// In en, this message translates to:
  /// **'Opened: {project}'**
  String openedProject(Object project);

  /// No description provided for @moreTools.
  ///
  /// In en, this message translates to:
  /// **'More tools'**
  String get moreTools;

  /// No description provided for @collapseTools.
  ///
  /// In en, this message translates to:
  /// **'Collapse tools'**
  String get collapseTools;

  /// No description provided for @presenterBroadcastStart.
  ///
  /// In en, this message translates to:
  /// **'Broadcast over Wi-Fi'**
  String get presenterBroadcastStart;

  /// No description provided for @presenterBroadcastStop.
  ///
  /// In en, this message translates to:
  /// **'Stop Wi-Fi broadcast'**
  String get presenterBroadcastStop;

  /// No description provided for @presenterBroadcastCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy viewer link'**
  String get presenterBroadcastCopy;

  /// No description provided for @presenterBroadcastCopied.
  ///
  /// In en, this message translates to:
  /// **'Secure viewer link copied to the clipboard.'**
  String get presenterBroadcastCopied;

  /// No description provided for @presenterBroadcastFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start the Wi-Fi broadcast server.'**
  String get presenterBroadcastFailed;

  /// No description provided for @presenterViewerCount.
  ///
  /// In en, this message translates to:
  /// **'{count} viewers'**
  String presenterViewerCount(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
