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
  String get navAccount => 'アカウント';

  @override
  String get navSettings => '設定';

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
  String get generateNewKey => '新しい鍵を生成';

  @override
  String get generateNewKeyTitle => '新しい鍵ペアを生成しますか？';

  @override
  String get generateNewKeyWarning =>
      '新しい鍵ペアを生成し、現在のIDを置き換えます。現在の秘密鍵をバックアップしていない場合、完全に失われます。この操作は取り消せません。';

  @override
  String get generate => '生成';

  @override
  String get keyGeneratedSuccessfully => '新しい鍵ペアが正常に生成されました';

  @override
  String get failedToGenerateKey => '新しい鍵の生成に失敗しました。もう一度お試しください。';

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
  String get shareLiveBoard => 'スコアボードを共有';

  @override
  String get shareLiveBoardMessage => 'bjjscore.live で私のBJJの試合をライブでフォロー：';

  @override
  String get shareFailed => '共有メニューを開けませんでした';

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
  String get pause => '一時停止';

  @override
  String get resume => '再開';

  @override
  String get statusPaused => '一時停止中';

  @override
  String get finish => '終了';

  @override
  String get holdHint => '長押し';

  @override
  String get matchFinished => '試合終了';

  @override
  String get matchCanceled => '試合キャンセル';

  @override
  String get matchReadOnly => '閲覧のみ';

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
  String get website => 'ウェブサイト';

  @override
  String get sourceCode => 'ソースコード';

  @override
  String get sectionLanguage => '言語';

  @override
  String get language => '言語';

  @override
  String get selectLanguage => '言語を選択';

  @override
  String get languageSaveFailed => '言語を保存できませんでした。もう一度お試しください。';

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
      'Choke\nCopyright (C) 2026 ProtoLayer OÜ\n\nこのプログラムはフリーソフトウェアです。フリーソフトウェア財団が公表するGNU一般公衆利用許諾書（バージョン3、または任意でそれ以降のバージョン）の条件の下で、再配布および改変することができます。\n\nこのプログラムは有用であることを願って配布されますが、商品性や特定目的への適合性の暗黙的な保証を含め、いかなる保証もありません。詳細はGNU一般公衆利用許諾書をご覧ください。';

  @override
  String get licenseReadFull => '全文をお読みになりますか？ライセンスの全文はこちらです：';

  @override
  String get licenseLabel => 'ライセンス';

  @override
  String get licenseSubtitle => 'GNU GPL v3.0';

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

  @override
  String get bjjBlackBelt => 'BJJの黒帯';

  @override
  String get outcomeTitle => '試合の終わり方は？';

  @override
  String get outcomeSubmission => '一本';

  @override
  String get outcomePoints => 'ポイント';

  @override
  String get outcomeAdvantages => 'アドバンテージ';

  @override
  String get outcomeDecision => '審判判定';

  @override
  String get outcomeDq => '反則失格';

  @override
  String get outcomeForfeit => '棄権';

  @override
  String get outcomeDraw => '引き分け';

  @override
  String get outcomeWhichFighter => '勝者はどちら？';

  @override
  String get outcomeTechnique => '技（任意）';

  @override
  String get outcomeDqCategory => '区分';

  @override
  String get outcomeDqAccumulated => '反則4回';

  @override
  String get outcomeDqTechnical => 'テクニカルファウル';

  @override
  String get outcomeDqDisciplinary => '非スポーツ的行為';

  @override
  String get outcomeDqDetail => '内容（任意）';

  @override
  String get outcomeConfirm => '確定';

  @override
  String get outcomeTimeUp => '時間終了 — 試合の終わり方は？';

  @override
  String outcomeWinsBy(String name) {
    return '$name の勝ち';
  }

  @override
  String get skip => 'スキップ';

  @override
  String get outcomeAmend => '結果を修正';

  @override
  String outcomeSubmissionOf(String technique) {
    return '一本（$technique）';
  }

  @override
  String get subArmbar => '腕十字固め';

  @override
  String get subRearNakedChoke => '裸絞め';

  @override
  String get subTriangle => '三角絞め';

  @override
  String get subGuillotine => 'ギロチンチョーク';

  @override
  String get subKimura => 'キムラロック';

  @override
  String get subAmericana => 'アメリカーナ';

  @override
  String get subCrossCollarChoke => '十字絞め';

  @override
  String get subBowAndArrow => '弓矢絞め';

  @override
  String get subEzekiel => 'エゼキエル絞め';

  @override
  String get subOmoplata => 'オモプラータ';

  @override
  String get subArmTriangle => '肩固め';

  @override
  String get subNorthSouthChoke => 'ノースサウスチョーク';

  @override
  String get subStraightAnkleLock => 'アキレス腱固め';

  @override
  String get subHeelHook => 'ヒールフック';

  @override
  String get subToeHold => 'トーホールド';

  @override
  String get outcomeSubmissionOther => 'その他…';

  @override
  String get settingsSubmissions => 'サブミッション';

  @override
  String get settingsSubmissionsDesc => '一本勝ちで試合が終わったときに表示される技';

  @override
  String get settingsMatchSound => '試合音';

  @override
  String get settingsMatchSoundOn => '開始はゴング、終了はホーン';

  @override
  String get settingsMatchSoundOff => 'タイマーは無音で進みます';

  @override
  String get submissionsAdd => 'サブミッションを追加';

  @override
  String get submissionsName => '技名';

  @override
  String get submissionsRemove => '削除';

  @override
  String get submissionsRestore => '初期設定に戻す';

  @override
  String get submissionsDuplicate => 'すでにリストにあります';

  @override
  String get submissionsEmpty => 'サブミッションがありません。追加するか、初期設定に戻してください。';

  @override
  String get navScoreboard => 'スコアボード';

  @override
  String get scoreboardPubkeyHint => '主催者の npub または 16 進公開鍵';

  @override
  String get scoreboardWatch => '見る';

  @override
  String get scoreboardStopWatching => '表示をやめる';

  @override
  String get scoreboardInvalidPubkey => '無効な公開鍵：npub または 64 文字の 16 進数が必要です';

  @override
  String get scoreboardWelcomeTitle => '他の会場の試合を見る';

  @override
  String get scoreboardWelcomeBody => '主催者が共有した公開鍵を貼ると、その試合がここにリアルタイムで表示されます。';

  @override
  String get scoreboardEmptyTitle => 'まだ試合がありません';

  @override
  String get scoreboardEmptyBody => 'この主催者の試合イベントを待っています…';

  @override
  String get scoreboardTime => 'タイム';

  @override
  String get scoreboardWinner => '勝者';

  @override
  String get scoreboardResult => '結果';

  @override
  String get scoreboardAdvShort => 'アド';

  @override
  String get scoreboardPenShort => '反則';

  @override
  String scoreboardPointsShort(int points) {
    return '$points ポイント';
  }

  @override
  String get boardLiveCredit => 'ライブスコアボード';

  @override
  String get scoreboardBrokenLinkTitle => 'このリンクは壊れています';

  @override
  String get scoreboardBrokenLinkBody =>
      '特定の対象を指していましたが、一部を読み取れませんでした。共有した人にもう一度送ってもらってください。';

  @override
  String get scoreboardBrokenLinkDismiss => '自分のスコアボードを見る';

  @override
  String get scoreboardShareBoard => 'このスコアボードを共有';

  @override
  String get scoreboardShareBoardMessage =>
      'bjjscore.live でこれらの BJJ の試合をライブで観戦:';

  @override
  String get scoreboardShareMatch => 'この試合を共有';

  @override
  String get scoreboardShareMatchMessage => 'bjjscore.live でこの BJJ の試合をライブで観戦:';

  @override
  String get scoreboardQrTitle => 'スキャンしてライブ観戦';

  @override
  String get scoreboardQrHint => 'スマートフォンのカメラをこのコードに向けると、ライブスコアボードが開きます';

  @override
  String get scoreboardMatchPendingTitle => 'その試合を探しています…';

  @override
  String get scoreboardMatchPendingBody => 'リンクはこのスコアボードの試合を指しています。届くのを待っています。';

  @override
  String get scoreboardMatchUnresolvedTitle => 'その試合はこのスコアボードにありません';

  @override
  String get scoreboardMatchUnresolvedBody =>
      'しばらく前に終了した可能性があります。試合のリンクは約1日で切れます。共有した人に新しいリンクをもらってください。';
}
