// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Choke';

  @override
  String get homeSubtitle => 'Pontue suas lutas de BJJ';

  @override
  String get navHome => 'Início';

  @override
  String get navMatch => 'Luta';

  @override
  String get navAccount => 'Conta';

  @override
  String get navSettings => 'Configurações';

  @override
  String get matchListPlaceholder => 'Crie uma luta na tela inicial';

  @override
  String get noMatchesYet => 'Nenhuma luta ainda';

  @override
  String get createNewOne => 'Crie uma nova!';

  @override
  String get statusWaiting => 'Aguardando';

  @override
  String get statusInProgress => 'Em andamento';

  @override
  String get statusFinished => 'Finalizada';

  @override
  String get statusCanceled => 'Cancelada';

  @override
  String get vs => 'vs';

  @override
  String get accountTitle => 'Conta';

  @override
  String get importChangeKey => 'Importar/Alterar chave';

  @override
  String get yourNostrIdentity => 'Sua identidade Nostr';

  @override
  String get keypairDescription => 'Este par de chaves identifica você na rede';

  @override
  String get publicKeyNpub => 'Chave pública (npub)';

  @override
  String get generating => 'Gerando...';

  @override
  String get copy => 'Copiar';

  @override
  String get showQr => 'Mostrar QR';

  @override
  String get keyUnavailable => 'Chave indisponível';

  @override
  String get errorLoadingKey => 'Erro ao carregar chave';

  @override
  String get privateKeyNsec => 'Chave privada (nsec)';

  @override
  String get neverSharePrivateKey =>
      'Nunca compartilhe sua chave privada com ninguém!';

  @override
  String get tapToReveal => 'Toque para revelar • Mantenha em segredo!';

  @override
  String get copyToClipboard => 'Copiar para a área de transferência';

  @override
  String copiedToClipboard(String label) {
    return '$label copiado para a área de transferência';
  }

  @override
  String get publicKey => 'Chave pública';

  @override
  String get privateKey => 'Chave privada';

  @override
  String get importPrivateKey => 'Importar chave privada';

  @override
  String get importWarning =>
      'Atenção: Importar uma nova chave privada substituirá sua identidade atual. Essa ação não pode ser desfeita.';

  @override
  String get enterNsec => 'Digite o nsec...';

  @override
  String get cancel => 'Cancelar';

  @override
  String get import => 'Importar';

  @override
  String get pleaseEnterNsec => 'Por favor, digite um nsec';

  @override
  String get invalidNsecFormat =>
      'Formato de nsec inválido (deve começar com nsec1)';

  @override
  String get keyImportedSuccessfully => 'Chave privada importada com sucesso';

  @override
  String get failedToImportKey =>
      'Falha ao importar a chave. Por favor, verifique o formato.';

  @override
  String get yourPublicKey => 'Sua chave pública';

  @override
  String get scanQrToShare =>
      'Escaneie este código QR para compartilhar sua chave pública';

  @override
  String get close => 'Fechar';

  @override
  String get securityTips => 'Dicas de segurança';

  @override
  String get tipBackupTitle => 'Faça backup das suas chaves';

  @override
  String get tipBackupDescription =>
      'Anote seu nsec e guarde em um lugar seguro.';

  @override
  String get tipNeverShareTitle => 'Nunca compartilhe seu nsec';

  @override
  String get tipNeverShareDescription =>
      'Qualquer pessoa com seu nsec pode se passar por você.';

  @override
  String get tipSecureStorageTitle => 'Armazenamento seguro';

  @override
  String get tipSecureStorageDescription =>
      'As chaves são armazenadas com segurança no seu dispositivo.';

  @override
  String get newMatch => 'Nova luta';

  @override
  String get fighter1 => 'Lutador 1';

  @override
  String get fighter2 => 'Lutador 2';

  @override
  String get enterFighterName => 'Digite o nome do lutador';

  @override
  String get fighter1NameRequired => 'O nome do lutador 1 é obrigatório';

  @override
  String get fighter2NameRequired => 'O nome do lutador 2 é obrigatório';

  @override
  String get fighter1Color => 'Cor do lutador 1';

  @override
  String get fighter2Color => 'Cor do lutador 2';

  @override
  String get matchDuration => 'Duração da luta';

  @override
  String get createMatch => 'Criar luta';

  @override
  String get couldNotPublishMatch =>
      'Não foi possível publicar a luta. Verifique sua conexão e tente novamente.';

  @override
  String get retry => 'Tentar novamente';

  @override
  String matchId(String id) {
    return 'Luta #$id';
  }

  @override
  String get canceled => 'CANCELADA';

  @override
  String get vsLabel => 'VS';

  @override
  String get takedownSweep => 'Queda / Raspagem';

  @override
  String get guardPass => 'Passagem de guarda';

  @override
  String get mountBackTake => 'Montada / Pegada de costas';

  @override
  String get advantage => 'Vantagem';

  @override
  String get penalty => 'Penalidade';

  @override
  String get undoLastAction => 'Desfazer última ação';

  @override
  String get startMatch => 'Iniciar luta';

  @override
  String get finish => 'Finalizar';

  @override
  String get matchFinished => 'Luta finalizada';

  @override
  String get matchCanceled => 'Luta cancelada';

  @override
  String get finishMatchQuestion => 'Finalizar luta?';

  @override
  String get finishMatchDescription =>
      'Isso encerrará a luta e publicará a pontuação final.';

  @override
  String get cancelMatchQuestion => 'Cancelar luta?';

  @override
  String get cancelMatchDescription =>
      'Isso cancelará a luta. As pontuações não serão salvas.';

  @override
  String get goBack => 'Voltar';

  @override
  String get cancelMatch => 'Cancelar luta';

  @override
  String get leaveMatchQuestion => 'Sair da luta?';

  @override
  String get leaveMatchDescription =>
      'A luta ainda está em andamento. Tem certeza de que deseja sair?';

  @override
  String get stay => 'Ficar';

  @override
  String get leave => 'Sair';

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get sectionAppearance => 'Aparência';

  @override
  String get sectionNostr => 'Nostr';

  @override
  String get relays => 'Relays';

  @override
  String get manageRelayConnections => 'Gerenciar conexões de relays';

  @override
  String get sectionMatch => 'Luta';

  @override
  String get defaultMatchDuration => 'Duração padrão da luta';

  @override
  String get fiveMinutes => '5 minutos';

  @override
  String get sectionAbout => 'Sobre';

  @override
  String get version => 'Versão';

  @override
  String get sourceCode => 'Código-fonte';

  @override
  String get sectionLanguage => 'Idioma';

  @override
  String get language => 'Idioma';

  @override
  String get selectLanguage => 'Selecionar idioma';

  @override
  String get relayManagement => 'Gerenciamento de relays';

  @override
  String get refresh => 'Atualizar';

  @override
  String get addCustomRelay => 'Adicionar relay personalizado';

  @override
  String get relayHint => 'wss://relay.exemplo.com';

  @override
  String get pleaseEnterRelayUrl => 'Por favor, digite uma URL de relay';

  @override
  String get relayUrlMustStartWithWss =>
      'A URL deve começar com wss:// ou ws://';

  @override
  String get adding => 'Adicionando...';

  @override
  String get add => 'Adicionar';

  @override
  String get noRelaysConfigured => 'Nenhum relay configurado';

  @override
  String get addRelayToStart =>
      'Adicione um relay para começar a publicar eventos';

  @override
  String get relayStatusDisabled => 'Desativado';

  @override
  String get relayStatusConnectedDefault => 'Conectado • Padrão';

  @override
  String get relayStatusConnectingDefault => 'Conectando • Padrão';

  @override
  String get relayStatusConnected => 'Conectado';

  @override
  String get relayStatusConnecting => 'Conectando';

  @override
  String get removeRelayQuestion => 'Remover relay?';

  @override
  String removeRelayConfirmation(String url) {
    return 'Tem certeza de que deseja remover $url?';
  }

  @override
  String get remove => 'Remover';

  @override
  String get relayAddedSuccessfully => 'Relay adicionado com sucesso';

  @override
  String get relayRemoved => 'Relay removido';

  @override
  String get systemDefault => 'Padrão do sistema';

  @override
  String get themeMode => 'Tema';

  @override
  String get dark => 'Escuro';

  @override
  String get light => 'Claro';

  @override
  String get followSystemTheme => 'Seguir configuração do sistema';
}
