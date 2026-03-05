// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Choke';

  @override
  String get homeSubtitle => 'Score your BJJ matches';

  @override
  String get navHome => 'Home';

  @override
  String get navMatch => 'Match';

  @override
  String get navAccount => 'Account';

  @override
  String get navSettings => 'Settings';

  @override
  String get matchListPlaceholder => 'Create a match from the Home screen';

  @override
  String get noMatchesYet => 'No matches yet';

  @override
  String get createNewOne => 'Create a new one!';

  @override
  String get statusWaiting => 'Waiting';

  @override
  String get statusInProgress => 'In Progress';

  @override
  String get statusFinished => 'Finished';

  @override
  String get statusCanceled => 'Canceled';

  @override
  String get vs => 'vs';

  @override
  String get accountTitle => 'Account';

  @override
  String get importChangeKey => 'Import/Change Key';

  @override
  String get yourNostrIdentity => 'Your Nostr Identity';

  @override
  String get keypairDescription => 'This keypair identifies you on the network';

  @override
  String get publicKeyNpub => 'Public Key (npub)';

  @override
  String get generating => 'Generating...';

  @override
  String get copy => 'Copy';

  @override
  String get showQr => 'Show QR';

  @override
  String get keyUnavailable => 'Key unavailable';

  @override
  String get errorLoadingKey => 'Error loading key';

  @override
  String get privateKeyNsec => 'Private Key (nsec)';

  @override
  String get neverSharePrivateKey =>
      'Never share your private key with anyone!';

  @override
  String get tapToReveal => 'Tap to reveal • Keep this secret!';

  @override
  String get copyToClipboard => 'Copy to Clipboard';

  @override
  String copiedToClipboard(String label) {
    return '$label copied to clipboard';
  }

  @override
  String get publicKey => 'Public key';

  @override
  String get privateKey => 'Private key';

  @override
  String get importPrivateKey => 'Import Private Key';

  @override
  String get importWarning =>
      'Warning: Importing a new private key will replace your current identity. This action cannot be undone.';

  @override
  String get enterNsec => 'Enter nsec...';

  @override
  String get cancel => 'Cancel';

  @override
  String get import => 'Import';

  @override
  String get pleaseEnterNsec => 'Please enter an nsec';

  @override
  String get invalidNsecFormat =>
      'Invalid nsec format (should start with nsec1)';

  @override
  String get keyImportedSuccessfully => 'Private key imported successfully';

  @override
  String get failedToImportKey =>
      'Failed to import key. Please check the format.';

  @override
  String get yourPublicKey => 'Your Public Key';

  @override
  String get scanQrToShare => 'Scan this QR code to share your public key';

  @override
  String get close => 'Close';

  @override
  String get securityTips => 'Security Tips';

  @override
  String get tipBackupTitle => 'Backup your keys';

  @override
  String get tipBackupDescription =>
      'Write down your nsec and store it in a safe place.';

  @override
  String get tipNeverShareTitle => 'Never share your nsec';

  @override
  String get tipNeverShareDescription =>
      'Anyone with your nsec can impersonate you.';

  @override
  String get tipSecureStorageTitle => 'Secure storage';

  @override
  String get tipSecureStorageDescription =>
      'Keys are stored securely on your device.';

  @override
  String get newMatch => 'New Match';

  @override
  String get fighter1 => 'Fighter 1';

  @override
  String get fighter2 => 'Fighter 2';

  @override
  String get enterFighterName => 'Enter fighter name';

  @override
  String get fighter1NameRequired => 'Fighter 1 name is required';

  @override
  String get fighter2NameRequired => 'Fighter 2 name is required';

  @override
  String get fighter1Color => 'Fighter 1 Color';

  @override
  String get fighter2Color => 'Fighter 2 Color';

  @override
  String get matchDuration => 'Match Duration';

  @override
  String get createMatch => 'Create Match';

  @override
  String get couldNotPublishMatch =>
      'Could not publish match. Check your connection and try again.';

  @override
  String get retry => 'Retry';

  @override
  String matchId(String id) {
    return 'Match #$id';
  }

  @override
  String get canceled => 'CANCELED';

  @override
  String get vsLabel => 'VS';

  @override
  String get takedownSweep => 'Takedown / Sweep';

  @override
  String get guardPass => 'Guard Pass';

  @override
  String get mountBackTake => 'Mount / Back Take';

  @override
  String get advantage => 'Advantage';

  @override
  String get penalty => 'Penalty';

  @override
  String get undoLastAction => 'Undo Last Action';

  @override
  String get startMatch => 'Start Match';

  @override
  String get finish => 'Finish';

  @override
  String get matchFinished => 'Match Finished';

  @override
  String get matchCanceled => 'Match Canceled';

  @override
  String get finishMatchQuestion => 'Finish Match?';

  @override
  String get finishMatchDescription =>
      'This will end the match and publish the final score.';

  @override
  String get cancelMatchQuestion => 'Cancel Match?';

  @override
  String get cancelMatchDescription =>
      'This will cancel the match. Scores will not be saved.';

  @override
  String get goBack => 'Go Back';

  @override
  String get cancelMatch => 'Cancel Match';

  @override
  String get leaveMatchQuestion => 'Leave Match?';

  @override
  String get leaveMatchDescription =>
      'The match is still in progress. Are you sure you want to leave?';

  @override
  String get stay => 'Stay';

  @override
  String get leave => 'Leave';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get sectionAppearance => 'Appearance';

  @override
  String get sectionNostr => 'Nostr';

  @override
  String get relays => 'Relays';

  @override
  String get manageRelayConnections => 'Manage relay connections';

  @override
  String get sectionMatch => 'Match';

  @override
  String get defaultMatchDuration => 'Default Match Duration';

  @override
  String get fiveMinutes => '5 minutes';

  @override
  String get sectionAbout => 'About';

  @override
  String get version => 'Version';

  @override
  String get sourceCode => 'Source Code';

  @override
  String get sectionLanguage => 'Language';

  @override
  String get language => 'Language';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get relayManagement => 'Relay Management';

  @override
  String get refresh => 'Refresh';

  @override
  String get addCustomRelay => 'Add Custom Relay';

  @override
  String get relayHint => 'wss://relay.example.com';

  @override
  String get pleaseEnterRelayUrl => 'Please enter a relay URL';

  @override
  String get relayUrlMustStartWithWss => 'URL must start with wss:// or ws://';

  @override
  String get adding => 'Adding...';

  @override
  String get add => 'Add';

  @override
  String get noRelaysConfigured => 'No relays configured';

  @override
  String get addRelayToStart => 'Add a relay to start publishing events';

  @override
  String get relayStatusDisabled => 'Disabled';

  @override
  String get relayStatusConnectedDefault => 'Connected • Default';

  @override
  String get relayStatusConnectingDefault => 'Connecting • Default';

  @override
  String get relayStatusConnected => 'Connected';

  @override
  String get relayStatusConnecting => 'Connecting';

  @override
  String get removeRelayQuestion => 'Remove Relay?';

  @override
  String removeRelayConfirmation(String url) {
    return 'Are you sure you want to remove $url?';
  }

  @override
  String get remove => 'Remove';

  @override
  String get relayAddedSuccessfully => 'Relay added successfully';

  @override
  String get relayRemoved => 'Relay removed';

  @override
  String get systemDefault => 'System default';

  @override
  String get themeMode => 'Theme';

  @override
  String get dark => 'Dark';

  @override
  String get light => 'Light';

  @override
  String get followSystemTheme => 'Follow system setting';

  @override
  String get licenseTitle => 'License';

  @override
  String get licenseText =>
      'MIT License\n\nCopyright (c) 2026 Negrunch\n\nPermission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the \"Software\"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:\n\nThe above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.\n\nTHE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.';

  @override
  String get licenseLabel => 'License';

  @override
  String get licenseSubtitle => 'MIT License';
}
