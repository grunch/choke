// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Choke';

  @override
  String get homeSubtitle => 'Puntúa tus luchas de BJJ';

  @override
  String get navHome => 'Inicio';

  @override
  String get navAccount => 'Cuenta';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get noMatchesYet => 'Aún no hay luchas';

  @override
  String get createNewOne => '¡Crea una nueva!';

  @override
  String get statusWaiting => 'Esperando';

  @override
  String get statusInProgress => 'En curso';

  @override
  String get statusFinished => 'Finalizado';

  @override
  String get statusCanceled => 'Cancelado';

  @override
  String get vs => 'vs';

  @override
  String get accountTitle => 'Cuenta';

  @override
  String get importChangeKey => 'Importar/Cambiar clave';

  @override
  String get generateNewKey => 'Generar nueva clave';

  @override
  String get generateNewKeyTitle => '¿Generar nuevo par de claves?';

  @override
  String get generateNewKeyWarning =>
      'Esto generará un nuevo par de claves y reemplazará tu identidad actual. Si no has respaldado tu clave privada actual, la perderás de forma permanente. Esta acción no se puede deshacer.';

  @override
  String get generate => 'Generar';

  @override
  String get keyGeneratedSuccessfully =>
      'Nuevo par de claves generado correctamente';

  @override
  String get failedToGenerateKey =>
      'Error al generar la nueva clave. Por favor intenta de nuevo.';

  @override
  String get yourNostrIdentity => 'Tu identidad Nostr';

  @override
  String get keypairDescription => 'Este par de claves te identifica en la red';

  @override
  String get publicKeyNpub => 'Clave pública (npub)';

  @override
  String get generating => 'Generando...';

  @override
  String get copy => 'Copiar';

  @override
  String get showQr => 'Mostrar QR';

  @override
  String get shareLiveBoard => 'Compartir marcador';

  @override
  String get shareLiveBoardMessage =>
      'Sigue mis combates de BJJ en vivo en bjjscore.live:';

  @override
  String get shareFailed => 'No se pudo abrir el menú de compartir';

  @override
  String get keyUnavailable => 'Clave no disponible';

  @override
  String get errorLoadingKey => 'Error al cargar la clave';

  @override
  String get privateKeyNsec => 'Clave privada (nsec)';

  @override
  String get neverSharePrivateKey =>
      '¡Nunca compartas tu clave privada con nadie!';

  @override
  String get tapToReveal => 'Toca para revelar • ¡Mantenlo en secreto!';

  @override
  String get copyToClipboard => 'Copiar al portapapeles';

  @override
  String copiedToClipboard(String label) {
    return '$label copiado al portapapeles';
  }

  @override
  String get publicKey => 'Clave pública';

  @override
  String get privateKey => 'Clave privada';

  @override
  String get importPrivateKey => 'Importar clave privada';

  @override
  String get importWarning =>
      'Advertencia: Importar una nueva clave privada reemplazará tu identidad actual. Esta acción no se puede deshacer.';

  @override
  String get enterNsec => 'Ingresa el nsec...';

  @override
  String get cancel => 'Cancelar';

  @override
  String get import => 'Importar';

  @override
  String get pleaseEnterNsec => 'Por favor ingresa un nsec';

  @override
  String get invalidNsecFormat =>
      'Formato de nsec inválido (debe comenzar con nsec1)';

  @override
  String get keyImportedSuccessfully => 'Clave privada importada correctamente';

  @override
  String get failedToImportKey =>
      'Error al importar la clave. Por favor verifica el formato.';

  @override
  String get yourPublicKey => 'Tu clave pública';

  @override
  String get scanQrToShare =>
      'Escanea este código QR para compartir tu clave pública';

  @override
  String get close => 'Cerrar';

  @override
  String get securityTips => 'Consejos de seguridad';

  @override
  String get tipBackupTitle => 'Respalda tus claves';

  @override
  String get tipBackupDescription =>
      'Escribe tu nsec y guárdalo en un lugar seguro.';

  @override
  String get tipNeverShareTitle => 'Nunca compartas tu nsec';

  @override
  String get tipNeverShareDescription =>
      'Cualquiera con tu nsec puede hacerse pasar por ti.';

  @override
  String get tipSecureStorageTitle => 'Almacenamiento seguro';

  @override
  String get tipSecureStorageDescription =>
      'Las claves se almacenan de forma segura en tu dispositivo.';

  @override
  String get newMatch => 'Nueva lucha';

  @override
  String get fighter1 => 'Luchador 1';

  @override
  String get fighter2 => 'Luchador 2';

  @override
  String get enterFighterName => 'Ingresa el nombre del luchador';

  @override
  String get fighter1NameRequired => 'El nombre del luchador 1 es obligatorio';

  @override
  String get fighter2NameRequired => 'El nombre del luchador 2 es obligatorio';

  @override
  String get fighter1Color => 'Color del luchador 1';

  @override
  String get fighter2Color => 'Color del luchador 2';

  @override
  String get matchDuration => 'Duración de la lucha';

  @override
  String get createMatch => 'Crear lucha';

  @override
  String get couldNotPublishMatch =>
      'No se pudo publicar la lucha. Verifica tu conexión e intenta de nuevo.';

  @override
  String get retry => 'Reintentar';

  @override
  String matchId(String id) {
    return 'Lucha #$id';
  }

  @override
  String get canceled => 'CANCELADO';

  @override
  String get vsLabel => 'VS';

  @override
  String get takedownSweep => 'Derribo / Barrida';

  @override
  String get guardPass => 'Pasaje de guardia';

  @override
  String get mountBackTake => 'Monta / Toma de espalda';

  @override
  String get advantage => 'Ventaja';

  @override
  String get penalty => 'Penalidad';

  @override
  String get undoLastAction => 'Deshacer última acción';

  @override
  String get startMatch => 'Iniciar lucha';

  @override
  String get pause => 'Pausar';

  @override
  String get resume => 'Reanudar';

  @override
  String get statusPaused => 'En pausa';

  @override
  String get finish => 'Finalizar';

  @override
  String get holdHint => 'mantener';

  @override
  String get matchFinished => 'Lucha finalizada';

  @override
  String get matchCanceled => 'Lucha cancelada';

  @override
  String get matchReadOnly => 'Solo lectura';

  @override
  String get finishMatchQuestion => '¿Finalizar lucha?';

  @override
  String get finishMatchDescription =>
      'Esto finalizará la lucha y publicará el puntaje final.';

  @override
  String get cancelMatchQuestion => '¿Cancelar lucha?';

  @override
  String get cancelMatchDescription =>
      'Esto cancelará la lucha. Los puntajes no se guardarán.';

  @override
  String get goBack => 'Volver';

  @override
  String get cancelMatch => 'Cancelar lucha';

  @override
  String get leaveMatchQuestion => '¿Salir de la lucha?';

  @override
  String get leaveMatchDescription =>
      'La lucha aún está en curso. ¿Estás seguro de que quieres salir?';

  @override
  String get stay => 'Quedarse';

  @override
  String get leave => 'Salir';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get sectionAppearance => 'Apariencia';

  @override
  String get sectionNostr => 'Nostr';

  @override
  String get relays => 'Relays';

  @override
  String get manageRelayConnections => 'Administrar conexiones de relays';

  @override
  String get sectionMatch => 'Lucha';

  @override
  String get defaultMatchDuration => 'Duración predeterminada';

  @override
  String get fiveMinutes => '5 minutos';

  @override
  String get sectionAbout => 'Acerca de';

  @override
  String get version => 'Versión';

  @override
  String get website => 'Sitio web';

  @override
  String get sourceCode => 'Código fuente';

  @override
  String get sectionLanguage => 'Idioma';

  @override
  String get language => 'Idioma';

  @override
  String get selectLanguage => 'Seleccionar idioma';

  @override
  String get languageSaveFailed =>
      'No se pudo guardar el idioma. Inténtalo de nuevo.';

  @override
  String get relayManagement => 'Gestión de relays';

  @override
  String get refresh => 'Actualizar';

  @override
  String get addCustomRelay => 'Agregar relay personalizado';

  @override
  String get relayHint => 'wss://relay.ejemplo.com';

  @override
  String get pleaseEnterRelayUrl => 'Por favor ingresa una URL de relay';

  @override
  String get relayUrlMustStartWithWss =>
      'La URL debe comenzar con wss:// o ws://';

  @override
  String get adding => 'Agregando...';

  @override
  String get add => 'Agregar';

  @override
  String get noRelaysConfigured => 'No hay relays configurados';

  @override
  String get addRelayToStart =>
      'Agrega un relay para comenzar a publicar eventos';

  @override
  String get relayStatusDisabled => 'Deshabilitado';

  @override
  String get relayStatusConnectedDefault => 'Conectado • Predeterminado';

  @override
  String get relayStatusConnectingDefault => 'Conectando • Predeterminado';

  @override
  String get relayStatusConnected => 'Conectado';

  @override
  String get relayStatusConnecting => 'Conectando';

  @override
  String get removeRelayQuestion => '¿Eliminar relay?';

  @override
  String removeRelayConfirmation(String url) {
    return '¿Estás seguro de que quieres eliminar $url?';
  }

  @override
  String get remove => 'Eliminar';

  @override
  String get relayAddedSuccessfully => 'Relay agregado correctamente';

  @override
  String get relayRemoved => 'Relay eliminado';

  @override
  String get systemDefault => 'Sistema';

  @override
  String get themeMode => 'Tema';

  @override
  String get dark => 'Oscuro';

  @override
  String get light => 'Claro';

  @override
  String get followSystemTheme => 'Seguir configuración del sistema';

  @override
  String get licenseTitle => 'Licencia';

  @override
  String get licenseText =>
      'Choke\nCopyright (C) 2026 ProtoLayer OÜ\n\nEste programa es software libre: puedes redistribuirlo y/o modificarlo bajo los términos de la Licencia Pública General GNU publicada por la Free Software Foundation, ya sea la versión 3 de la Licencia o (a tu elección) cualquier versión posterior.\n\nEste programa se distribuye con la esperanza de que sea útil, pero SIN NINGUNA GARANTÍA; ni siquiera la garantía implícita de COMERCIABILIDAD o IDONEIDAD PARA UN FIN PARTICULAR. Consulta la Licencia Pública General GNU para más detalles.';

  @override
  String get licenseReadFull =>
      '¿Quieres leerla entera? El texto completo de la licencia está aquí:';

  @override
  String get licenseLabel => 'Licencia';

  @override
  String get licenseSubtitle => 'GNU GPL v3.0';

  @override
  String get relayErrorLoadFailed =>
      'Error al cargar la configuración de relays';

  @override
  String get relayErrorAlreadyExists => 'El relay ya existe';

  @override
  String get relayErrorInvalidUrl =>
      'URL de relay inválida. Debe comenzar con wss://';

  @override
  String get relayErrorUnreachable =>
      'No se pudo conectar al relay. Verifica la URL e intenta de nuevo';

  @override
  String get relayErrorAddFailed => 'Error al agregar el relay';

  @override
  String get relayErrorRemoveFailed => 'Error al eliminar el relay';

  @override
  String get relayErrorCannotRemoveLast =>
      'No se puede eliminar el último relay activo';

  @override
  String get relayErrorToggleFailed => 'Error al actualizar el relay';

  @override
  String get relayErrorCannotDisableLast =>
      'Al menos un relay debe permanecer activo';

  @override
  String builtBy(String name) {
    return 'Construido por $name';
  }

  @override
  String get bjjBlackBelt => 'Cinturón negro de BJJ';

  @override
  String get outcomeTitle => '¿Cómo terminó?';

  @override
  String get outcomeSubmission => 'Sumisión';

  @override
  String get outcomePoints => 'Puntos';

  @override
  String get outcomeAdvantages => 'Ventajas';

  @override
  String get outcomeDecision => 'Decisión arbitral';

  @override
  String get outcomeDq => 'Descalificación';

  @override
  String get outcomeForfeit => 'Abandono';

  @override
  String get outcomeDraw => 'Empate';

  @override
  String get outcomeWhichFighter => '¿Qué luchador ganó?';

  @override
  String get outcomeTechnique => 'Técnica (opcional)';

  @override
  String get outcomeDqCategory => 'Categoría';

  @override
  String get outcomeDqAccumulated => 'Cuatro penalidades';

  @override
  String get outcomeDqTechnical => 'Falta técnica';

  @override
  String get outcomeDqDisciplinary => 'Falta disciplinaria';

  @override
  String get outcomeDqDetail => 'Qué pasó (opcional)';

  @override
  String get outcomeConfirm => 'Confirmar';

  @override
  String get outcomeTimeUp => 'Se acabó el tiempo — ¿cómo terminó?';

  @override
  String outcomeWinsBy(String name) {
    return 'Gana $name';
  }

  @override
  String get skip => 'Omitir';

  @override
  String get outcomeAmend => 'Corregir resultado';

  @override
  String outcomeSubmissionOf(String technique) {
    return 'Sumisión ($technique)';
  }

  @override
  String get subArmbar => 'Llave de brazo';

  @override
  String get subRearNakedChoke => 'Mataleón';

  @override
  String get subTriangle => 'Triángulo';

  @override
  String get subGuillotine => 'Guillotina';

  @override
  String get subKimura => 'Kimura';

  @override
  String get subAmericana => 'Americana';

  @override
  String get subCrossCollarChoke => 'Estrangulación cruzada';

  @override
  String get subBowAndArrow => 'Arco y flecha';

  @override
  String get subEzekiel => 'Ezequiel';

  @override
  String get subOmoplata => 'Omoplata';

  @override
  String get subArmTriangle => 'Triángulo de brazo';

  @override
  String get subNorthSouthChoke => 'Estrangulación norte-sur';

  @override
  String get subStraightAnkleLock => 'Llave de tobillo';

  @override
  String get subHeelHook => 'Heel hook';

  @override
  String get subToeHold => 'Americana de pie';

  @override
  String get outcomeSubmissionOther => 'Otra…';

  @override
  String get settingsSubmissions => 'Sumisiones';

  @override
  String get settingsSubmissionsDesc =>
      'Las técnicas que se ofrecen cuando una lucha termina por sumisión';

  @override
  String get settingsMatchSound => 'Sonidos de la lucha';

  @override
  String get settingsMatchSoundOn =>
      'Campana al iniciar, bocina al acabarse el tiempo';

  @override
  String get settingsMatchSoundOff => 'El reloj corre en silencio';

  @override
  String get submissionsAdd => 'Agregar sumisión';

  @override
  String get submissionsName => 'Técnica';

  @override
  String get submissionsRemove => 'Quitar';

  @override
  String get submissionsRestore => 'Restaurar las predeterminadas';

  @override
  String get submissionsDuplicate => 'Ya está en la lista';

  @override
  String get submissionsEmpty =>
      'No queda ninguna sumisión. Agrega una o restaura las predeterminadas.';

  @override
  String get navScoreboard => 'Tablero';

  @override
  String get scoreboardPubkeyHint => 'npub o clave pública hex del organizador';

  @override
  String get scoreboardWatch => 'Ver';

  @override
  String get scoreboardStopWatching => 'Dejar de ver';

  @override
  String get scoreboardInvalidPubkey =>
      'Clave pública inválida: debe ser npub o hex de 64 caracteres';

  @override
  String get scoreboardWelcomeTitle => 'Mirá los tatamis de otros';

  @override
  String get scoreboardWelcomeBody =>
      'Pegá la clave pública que compartió un organizador y sus luchas aparecen acá en vivo.';

  @override
  String get scoreboardEmptyTitle => 'Todavía no hay luchas';

  @override
  String get scoreboardEmptyBody =>
      'Esperando eventos de lucha de este organizador…';

  @override
  String get scoreboardTime => 'TIEMPO';

  @override
  String get scoreboardWinner => 'GANADOR';

  @override
  String get scoreboardResult => 'RESULTADO';

  @override
  String get scoreboardAdvShort => 'VENT';

  @override
  String get scoreboardPenShort => 'PEN';

  @override
  String scoreboardPointsShort(int points) {
    return '$points PTS';
  }

  @override
  String get boardLiveCredit => 'Marcador en vivo';

  @override
  String get scoreboardBrokenLinkTitle => 'Ese link está roto';

  @override
  String get scoreboardBrokenLinkBody =>
      'Apuntaba a algo en particular, pero no se pudo leer una parte. Pedile a quien te lo compartió que te lo mande de nuevo.';

  @override
  String get scoreboardBrokenLinkDismiss => 'Ver mi tablero';

  @override
  String get scoreboardShareBoard => 'Compartir este tablero';

  @override
  String get scoreboardShareBoardMessage =>
      'Seguí estas luchas de BJJ en vivo en bjjscore.live:';

  @override
  String get scoreboardQrTitle => 'Escaneá para ver en vivo';

  @override
  String get scoreboardQrHint =>
      'Apuntá la cámara del teléfono a este código para abrir el tablero en vivo';

  @override
  String get scoreboardMatchPendingTitle => 'Buscando esa lucha…';

  @override
  String get scoreboardMatchPendingBody =>
      'El link nombraba una lucha de este tablero. Esperando a que llegue.';

  @override
  String get scoreboardMatchUnresolvedTitle =>
      'Esa lucha no está en este tablero';

  @override
  String get scoreboardMatchUnresolvedBody =>
      'Puede que haya terminado hace rato: un link de lucha dura alrededor de un día. Pedile uno nuevo a quien te lo compartió.';
}
