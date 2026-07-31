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

  /// Tooltip for generate new keypair button
  ///
  /// In en, this message translates to:
  /// **'Generate New Key'**
  String get generateNewKey;

  /// Title of the generate new keypair confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Generate New Keypair?'**
  String get generateNewKeyTitle;

  /// Warning message in the generate new keypair dialog
  ///
  /// In en, this message translates to:
  /// **'This will generate a new keypair and replace your current identity. If you have not backed up your current private key, it will be lost permanently. This action cannot be undone.'**
  String get generateNewKeyWarning;

  /// Confirm button label in the generate new keypair dialog
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get generate;

  /// Snackbar shown after a new keypair is generated
  ///
  /// In en, this message translates to:
  /// **'New keypair generated successfully'**
  String get keyGeneratedSuccessfully;

  /// Snackbar shown when generating a new keypair fails
  ///
  /// In en, this message translates to:
  /// **'Failed to generate new key. Please try again.'**
  String get failedToGenerateKey;

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

  /// Button and share-sheet subject for sharing the bjjscore.live live board link
  ///
  /// In en, this message translates to:
  /// **'Share live board'**
  String get shareLiveBoard;

  /// Message shown before the shared bjjscore.live link in the share sheet
  ///
  /// In en, this message translates to:
  /// **'Follow my BJJ matches live on bjjscore.live:'**
  String get shareLiveBoardMessage;

  /// Error snackbar when the platform share sheet fails to open
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the share sheet'**
  String get shareFailed;

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

  /// Pause the match clock (accessibility label / tooltip)
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// Resume the match clock (accessibility label / tooltip)
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// Clock status shown while the match is paused
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get statusPaused;

  /// Finish match button label
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// Suffix hint on hold-to-confirm buttons, e.g. 'Finish · hold'
  ///
  /// In en, this message translates to:
  /// **'hold'**
  String get holdHint;

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

  /// Read-only indicator shown when viewing a finished or canceled match
  ///
  /// In en, this message translates to:
  /// **'View only'**
  String get matchReadOnly;

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

  /// No description provided for @website.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get website;

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

  /// Error snackbar when the chosen language cannot be stored
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the language. Please try again.'**
  String get languageSaveFailed;

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
  /// **'System'**
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

  /// License screen title
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get licenseTitle;

  /// GNU GPL v3.0 license notice displayed in license screen
  ///
  /// In en, this message translates to:
  /// **'Choke\nCopyright (C) 2026 ProtoLayer OÜ\n\nThis program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.\n\nThis program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.'**
  String get licenseText;

  /// Lead-in above the tappable link to the full GNU GPL v3.0 text
  ///
  /// In en, this message translates to:
  /// **'Want to read the whole thing? The full license lives here:'**
  String get licenseReadFull;

  /// License tile title in Settings
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get licenseLabel;

  /// License tile subtitle in Settings
  ///
  /// In en, this message translates to:
  /// **'GNU GPL v3.0'**
  String get licenseSubtitle;

  /// No description provided for @relayErrorLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load relay configuration'**
  String get relayErrorLoadFailed;

  /// No description provided for @relayErrorAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'Relay already exists'**
  String get relayErrorAlreadyExists;

  /// No description provided for @relayErrorInvalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Invalid relay URL. Must start with wss://'**
  String get relayErrorInvalidUrl;

  /// No description provided for @relayErrorUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Unable to connect to relay. Please check the URL and try again'**
  String get relayErrorUnreachable;

  /// No description provided for @relayErrorAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add relay'**
  String get relayErrorAddFailed;

  /// No description provided for @relayErrorRemoveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove relay'**
  String get relayErrorRemoveFailed;

  /// No description provided for @relayErrorCannotRemoveLast.
  ///
  /// In en, this message translates to:
  /// **'Cannot remove the last active relay'**
  String get relayErrorCannotRemoveLast;

  /// No description provided for @relayErrorToggleFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update relay'**
  String get relayErrorToggleFailed;

  /// No description provided for @relayErrorCannotDisableLast.
  ///
  /// In en, this message translates to:
  /// **'At least one relay must remain active'**
  String get relayErrorCannotDisableLast;

  /// Creator credit in settings footer
  ///
  /// In en, this message translates to:
  /// **'Built by {name}'**
  String builtBy(String name);

  /// Accessibility label for the black belt image in the settings footer
  ///
  /// In en, this message translates to:
  /// **'BJJ black belt'**
  String get bjjBlackBelt;

  /// Title of the sheet asking the referee how the match ended
  ///
  /// In en, this message translates to:
  /// **'How did it end?'**
  String get outcomeTitle;

  /// Outcome sheet: outcomeSubmission
  ///
  /// In en, this message translates to:
  /// **'Submission'**
  String get outcomeSubmission;

  /// Outcome sheet: outcomePoints
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get outcomePoints;

  /// Outcome sheet: outcomeAdvantages
  ///
  /// In en, this message translates to:
  /// **'Advantages'**
  String get outcomeAdvantages;

  /// Outcome sheet: outcomeDecision
  ///
  /// In en, this message translates to:
  /// **'Referee decision'**
  String get outcomeDecision;

  /// Outcome sheet: outcomeDq
  ///
  /// In en, this message translates to:
  /// **'Disqualification'**
  String get outcomeDq;

  /// Outcome sheet: outcomeForfeit
  ///
  /// In en, this message translates to:
  /// **'Forfeit'**
  String get outcomeForfeit;

  /// Outcome sheet: outcomeDraw
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get outcomeDraw;

  /// Outcome sheet: outcomeWhichFighter
  ///
  /// In en, this message translates to:
  /// **'Which fighter won?'**
  String get outcomeWhichFighter;

  /// Outcome sheet: outcomeTechnique
  ///
  /// In en, this message translates to:
  /// **'Technique (optional)'**
  String get outcomeTechnique;

  /// Outcome sheet: outcomeDqCategory
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get outcomeDqCategory;

  /// Outcome sheet: outcomeDqAccumulated
  ///
  /// In en, this message translates to:
  /// **'Four penalties'**
  String get outcomeDqAccumulated;

  /// Outcome sheet: outcomeDqTechnical
  ///
  /// In en, this message translates to:
  /// **'Technical foul'**
  String get outcomeDqTechnical;

  /// Outcome sheet: outcomeDqDisciplinary
  ///
  /// In en, this message translates to:
  /// **'Disciplinary foul'**
  String get outcomeDqDisciplinary;

  /// Outcome sheet: outcomeDqDetail
  ///
  /// In en, this message translates to:
  /// **'What happened (optional)'**
  String get outcomeDqDetail;

  /// Outcome sheet: outcomeConfirm
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get outcomeConfirm;

  /// Outcome sheet: outcomeTimeUp
  ///
  /// In en, this message translates to:
  /// **'Time is up — how did it end?'**
  String get outcomeTimeUp;

  /// Names the winner
  ///
  /// In en, this message translates to:
  /// **'{name} wins'**
  String outcomeWinsBy(String name);

  /// Skip an optional field
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// Outcome: outcomeAmend
  ///
  /// In en, this message translates to:
  /// **'Amend result'**
  String get outcomeAmend;

  /// Outcome: outcomeSubmissionOf
  ///
  /// In en, this message translates to:
  /// **'Submission ({technique})'**
  String outcomeSubmissionOf(String technique);

  /// Submission technique: Armbar
  ///
  /// In en, this message translates to:
  /// **'Armbar'**
  String get subArmbar;

  /// Submission technique: Rear naked choke
  ///
  /// In en, this message translates to:
  /// **'Rear naked choke'**
  String get subRearNakedChoke;

  /// Submission technique: Triangle choke
  ///
  /// In en, this message translates to:
  /// **'Triangle choke'**
  String get subTriangle;

  /// Submission technique: Guillotine
  ///
  /// In en, this message translates to:
  /// **'Guillotine'**
  String get subGuillotine;

  /// Submission technique: Kimura
  ///
  /// In en, this message translates to:
  /// **'Kimura'**
  String get subKimura;

  /// Submission technique: Americana
  ///
  /// In en, this message translates to:
  /// **'Americana'**
  String get subAmericana;

  /// Submission technique: Cross collar choke
  ///
  /// In en, this message translates to:
  /// **'Cross collar choke'**
  String get subCrossCollarChoke;

  /// Submission technique: Bow and arrow choke
  ///
  /// In en, this message translates to:
  /// **'Bow and arrow choke'**
  String get subBowAndArrow;

  /// Submission technique: Ezekiel choke
  ///
  /// In en, this message translates to:
  /// **'Ezekiel choke'**
  String get subEzekiel;

  /// Submission technique: Omoplata
  ///
  /// In en, this message translates to:
  /// **'Omoplata'**
  String get subOmoplata;

  /// Submission technique: Arm triangle
  ///
  /// In en, this message translates to:
  /// **'Arm triangle'**
  String get subArmTriangle;

  /// Submission technique: North–south choke
  ///
  /// In en, this message translates to:
  /// **'North–south choke'**
  String get subNorthSouthChoke;

  /// Submission technique: Straight ankle lock
  ///
  /// In en, this message translates to:
  /// **'Straight ankle lock'**
  String get subStraightAnkleLock;

  /// Submission technique: Heel hook
  ///
  /// In en, this message translates to:
  /// **'Heel hook'**
  String get subHeelHook;

  /// Submission technique: Toe hold
  ///
  /// In en, this message translates to:
  /// **'Toe hold'**
  String get subToeHold;

  /// Outcome sheet: opens free-text entry for a submission not on the list
  ///
  /// In en, this message translates to:
  /// **'Other…'**
  String get outcomeSubmissionOther;

  /// Settings: submissions section title
  ///
  /// In en, this message translates to:
  /// **'Submissions'**
  String get settingsSubmissions;

  /// Settings: submissions section description
  ///
  /// In en, this message translates to:
  /// **'The techniques offered when a match ends by submission'**
  String get settingsSubmissionsDesc;

  /// Settings: match sound toggle title
  ///
  /// In en, this message translates to:
  /// **'Match Sounds'**
  String get settingsMatchSound;

  /// Settings: match sound toggle subtitle when sound is on
  ///
  /// In en, this message translates to:
  /// **'A bell on start, a horn when time runs out'**
  String get settingsMatchSoundOn;

  /// Settings: match sound toggle subtitle when sound is off
  ///
  /// In en, this message translates to:
  /// **'The clock runs silently'**
  String get settingsMatchSoundOff;

  /// Submissions editor: add button
  ///
  /// In en, this message translates to:
  /// **'Add submission'**
  String get submissionsAdd;

  /// Submissions editor: technique name field label
  ///
  /// In en, this message translates to:
  /// **'Technique'**
  String get submissionsName;

  /// Submissions editor: remove a submission from the list
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get submissionsRemove;

  /// Submissions editor: bring back the built-in submissions
  ///
  /// In en, this message translates to:
  /// **'Restore defaults'**
  String get submissionsRestore;

  /// Submissions editor: the technique is already on the list
  ///
  /// In en, this message translates to:
  /// **'Already on the list'**
  String get submissionsDuplicate;

  /// Submissions picker/editor: every submission has been removed
  ///
  /// In en, this message translates to:
  /// **'No submissions left. Add one, or restore the defaults.'**
  String get submissionsEmpty;

  /// Bottom navigation label for the read-only Scoreboard tab
  ///
  /// In en, this message translates to:
  /// **'Scoreboard'**
  String get navScoreboard;

  /// Placeholder in the field where the viewer pastes the organizer pubkey
  ///
  /// In en, this message translates to:
  /// **'Organizer npub or hex pubkey'**
  String get scoreboardPubkeyHint;

  /// Button that starts watching the entered pubkey
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get scoreboardWatch;

  /// Button that stops watching and forgets the pubkey
  ///
  /// In en, this message translates to:
  /// **'Stop watching'**
  String get scoreboardStopWatching;

  /// Error shown when the pasted pubkey is neither an npub nor 64-char hex
  ///
  /// In en, this message translates to:
  /// **'Invalid pubkey: must be an npub or 64-char hex'**
  String get scoreboardInvalidPubkey;

  /// Title before any pubkey has been entered
  ///
  /// In en, this message translates to:
  /// **'Watch somebody else’s mats'**
  String get scoreboardWelcomeTitle;

  /// Body before any pubkey has been entered
  ///
  /// In en, this message translates to:
  /// **'Paste the pubkey an organizer shared and their matches appear here live.'**
  String get scoreboardWelcomeBody;

  /// Title when a pubkey is being watched but no matches have arrived
  ///
  /// In en, this message translates to:
  /// **'No matches yet'**
  String get scoreboardEmptyTitle;

  /// Body when a pubkey is being watched but no matches have arrived
  ///
  /// In en, this message translates to:
  /// **'Waiting for match events from this organizer…'**
  String get scoreboardEmptyBody;

  /// Label over the clock on the full-screen scoreboard
  ///
  /// In en, this message translates to:
  /// **'TIME'**
  String get scoreboardTime;

  /// Label over the winner name on a finished match
  ///
  /// In en, this message translates to:
  /// **'WINNER'**
  String get scoreboardWinner;

  /// Label used instead of WINNER when a match was a draw
  ///
  /// In en, this message translates to:
  /// **'RESULT'**
  String get scoreboardResult;

  /// Short label on the advantages chip; kept short to fit the wall display
  ///
  /// In en, this message translates to:
  /// **'ADV'**
  String get scoreboardAdvShort;

  /// Short label on the penalties chip; kept short to fit the wall display
  ///
  /// In en, this message translates to:
  /// **'PEN'**
  String get scoreboardPenShort;

  /// Point-value column header in the score breakdown, e.g. 2 PTS
  ///
  /// In en, this message translates to:
  /// **'{points} PTS'**
  String scoreboardPointsShort(int points);

  /// Title shown when a shared link named a board but its pubkey could not be read
  ///
  /// In en, this message translates to:
  /// **'That link is broken'**
  String get scoreboardBrokenLinkTitle;

  /// Explanation shown with scoreboardBrokenLinkTitle
  ///
  /// In en, this message translates to:
  /// **'It was meant for a specific board, but the pubkey in it could not be read. Ask whoever shared it to send it again.'**
  String get scoreboardBrokenLinkBody;

  /// Button that dismisses the broken-link state and returns to the board the user was already watching
  ///
  /// In en, this message translates to:
  /// **'Show my board'**
  String get scoreboardBrokenLinkDismiss;

  /// Tooltip and share-sheet subject for sharing a link to the board being watched
  ///
  /// In en, this message translates to:
  /// **'Share this board'**
  String get scoreboardShareBoard;

  /// Message shown before the shared bjjscore.live link when sharing a watched board
  ///
  /// In en, this message translates to:
  /// **'Follow these BJJ matches live on bjjscore.live:'**
  String get scoreboardShareBoardMessage;

  /// Title of the dialog holding a QR code of the watched board's link
  ///
  /// In en, this message translates to:
  /// **'Scan to watch live'**
  String get scoreboardQrTitle;

  /// Caption under the QR code of the watched board's link
  ///
  /// In en, this message translates to:
  /// **'Point a phone camera at this code to open the live board'**
  String get scoreboardQrHint;
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
