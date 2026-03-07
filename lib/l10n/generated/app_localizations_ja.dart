// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Choke';

  @override
  String get homeSubtitle => 'BJJの試合をスコアリング';

  @override
  String get navHome => 'ホーム';

  @override
  String get navMatch => '試合';

  @override
  String get navAccount => 'アカウント';

  @override
  String get navSettings => '設定';

  @override
  String get matchListPlaceholder => 'ホーム画面から試合を作成してください';

  @override
  String get noMatchesYet => 'まだ試合がありません';

  @override
  String get createNewOne => '新しい試合を作成しましょう！';

  @override
  String get statusWaiting => '待機中';

  @override
  String get statusInProgress => '進行中';

  @override
  String get statusFinished => '終了';

  @override
  String get statusCanceled => 'キャンセル';

  @override
  String get vs => 'vs';

  @override
  String get accountTitle => 'アカウント';

  @override
  String get importChangeKey => '鍵のインポート/変更';

  @override
  String get yourNostrIdentity => 'あなたのNostr ID';

  @override
  String get keypairDescription => 'この鍵ペアがネットワーク上であなたを識別します';

  @override
  String get publicKeyNpub => '公開鍵（npub）';

  @override
  String get generating => '生成中...';

  @override
  String get copy => 'コピー';

  @override
  String get showQr => 'QR表示';

  @override
  String get keyUnavailable => '鍵が利用できません';

  @override
  String get errorLoadingKey => '鍵の読み込みエラー';

  @override
  String get privateKeyNsec => '秘密鍵（nsec）';

  @override
  String get neverSharePrivateKey => '秘密鍵を誰にも共有しないでください！';

  @override
  String get tapToReveal => 'タップして表示 • 秘密にしてください！';

  @override
  String get copyToClipboard => 'クリップボードにコピー';

  @override
  String copiedToClipboard(String label) {
    return '$labelをクリップボードにコピーしました';
  }

  @override
  String get publicKey => '公開鍵';

  @override
  String get privateKey => '秘密鍵';

  @override
  String get importPrivateKey => '秘密鍵をインポート';

  @override
  String get importWarning => '警告：新しい秘密鍵をインポートすると、現在のIDが置き換えられます。この操作は取り消せません。';

  @override
  String get enterNsec => 'nsecを入力...';

  @override
  String get cancel => 'キャンセル';

  @override
  String get import => 'インポート';

  @override
  String get pleaseEnterNsec => 'nsecを入力してください';

  @override
  String get invalidNsecFormat => 'nsecの形式が無効です（nsec1で始まる必要があります）';

  @override
  String get keyImportedSuccessfully => '秘密鍵が正常にインポートされました';

  @override
  String get failedToImportKey => '鍵のインポートに失敗しました。形式を確認してください。';

  @override
  String get yourPublicKey => 'あなたの公開鍵';

  @override
  String get scanQrToShare => 'このQRコードをスキャンして公開鍵を共有できます';

  @override
  String get close => '閉じる';

  @override
  String get securityTips => 'セキュリティのヒント';

  @override
  String get tipBackupTitle => '鍵をバックアップ';

  @override
  String get tipBackupDescription => 'nsecを書き留めて安全な場所に保管してください。';

  @override
  String get tipNeverShareTitle => 'nsecを共有しない';

  @override
  String get tipNeverShareDescription => 'nsecを持つ人は誰でもあなたになりすますことができます。';

  @override
  String get tipSecureStorageTitle => '安全なストレージ';

  @override
  String get tipSecureStorageDescription => '鍵はデバイスに安全に保存されています。';

  @override
  String get newMatch => '新しい試合';

  @override
  String get fighter1 => '選手1';

  @override
  String get fighter2 => '選手2';

  @override
  String get enterFighterName => '選手名を入力';

  @override
  String get fighter1NameRequired => '選手1の名前は必須です';

  @override
  String get fighter2NameRequired => '選手2の名前は必須です';

  @override
  String get fighter1Color => '選手1の色';

  @override
  String get fighter2Color => '選手2の色';

  @override
  String get matchDuration => '試合時間';

  @override
  String get createMatch => '試合を作成';

  @override
  String get couldNotPublishMatch => '試合を公開できませんでした。接続を確認して再試行してください。';

  @override
  String get retry => '再試行';

  @override
  String matchId(String id) {
    return '試合 #$id';
  }

  @override
  String get canceled => 'キャンセル済み';

  @override
  String get vsLabel => 'VS';

  @override
  String get takedownSweep => 'テイクダウン / スイープ';

  @override
  String get guardPass => 'ガードパス';

  @override
  String get mountBackTake => 'マウント / バックテイク';

  @override
  String get advantage => 'アドバンテージ';

  @override
  String get penalty => 'ペナルティ';

  @override
  String get undoLastAction => '最後の操作を元に戻す';

  @override
  String get startMatch => '試合開始';

  @override
  String get finish => '終了';

  @override
  String get matchFinished => '試合終了';

  @override
  String get matchCanceled => '試合キャンセル';

  @override
  String get finishMatchQuestion => '試合を終了しますか？';

  @override
  String get finishMatchDescription => '試合が終了し、最終スコアが公開されます。';

  @override
  String get cancelMatchQuestion => '試合をキャンセルしますか？';

  @override
  String get cancelMatchDescription => '試合がキャンセルされます。スコアは保存されません。';

  @override
  String get goBack => '戻る';

  @override
  String get cancelMatch => '試合をキャンセル';

  @override
  String get leaveMatchQuestion => '試合から離れますか？';

  @override
  String get leaveMatchDescription => '試合はまだ進行中です。本当に離れますか？';

  @override
  String get stay => '残る';

  @override
  String get leave => '離れる';

  @override
  String get settingsTitle => '設定';

  @override
  String get sectionAppearance => '外観';

  @override
  String get sectionNostr => 'Nostr';

  @override
  String get relays => 'リレー';

  @override
  String get manageRelayConnections => 'リレー接続を管理';

  @override
  String get sectionMatch => '試合';

  @override
  String get defaultMatchDuration => 'デフォルトの試合時間';

  @override
  String get fiveMinutes => '5分';

  @override
  String get sectionAbout => 'アプリについて';

  @override
  String get version => 'バージョン';

  @override
  String get sourceCode => 'ソースコード';

  @override
  String get sectionLanguage => '言語';

  @override
  String get language => '言語';

  @override
  String get selectLanguage => '言語を選択';

  @override
  String get relayManagement => 'リレー管理';

  @override
  String get refresh => '更新';

  @override
  String get addCustomRelay => 'カスタムリレーを追加';

  @override
  String get relayHint => 'wss://relay.example.com';

  @override
  String get pleaseEnterRelayUrl => 'リレーURLを入力してください';

  @override
  String get relayUrlMustStartWithWss => 'URLはwss://またはws://で始まる必要があります';

  @override
  String get adding => '追加中...';

  @override
  String get add => '追加';

  @override
  String get noRelaysConfigured => 'リレーが設定されていません';

  @override
  String get addRelayToStart => 'イベントの公開を開始するにはリレーを追加してください';

  @override
  String get relayStatusDisabled => '無効';

  @override
  String get relayStatusConnectedDefault => '接続済み • デフォルト';

  @override
  String get relayStatusConnectingDefault => '接続中 • デフォルト';

  @override
  String get relayStatusConnected => '接続済み';

  @override
  String get relayStatusConnecting => '接続中';

  @override
  String get removeRelayQuestion => 'リレーを削除しますか？';

  @override
  String removeRelayConfirmation(String url) {
    return '$urlを削除してもよろしいですか？';
  }

  @override
  String get remove => '削除';

  @override
  String get relayAddedSuccessfully => 'リレーが正常に追加されました';

  @override
  String get relayRemoved => 'リレーが削除されました';

  @override
  String get systemDefault => 'システム';

  @override
  String get themeMode => 'テーマ';

  @override
  String get dark => 'ダーク';

  @override
  String get light => 'ライト';

  @override
  String get followSystemTheme => 'システム設定に従う';

  @override
  String get licenseTitle => 'ライセンス';

  @override
  String get licenseText =>
      'MIT ライセンス\n\nCopyright (c) 2026 Negrunch\n\n本ソフトウェアと関連ドキュメントファイル（以下「ソフトウェア」）のコピーを取得した者は、以下に示す条件に従い、ソフトウェアを自由に使用、複製、変更、統合、公開、配布、サブライセンスし、またはコピーを販売する権利を無償で付与されます。\n\n上記の著作権表示および本免責条項は、ソフトウェアのすべてのコピーまたは重要な部分に含まれるものとします。\n\nソフトウェアは「現状のまま」提供され、商品性、特定目的への適合性、および非侵害に関する明示的または黙示的な保証は一切ありません。いかなる場合においても、著作者または著作権者は、契約、不法行為、その他の理由から、ソフトウェアの使用その他の取引に起因または関連して発生した請求、損害またはその他の責任を負わないものとします。';

  @override
  String get licenseLabel => 'ライセンス';

  @override
  String get licenseSubtitle => 'MIT ライセンス';

  @override
  String get relayErrorLoadFailed => 'リレー設定の読み込みに失敗しました';

  @override
  String get relayErrorAlreadyExists => 'リレーは既に存在します';

  @override
  String get relayErrorInvalidUrl => '無効なリレーURL。wss://で始まる必要があります';

  @override
  String get relayErrorUnreachable => 'リレーに接続できません。URLを確認して再試行してください';

  @override
  String get relayErrorAddFailed => 'リレーの追加に失敗しました';

  @override
  String get relayErrorRemoveFailed => 'リレーの削除に失敗しました';

  @override
  String get relayErrorCannotRemoveLast => '最後のアクティブなリレーは削除できません';

  @override
  String get relayErrorToggleFailed => 'リレーの更新に失敗しました';

  @override
  String get relayErrorCannotDisableLast => '少なくとも1つのリレーをアクティブにする必要があります';

  @override
  String builtBy(String name) {
    return '$name が開発';
  }
}
