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
  String get navAccount => 'Account';

  @override
  String get navSettings => 'Settings';

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
  String get generateNewKey => 'Generate New Key';

  @override
  String get generateNewKeyTitle => 'Generate New Keypair?';

  @override
  String get generateNewKeyWarning =>
      'This will generate a new keypair and replace your current identity. If you have not backed up your current private key, it will be lost permanently. This action cannot be undone.';

  @override
  String get generate => 'Generate';

  @override
  String get keyGeneratedSuccessfully => 'New keypair generated successfully';

  @override
  String get failedToGenerateKey =>
      'Failed to generate new key. Please try again.';

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
  String get shareLiveBoard => 'Share live board';

  @override
  String get shareLiveBoardMessage =>
      'Follow my BJJ matches live on bjjscore.live:';

  @override
  String get shareFailed => 'Couldn\'t open the share sheet';

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
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get statusPaused => 'Paused';

  @override
  String get finish => 'Finish';

  @override
  String get holdHint => 'hold';

  @override
  String get matchFinished => 'Match Finished';

  @override
  String get matchCanceled => 'Match Canceled';

  @override
  String get matchReadOnly => 'View only';

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
  String get website => 'Website';

  @override
  String get sourceCode => 'Source Code';

  @override
  String get sectionLanguage => 'Language';

  @override
  String get language => 'Language';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get languageSaveFailed =>
      'Couldn\'t save the language. Please try again.';

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
  String get systemDefault => 'System';

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
      'Choke\nCopyright (C) 2026 ProtoLayer OÜ\n\nThis program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.\n\nThis program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.\n\nYou should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.';

  @override
  String get licenseLabel => 'License';

  @override
  String get licenseSubtitle => 'GNU GPL v3.0';

  @override
  String get relayErrorLoadFailed => 'Failed to load relay configuration';

  @override
  String get relayErrorAlreadyExists => 'Relay already exists';

  @override
  String get relayErrorInvalidUrl =>
      'Invalid relay URL. Must start with wss://';

  @override
  String get relayErrorUnreachable =>
      'Unable to connect to relay. Please check the URL and try again';

  @override
  String get relayErrorAddFailed => 'Failed to add relay';

  @override
  String get relayErrorRemoveFailed => 'Failed to remove relay';

  @override
  String get relayErrorCannotRemoveLast =>
      'Cannot remove the last active relay';

  @override
  String get relayErrorToggleFailed => 'Failed to update relay';

  @override
  String get relayErrorCannotDisableLast =>
      'At least one relay must remain active';

  @override
  String builtBy(String name) {
    return 'Built by $name';
  }

  @override
  String get bjjBlackBelt => 'BJJ black belt';

  @override
  String get outcomeTitle => 'How did it end?';

  @override
  String get outcomeSubmission => 'Submission';

  @override
  String get outcomePoints => 'Points';

  @override
  String get outcomeAdvantages => 'Advantages';

  @override
  String get outcomeDecision => 'Referee decision';

  @override
  String get outcomeDq => 'Disqualification';

  @override
  String get outcomeForfeit => 'Forfeit';

  @override
  String get outcomeDraw => 'Draw';

  @override
  String get outcomeWhichFighter => 'Which fighter won?';

  @override
  String get outcomeTechnique => 'Technique (optional)';

  @override
  String get outcomeDqCategory => 'Category';

  @override
  String get outcomeDqAccumulated => 'Four penalties';

  @override
  String get outcomeDqTechnical => 'Technical foul';

  @override
  String get outcomeDqDisciplinary => 'Disciplinary foul';

  @override
  String get outcomeDqDetail => 'What happened (optional)';

  @override
  String get outcomeConfirm => 'Confirm';

  @override
  String get outcomeTimeUp => 'Time is up — how did it end?';

  @override
  String outcomeWinsBy(String name) {
    return '$name wins';
  }

  @override
  String get skip => 'Skip';

  @override
  String get outcomeAmend => 'Amend result';

  @override
  String outcomeSubmissionOf(String technique) {
    return 'Submission ($technique)';
  }

  @override
  String get subArmbar => 'Armbar';

  @override
  String get subRearNakedChoke => 'Rear naked choke';

  @override
  String get subTriangle => 'Triangle choke';

  @override
  String get subGuillotine => 'Guillotine';

  @override
  String get subKimura => 'Kimura';

  @override
  String get subAmericana => 'Americana';

  @override
  String get subCrossCollarChoke => 'Cross collar choke';

  @override
  String get subBowAndArrow => 'Bow and arrow choke';

  @override
  String get subEzekiel => 'Ezekiel choke';

  @override
  String get subOmoplata => 'Omoplata';

  @override
  String get subArmTriangle => 'Arm triangle';

  @override
  String get subNorthSouthChoke => 'North–south choke';

  @override
  String get subStraightAnkleLock => 'Straight ankle lock';

  @override
  String get subHeelHook => 'Heel hook';

  @override
  String get subToeHold => 'Toe hold';

  @override
  String get outcomeSubmissionOther => 'Other…';

  @override
  String get settingsSubmissions => 'Submissions';

  @override
  String get settingsSubmissionsDesc =>
      'The techniques offered when a match ends by submission';

  @override
  String get settingsMatchSound => 'Match Sounds';

  @override
  String get settingsMatchSoundOn =>
      'A bell on start, a horn when time runs out';

  @override
  String get settingsMatchSoundOff => 'The clock runs silently';

  @override
  String get submissionsAdd => 'Add submission';

  @override
  String get submissionsName => 'Technique';

  @override
  String get submissionsRemove => 'Remove';

  @override
  String get submissionsRestore => 'Restore defaults';

  @override
  String get submissionsDuplicate => 'Already on the list';

  @override
  String get submissionsEmpty =>
      'No submissions left. Add one, or restore the defaults.';

  @override
  String get navScoreboard => 'Scoreboard';

  @override
  String get scoreboardPubkeyHint => 'Organizer npub or hex pubkey';

  @override
  String get scoreboardWatch => 'Watch';

  @override
  String get scoreboardStopWatching => 'Stop watching';

  @override
  String get scoreboardInvalidPubkey =>
      'Invalid pubkey: must be an npub or 64-char hex';

  @override
  String get scoreboardWelcomeTitle => 'Watch somebody else’s mats';

  @override
  String get scoreboardWelcomeBody =>
      'Paste the pubkey an organizer shared and their matches appear here live.';

  @override
  String get scoreboardEmptyTitle => 'No matches yet';

  @override
  String get scoreboardEmptyBody =>
      'Waiting for match events from this organizer…';

  @override
  String get scoreboardTime => 'TIME';

  @override
  String get scoreboardWinner => 'WINNER';

  @override
  String get scoreboardResult => 'RESULT';

  @override
  String get scoreboardAdvShort => 'ADV';

  @override
  String get scoreboardPenShort => 'PEN';

  @override
  String scoreboardPointsShort(int points) {
    return '$points PTS';
  }
}
