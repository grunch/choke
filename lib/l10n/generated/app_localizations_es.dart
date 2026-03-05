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
  String get homeSubtitle => 'Puntúa tus combates de BJJ';

  @override
  String get navHome => 'Inicio';

  @override
  String get navMatch => 'Combate';

  @override
  String get navAccount => 'Cuenta';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get matchListPlaceholder =>
      'Crea un combate desde la pantalla de inicio';

  @override
  String get noMatchesYet => 'Aún no hay combates';

  @override
  String get createNewOne => '¡Crea uno nuevo!';

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
  String get newMatch => 'Nuevo combate';

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
  String get matchDuration => 'Duración del combate';

  @override
  String get createMatch => 'Crear combate';

  @override
  String get couldNotPublishMatch =>
      'No se pudo publicar el combate. Verifica tu conexión e intenta de nuevo.';

  @override
  String get retry => 'Reintentar';

  @override
  String matchId(String id) {
    return 'Combate #$id';
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
  String get startMatch => 'Iniciar combate';

  @override
  String get finish => 'Finalizar';

  @override
  String get matchFinished => 'Combate finalizado';

  @override
  String get matchCanceled => 'Combate cancelado';

  @override
  String get finishMatchQuestion => '¿Finalizar combate?';

  @override
  String get finishMatchDescription =>
      'Esto finalizará el combate y publicará el puntaje final.';

  @override
  String get cancelMatchQuestion => '¿Cancelar combate?';

  @override
  String get cancelMatchDescription =>
      'Esto cancelará el combate. Los puntajes no se guardarán.';

  @override
  String get goBack => 'Volver';

  @override
  String get cancelMatch => 'Cancelar combate';

  @override
  String get leaveMatchQuestion => '¿Salir del combate?';

  @override
  String get leaveMatchDescription =>
      'El combate aún está en curso. ¿Estás seguro de que quieres salir?';

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
  String get sectionMatch => 'Combate';

  @override
  String get defaultMatchDuration => 'Duración predeterminada';

  @override
  String get fiveMinutes => '5 minutos';

  @override
  String get sectionAbout => 'Acerca de';

  @override
  String get version => 'Versión';

  @override
  String get sourceCode => 'Código fuente';

  @override
  String get sectionLanguage => 'Idioma';

  @override
  String get language => 'Idioma';

  @override
  String get selectLanguage => 'Seleccionar idioma';

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
  String get systemDefault => 'Predeterminado del sistema';

  @override
  String get themeMode => 'Tema';

  @override
  String get dark => 'Oscuro';

  @override
  String get light => 'Claro';

  @override
  String get followSystemTheme => 'Seguir configuración del sistema';
}
