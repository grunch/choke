import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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
    Locale('es'),
    Locale('ja'),
    Locale('pt')
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'Choke'**
  String get appTitle;

  /// Subtitle on home screen
  ///
  /// In en, this message translates to:
  /// **'Score your BJJ matches'**
  String get homeSubtitle;

  /// Bottom navigation label for Home tab
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Bottom navigation label for Match tab
  ///
  /// In en, this message translates to:
  /// **'Match'**
  String get navMatch;

  /// Bottom navigation label for Account tab
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get navAccount;

  /// Bottom navigation label for Settings tab
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Placeholder text in Match tab
  ///
  /// In en, this message translates to:
  /// **'Create a match from the Home screen'**
  String get matchListPlaceholder;

  /// Empty state title on home screen
  ///
  /// In en, this message translates to:
  /// **'No matches yet'**
  String get noMatchesYet;

  /// Empty state subtitle on home screen
  ///
  /// In en, this message translates to:
  /// **'Create a new one!'**
  String get createNewOne;

  /// Match status: waiting
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get statusWaiting;

  /// Match status: in progress
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get statusInProgress;

  /// Match status: finished
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get statusFinished;

  /// Match status: canceled
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get statusCanceled;

  /// Versus separator between scores
  ///
  /// In en, this message translates to:
  /// **'vs'**
  String get vs;

  /// Account screen app bar title
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// Tooltip for import key button
  ///
  /// In en, this message translates to:
  /// **'Import/Change Key'**
  String get importChangeKey;

  /// Account screen header title
  ///
  /// In en, this message translates to:
  /// **'Your Nostr Identity'**
  String get yourNostrIdentity;

  /// Account screen header subtitle
  ///
  /// In en, this message translates to:
  /// **'This keypair identifies you on the network'**
  String get keypairDescription;

  /// Section title for public key
  ///
  /// In en, this message translates to:
  /// **'Public Key (npub)'**
  String get publicKeyNpub;

  /// Placeholder while key is being generated
  ///
  /// In en, this message translates to:
  /// **'Generating...'**
  String get generating;

  /// Copy button label
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// Show QR code button label
  ///
  /// In en, this message translates to:
  /// **'Show QR'**
  String get showQr;

  /// Message when key is not available
  ///
  /// In en, this message translates to:
  /// **'Key unavailable'**
  String get keyUnavailable;

  /// Error message when key fails to load
  ///
  /// In en, this message translates to:
  /// **'Error loading key'**
  String get errorLoadingKey;

  /// Section title for private key
  ///
  /// In en, this message translates to:
  /// **'Private Key (nsec)'**
  String get privateKeyNsec;

  /// Warning about private key
  ///
  /// In en, this message translates to:
  /// **'Never share your private key with anyone!'**
  String get neverSharePrivateKey;

  /// Hint text under hidden private key
  ///
  /// In en, this message translates to:
  /// **'Tap to reveal • Keep this secret!'**
  String get tapToReveal;

  /// Button to copy key to clipboard
  ///
  /// In en, this message translates to:
  /// **'Copy to Clipboard'**
  String get copyToClipboard;

  /// Snackbar message when something is copied
  ///
  /// In en, this message translates to:
  /// **'{label} copied to clipboard'**
  String copiedToClipboard(String label);

  /// Label for public key when copying
  ///
  /// In en, this message translates to:
  /// **'Public key'**
  String get publicKey;

  /// Label for private key when copying
  ///
  /// In en, this message translates to:
  /// **'Private key'**
  String get privateKey;

  /// Import key dialog title
  ///
  /// In en, this message translates to:
  /// **'Import Private Key'**
  String get importPrivateKey;

  /// Warning message in import dialog
  ///
  /// In en, this message translates to:
  /// **'Warning: Importing a new private key will replace your current identity. This action cannot be undone.'**
  String get importWarning;

  /// Hint text for nsec input field
  ///
  /// In en, this message translates to:
  /// **'Enter nsec...'**
  String get enterNsec;

  /// Cancel button label
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Import button label
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// Validation error: empty nsec
  ///
  /// In en, this message translates to:
  /// **'Please enter an nsec'**
  String get pleaseEnterNsec;

  /// Validation error: bad nsec format
  ///
  /// In en, this message translates to:
  /// **'Invalid nsec format (should start with nsec1)'**
  String get invalidNsecFormat;

  /// Success message after key import
  ///
  /// In en, this message translates to:
  /// **'Private key imported successfully'**
  String get keyImportedSuccessfully;

  /// Error message when key import fails
  ///
  /// In en, this message translates to:
  /// **'Failed to import key. Please check the format.'**
  String get failedToImportKey;

  /// QR dialog title
  ///
  /// In en, this message translates to:
  /// **'Your Public Key'**
  String get yourPublicKey;

  /// QR dialog description
  ///
  /// In en, this message translates to:
  /// **'Scan this QR code to share your public key'**
  String get scanQrToShare;

  /// Close button label
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Section title for security tips
  ///
  /// In en, this message translates to:
  /// **'Security Tips'**
  String get securityTips;

  /// Security tip: backup title
  ///
  /// In en, this message translates to:
  /// **'Backup your keys'**
  String get tipBackupTitle;

  /// Security tip: backup description
  ///
  /// In en, this message translates to:
  /// **'Write down your nsec and store it in a safe place.'**
  String get tipBackupDescription;

  /// Security tip: never share title
  ///
  /// In en, this message translates to:
  /// **'Never share your nsec'**
  String get tipNeverShareTitle;

  /// Security tip: never share description
  ///
  /// In en, this message translates to:
  /// **'Anyone with your nsec can impersonate you.'**
  String get tipNeverShareDescription;

  /// Security tip: secure storage title
  ///
  /// In en, this message translates to:
  /// **'Secure storage'**
  String get tipSecureStorageTitle;

  /// Security tip: secure storage description
  ///
  /// In en, this message translates to:
  /// **'Keys are stored securely on your device.'**
  String get tipSecureStorageDescription;

  /// Create match screen title
  ///
  /// In en, this message translates to:
  /// **'New Match'**
  String get newMatch;

  /// Fighter 1 section label
  ///
  /// In en, this message translates to:
  /// **'Fighter 1'**
  String get fighter1;

  /// Fighter 2 section label
  ///
  /// In en, this message translates to:
  /// **'Fighter 2'**
  String get fighter2;

  /// Hint text for fighter name input
  ///
  /// In en, this message translates to:
  /// **'Enter fighter name'**
  String get enterFighterName;

  /// Validation: fighter 1 name empty
  ///
  /// In en, this message translates to:
  /// **'Fighter 1 name is required'**
  String get fighter1NameRequired;

  /// Validation: fighter 2 name empty
  ///
  /// In en, this message translates to:
  /// **'Fighter 2 name is required'**
  String get fighter2NameRequired;

  /// Color picker label for fighter 1
  ///
  /// In en, this message translates to:
  /// **'Fighter 1 Color'**
  String get fighter1Color;

  /// Color picker label for fighter 2
  ///
  /// In en, this message translates to:
  /// **'Fighter 2 Color'**
  String get fighter2Color;

  /// Duration section label
  ///
  /// In en, this message translates to:
  /// **'Match Duration'**
  String get matchDuration;

  /// Create match button label
  ///
  /// In en, this message translates to:
  /// **'Create Match'**
  String get createMatch;

  /// Error when match publish fails
  ///
  /// In en, this message translates to:
  /// **'Could not publish match. Check your connection and try again.'**
  String get couldNotPublishMatch;

  /// Retry button label
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Match ID in app bar
  ///
  /// In en, this message translates to:
  /// **'Match #{id}'**
  String matchId(String id);

  /// Timer display when match is canceled
  ///
  /// In en, this message translates to:
  /// **'CANCELED'**
  String get canceled;

  /// VS label between score cards
  ///
  /// In en, this message translates to:
  /// **'VS'**
  String get vsLabel;

  /// Scoring button: +2 points
  ///
  /// In en, this message translates to:
  /// **'Takedown / Sweep'**
  String get takedownSweep;

  /// Scoring button: +3 points
  ///
  /// In en, this message translates to:
  /// **'Guard Pass'**
  String get guardPass;

  /// Scoring button: +4 points
  ///
  /// In en, this message translates to:
  /// **'Mount / Back Take'**
  String get mountBackTake;

  /// Advantage button label
  ///
  /// In en, this message translates to:
  /// **'Advantage'**
  String get advantage;

  /// Penalty button label
  ///
  /// In en, this message translates to:
  /// **'Penalty'**
  String get penalty;

  /// Undo button label
  ///
  /// In en, this message translates to:
  /// **'Undo Last Action'**
  String get undoLastAction;

  /// Start match button label
  ///
  /// In en, this message translates to:
  /// **'Start Match'**
  String get startMatch;

  /// Finish match button label
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// Status text when match is finished
  ///
  /// In en, this message translates to:
  /// **'Match Finished'**
  String get matchFinished;

  /// Status text when match is canceled
  ///
  /// In en, this message translates to:
  /// **'Match Canceled'**
  String get matchCanceled;

  /// Finish match dialog title
  ///
  /// In en, this message translates to:
  /// **'Finish Match?'**
  String get finishMatchQuestion;

  /// Finish match dialog content
  ///
  /// In en, this message translates to:
  /// **'This will end the match and publish the final score.'**
  String get finishMatchDescription;

  /// Cancel match dialog title
  ///
  /// In en, this message translates to:
  /// **'Cancel Match?'**
  String get cancelMatchQuestion;

  /// Cancel match dialog content
  ///
  /// In en, this message translates to:
  /// **'This will cancel the match. Scores will not be saved.'**
  String get cancelMatchDescription;

  /// Go back button in cancel dialog
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get goBack;

  /// Cancel match button in dialog
  ///
  /// In en, this message translates to:
  /// **'Cancel Match'**
  String get cancelMatch;

  /// Leave match dialog title
  ///
  /// In en, this message translates to:
  /// **'Leave Match?'**
  String get leaveMatchQuestion;

  /// Leave match dialog content
  ///
  /// In en, this message translates to:
  /// **'The match is still in progress. Are you sure you want to leave?'**
  String get leaveMatchDescription;

  /// Stay button in leave dialog
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get stay;

  /// Leave button in leave dialog
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Settings section: appearance
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get sectionAppearance;

  /// Settings section: nostr
  ///
  /// In en, this message translates to:
  /// **'Nostr'**
  String get sectionNostr;

  /// Relay management tile title
  ///
  /// In en, this message translates to:
  /// **'Relays'**
  String get relays;

  /// Relay management tile subtitle
  ///
  /// In en, this message translates to:
  /// **'Manage relay connections'**
  String get manageRelayConnections;

  /// Settings section: match
  ///
  /// In en, this message translates to:
  /// **'Match'**
  String get sectionMatch;

  /// Default duration tile title
  ///
  /// In en, this message translates to:
  /// **'Default Match Duration'**
  String get defaultMatchDuration;

  /// Default duration value
  ///
  /// In en, this message translates to:
  /// **'5 minutes'**
  String get fiveMinutes;

  /// Settings section: about
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get sectionAbout;

  /// Version tile title
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// Source code tile title
  ///
  /// In en, this message translates to:
  /// **'Source Code'**
  String get sourceCode;

  /// Settings section: language
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get sectionLanguage;

  /// Language selector tile title
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Language picker dialog title
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// Relay management screen title
  ///
  /// In en, this message translates to:
  /// **'Relay Management'**
  String get relayManagement;

  /// Refresh button tooltip
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// Add relay input label
  ///
  /// In en, this message translates to:
  /// **'Add Custom Relay'**
  String get addCustomRelay;

  /// Relay URL input hint
  ///
  /// In en, this message translates to:
  /// **'wss://relay.example.com'**
  String get relayHint;

  /// Validation: empty relay URL
  ///
  /// In en, this message translates to:
  /// **'Please enter a relay URL'**
  String get pleaseEnterRelayUrl;

  /// Validation: invalid relay URL prefix
  ///
  /// In en, this message translates to:
  /// **'URL must start with wss:// or ws://'**
  String get relayUrlMustStartWithWss;

  /// Button label while adding relay
  ///
  /// In en, this message translates to:
  /// **'Adding...'**
  String get adding;

  /// Add button label
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Empty state title for relays
  ///
  /// In en, this message translates to:
  /// **'No relays configured'**
  String get noRelaysConfigured;

  /// Empty state subtitle for relays
  ///
  /// In en, this message translates to:
  /// **'Add a relay to start publishing events'**
  String get addRelayToStart;

  /// Relay status: disabled
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get relayStatusDisabled;

  /// Relay status: connected default
  ///
  /// In en, this message translates to:
  /// **'Connected • Default'**
  String get relayStatusConnectedDefault;

  /// Relay status: connecting default
  ///
  /// In en, this message translates to:
  /// **'Connecting • Default'**
  String get relayStatusConnectingDefault;

  /// Relay status: connected
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get relayStatusConnected;

  /// Relay status: connecting
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get relayStatusConnecting;

  /// Remove relay dialog title
  ///
  /// In en, this message translates to:
  /// **'Remove Relay?'**
  String get removeRelayQuestion;

  /// Remove relay dialog content
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove {url}?'**
  String removeRelayConfirmation(String url);

  /// Remove button label
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// Success message after adding relay
  ///
  /// In en, this message translates to:
  /// **'Relay added successfully'**
  String get relayAddedSuccessfully;

  /// Success message after removing relay
  ///
  /// In en, this message translates to:
  /// **'Relay removed'**
  String get relayRemoved;

  /// System default locale option
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemDefault;

  /// Theme mode selector title
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeMode;

  /// Dark theme option
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// Light theme option
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// Hint text explaining system theme follows device setting
  ///
  /// In en, this message translates to:
  /// **'Follow system setting'**
  String get followSystemTheme;
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
      <String>['en', 'es', 'ja', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'ja':
      return AppLocalizationsJa();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
