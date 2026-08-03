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
  String get navAccount => 'Conta';

  @override
  String get navSettings => 'Configurações';

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
  String get generateNewKey => 'Gerar nova chave';

  @override
  String get generateNewKeyTitle => 'Gerar novo par de chaves?';

  @override
  String get generateNewKeyWarning =>
      'Isso gerará um novo par de chaves e substituirá sua identidade atual. Se você não fez backup da sua chave privada atual, ela será perdida permanentemente. Esta ação não pode ser desfeita.';

  @override
  String get generate => 'Gerar';

  @override
  String get keyGeneratedSuccessfully =>
      'Novo par de chaves gerado com sucesso';

  @override
  String get failedToGenerateKey =>
      'Falha ao gerar a nova chave. Por favor, tente novamente.';

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
  String get shareLiveBoard => 'Compartilhar placar';

  @override
  String get shareLiveBoardMessage =>
      'Acompanhe minhas lutas de BJJ ao vivo no bjjscore.live:';

  @override
  String get shareFailed => 'Não foi possível abrir o menu de compartilhamento';

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
  String get pause => 'Pausar';

  @override
  String get resume => 'Retomar';

  @override
  String get statusPaused => 'Em pausa';

  @override
  String get finish => 'Finalizar';

  @override
  String get holdHint => 'segurar';

  @override
  String get matchFinished => 'Luta finalizada';

  @override
  String get matchCanceled => 'Luta cancelada';

  @override
  String get matchReadOnly => 'Somente leitura';

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
  String get website => 'Site';

  @override
  String get sourceCode => 'Código-fonte';

  @override
  String get sectionLanguage => 'Idioma';

  @override
  String get language => 'Idioma';

  @override
  String get selectLanguage => 'Selecionar idioma';

  @override
  String get languageSaveFailed =>
      'Não foi possível salvar o idioma. Tente novamente.';

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
  String get systemDefault => 'Sistema';

  @override
  String get themeMode => 'Tema';

  @override
  String get dark => 'Escuro';

  @override
  String get light => 'Claro';

  @override
  String get followSystemTheme => 'Seguir configuração do sistema';

  @override
  String get licenseTitle => 'Licença';

  @override
  String get licenseText =>
      'Choke\nCopyright (C) 2026 ProtoLayer OÜ\n\nEste programa é software livre: você pode redistribuí-lo e/ou modificá-lo sob os termos da Licença Pública Geral GNU, conforme publicada pela Free Software Foundation, seja a versão 3 da Licença ou (a seu critério) qualquer versão posterior.\n\nEste programa é distribuído na esperança de que seja útil, mas SEM NENHUMA GARANTIA; sem mesmo a garantia implícita de COMERCIALIZAÇÃO ou ADEQUAÇÃO A UM PROPÓSITO ESPECÍFICO. Consulte a Licença Pública Geral GNU para mais detalhes.';

  @override
  String get licenseReadFull =>
      'Quer ler na íntegra? O texto completo da licença está aqui:';

  @override
  String get licenseLabel => 'Licença';

  @override
  String get licenseSubtitle => 'GNU GPL v3.0';

  @override
  String get relayErrorLoadFailed =>
      'Falha ao carregar a configuração de relays';

  @override
  String get relayErrorAlreadyExists => 'O relay já existe';

  @override
  String get relayErrorInvalidUrl =>
      'URL de relay inválida. Deve começar com wss://';

  @override
  String get relayErrorUnreachable =>
      'Não foi possível conectar ao relay. Verifique a URL e tente novamente';

  @override
  String get relayErrorAddFailed => 'Falha ao adicionar o relay';

  @override
  String get relayErrorRemoveFailed => 'Falha ao remover o relay';

  @override
  String get relayErrorCannotRemoveLast =>
      'Não é possível remover o último relay ativo';

  @override
  String get relayErrorToggleFailed => 'Falha ao atualizar o relay';

  @override
  String get relayErrorCannotDisableLast =>
      'Pelo menos um relay deve permanecer ativo';

  @override
  String builtBy(String name) {
    return 'Feito por $name';
  }

  @override
  String get bjjBlackBelt => 'Faixa preta de BJJ';

  @override
  String get outcomeTitle => 'Como terminou?';

  @override
  String get outcomeSubmission => 'Finalização';

  @override
  String get outcomePoints => 'Pontos';

  @override
  String get outcomeAdvantages => 'Vantagens';

  @override
  String get outcomeDecision => 'Decisão dos árbitros';

  @override
  String get outcomeDq => 'Desclassificação';

  @override
  String get outcomeForfeit => 'Desistência';

  @override
  String get outcomeDraw => 'Empate';

  @override
  String get outcomeWhichFighter => 'Qual lutador venceu?';

  @override
  String get outcomeTechnique => 'Técnica (opcional)';

  @override
  String get outcomeDqCategory => 'Categoria';

  @override
  String get outcomeDqAccumulated => 'Quatro punições';

  @override
  String get outcomeDqTechnical => 'Falta técnica';

  @override
  String get outcomeDqDisciplinary => 'Falta disciplinar';

  @override
  String get outcomeDqDetail => 'O que aconteceu (opcional)';

  @override
  String get outcomeConfirm => 'Confirmar';

  @override
  String get outcomeTimeUp => 'Tempo esgotado — como terminou?';

  @override
  String outcomeWinsBy(String name) {
    return '$name vence';
  }

  @override
  String get skip => 'Pular';

  @override
  String get outcomeAmend => 'Corrigir resultado';

  @override
  String outcomeSubmissionOf(String technique) {
    return 'Finalização ($technique)';
  }

  @override
  String get subArmbar => 'Chave de braço';

  @override
  String get subRearNakedChoke => 'Mata-leão';

  @override
  String get subTriangle => 'Triângulo';

  @override
  String get subGuillotine => 'Guilhotina';

  @override
  String get subKimura => 'Kimura';

  @override
  String get subAmericana => 'Americana';

  @override
  String get subCrossCollarChoke => 'Estrangulamento cruzado';

  @override
  String get subBowAndArrow => 'Arco e flecha';

  @override
  String get subEzekiel => 'Ezequiel';

  @override
  String get subOmoplata => 'Omoplata';

  @override
  String get subArmTriangle => 'Triângulo de braço';

  @override
  String get subNorthSouthChoke => 'Estrangulamento norte-sul';

  @override
  String get subStraightAnkleLock => 'Chave de pé reta';

  @override
  String get subHeelHook => 'Heel hook';

  @override
  String get subToeHold => 'Toe hold';

  @override
  String get outcomeSubmissionOther => 'Outra…';

  @override
  String get settingsSubmissions => 'Finalizações';

  @override
  String get settingsSubmissionsDesc =>
      'As técnicas oferecidas quando uma luta termina por finalização';

  @override
  String get settingsMatchSound => 'Sons da luta';

  @override
  String get settingsMatchSoundOn =>
      'Sino ao começar, buzina quando o tempo acaba';

  @override
  String get settingsMatchSoundOff => 'O relógio corre em silêncio';

  @override
  String get settingsAnnouncements => 'Anúncios';

  @override
  String get settingsAnnouncementsOn =>
      'Novidades ocasionais do projeto: versões, quedas, eventos';

  @override
  String get settingsAnnouncementsOff =>
      'O app não pede nada e não recebe nada';

  @override
  String get submissionsAdd => 'Adicionar finalização';

  @override
  String get submissionsName => 'Técnica';

  @override
  String get submissionsRemove => 'Remover';

  @override
  String get submissionsRestore => 'Restaurar as padrão';

  @override
  String get submissionsDuplicate => 'Já está na lista';

  @override
  String get submissionsEmpty =>
      'Não resta nenhuma finalização. Adicione uma ou restaure as padrão.';

  @override
  String get navScoreboard => 'Placar';

  @override
  String get scoreboardPubkeyHint => 'npub do organizador';

  @override
  String get scoreboardWatch => 'Ver';

  @override
  String get scoreboardStopWatching => 'Parar de ver';

  @override
  String get scoreboardInvalidPubkey => 'Essa chave pública não é válida';

  @override
  String get scoreboardWelcomeTitle => 'Acompanhe os tatames de outros';

  @override
  String get scoreboardWelcomeBody =>
      'Cole a chave pública que um organizador compartilhou e as lutas dele aparecem aqui ao vivo.';

  @override
  String get scoreboardEmptyTitle => 'Ainda sem lutas';

  @override
  String get scoreboardEmptyBody =>
      'Aguardando eventos de luta deste organizador…';

  @override
  String get scoreboardTime => 'TEMPO';

  @override
  String get scoreboardWinner => 'VENCEDOR';

  @override
  String get scoreboardResult => 'RESULTADO';

  @override
  String get scoreboardAdvShort => 'VANT';

  @override
  String get scoreboardPenShort => 'PUN';

  @override
  String scoreboardPointsShort(int points) {
    return '$points PTS';
  }

  @override
  String get boardLiveCredit => 'Placar ao vivo';

  @override
  String get scoreboardBrokenLinkTitle => 'Esse link está quebrado';

  @override
  String get scoreboardBrokenLinkBody =>
      'Ele apontava para algo específico, mas não foi possível ler uma parte. Peça para quem compartilhou enviar de novo.';

  @override
  String get scoreboardBrokenLinkDismiss => 'Ver meu placar';

  @override
  String get scoreboardShareBoard => 'Compartilhar este placar';

  @override
  String get scoreboardShareBoardMessage =>
      'Acompanhe estas lutas de BJJ ao vivo em bjjscore.live:';

  @override
  String get scoreboardShareMatch => 'Compartilhar esta luta';

  @override
  String get scoreboardShareMatchMessage =>
      'Assista a esta luta de BJJ ao vivo em bjjscore.live:';

  @override
  String get scoreboardQrTitle => 'Escaneie para ver ao vivo';

  @override
  String get scoreboardQrHint =>
      'Aponte a câmera do celular para este código para abrir o placar ao vivo';

  @override
  String get scoreboardMatchPendingTitle => 'Procurando essa luta…';

  @override
  String get scoreboardMatchPendingBody =>
      'O link apontava para uma luta deste placar. Aguardando ela chegar.';

  @override
  String get scoreboardMatchUnresolvedTitle =>
      'Essa luta não está neste placar';

  @override
  String get scoreboardMatchUnresolvedBody =>
      'Ela pode ter terminado faz um tempo — um link de luta dura cerca de um dia. Peça um novo para quem compartilhou.';
}
