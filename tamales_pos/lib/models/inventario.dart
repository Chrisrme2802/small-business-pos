/// Representa el estado operativo del inventario diario.
///
/// Controla el flujo completo del producto (congelado, en cocción, listo para
/// entregar y vendido en el día), así como la marca de tiempo objetivo para
/// calcular el temporizador de la vaporera.
class Inventario {
  /// Cantidad de tamales de puerco listos para entrega inmediata.
  final int puercoCocidos;

  /// Cantidad de tamales de puerco actualmente en la vaporera.
  final int puercoCociendose;

  /// Cantidad de tamales de puerco almacenados en congelador.
  final int puercoCongelados;

  /// Acumulado de tamales de puerco entregados o vendidos durante la jornada.
  final int puercoVendidosHoy;

  /// Cantidad de tamales de elote listos para entrega inmediata.
  final int eloteCocidos;

  /// Cantidad de tamales de elote actualmente en la vaporera.
  final int eloteCociendose;

  /// Cantidad de tamales de elote almacenados en congelador.
  final int eloteCongelados;

  /// Acumulado de tamales de elote entregados o vendidos durante la jornada.
  final int eloteVendidosHoy;

  /// Fecha y hora estimada en la que finalizará la cocción de la tanda actual.
  final DateTime? horaFinCoccion;

  /// Crea una instancia inmutable de [Inventario].
  ///
  /// Inicializa todos los contadores en `0` y sin cocción activa si no se proporciona
  const Inventario({
    this.puercoCocidos = 0,
    this.puercoCociendose = 0,
    this.puercoCongelados = 0,
    this.puercoVendidosHoy = 0,
    this.eloteCocidos = 0,
    this.eloteCociendose = 0,
    this.eloteCongelados = 0,
    this.eloteVendidosHoy = 0,
    this.horaFinCoccion,
  });

  /// Suma total de tamales de puerco disponibles en el día sin vender
  /// ([puercoCocidos] + [puercoCociendose] + [puercoCongelados]).
  int get totalPuercoDisponible =>
      puercoCocidos + puercoCociendose + puercoCongelados;

  /// Suma total de tamales de elote disponibles en el día sin vender
  /// ([eloteCocidos] + [eloteCociendose] + [eloteCongelados]).
  int get totalEloteDisponible =>
      eloteCocidos + eloteCociendose + eloteCongelados;

  /// Indica si existe una tanda activa en la vaporera con temporizador vigente.
  bool get hayCoccionActiva =>
      (puercoCociendose > 0 || eloteCociendose > 0) && horaFinCoccion != null;

  /// Calcula el tiempo restante de cocción comparando [horaFinCoccion]
  ///
  /// Devuelve [Duration.zero] si no hay cocción activa o si el tiempo ya venció.
  Duration get tiempoRestanteCoccion {
    if (horaFinCoccion == null) return Duration.zero;
    final diferencia = horaFinCoccion!.difference(DateTime.now());
    return diferencia.isNegative ? Duration.zero : diferencia;
  }

  /// Devuelve una nueva instancia reemplazando únicamente los valores indicados.
  ///
  /// Si [limpiarHoraFin] es `true`, fuerza [horaFinCoccion] a `null` sin
  /// importar el valor que tenga actualmente.
  Inventario copyWith({
    int? puercoCocidos,
    int? puercoCociendose,
    int? puercoCongelados,
    int? puercoVendidosHoy,
    int? eloteCocidos,
    int? eloteCociendose,
    int? eloteCongelados,
    int? eloteVendidosHoy,
    DateTime? horaFinCoccion,
    bool limpiarHoraFin = false,
  }) {
    return Inventario(
      puercoCocidos: puercoCocidos ?? this.puercoCocidos,
      puercoCociendose: puercoCociendose ?? this.puercoCociendose,
      puercoCongelados: puercoCongelados ?? this.puercoCongelados,
      puercoVendidosHoy: puercoVendidosHoy ?? this.puercoVendidosHoy,
      eloteCocidos: eloteCocidos ?? this.eloteCocidos,
      eloteCociendose: eloteCociendose ?? this.eloteCociendose,
      eloteCongelados: eloteCongelados ?? this.eloteCongelados,
      eloteVendidosHoy: eloteVendidosHoy ?? this.eloteVendidosHoy,
      horaFinCoccion: limpiarHoraFin
          ? null
          : (horaFinCoccion ?? this.horaFinCoccion),
    );
  }

  /// Serializa el estado del inventario a un mapa clave-valor compatible
  /// con bases de datos en la nube (Supabase).
  Map<String, dynamic> toMap() {
    return {
      'puercoCocidos': puercoCocidos,
      'puercoCociendose': puercoCociendose,
      'puercoCongelados': puercoCongelados,
      'puercoVendidosHoy': puercoVendidosHoy,
      'eloteCocidos': eloteCocidos,
      'eloteCociendose': eloteCociendose,
      'eloteCongelados': eloteCongelados,
      'eloteVendidosHoy': eloteVendidosHoy,
      'horaFinCoccion': horaFinCoccion?.toIso8601String(),
    };
  }

  /// Reconstruye una instancia de [Inventario] a partir de un [map].
  factory Inventario.fromMap(Map<String, dynamic> map) {
    return Inventario(
      puercoCocidos: map['puercoCocidos'] ?? 0,
      puercoCociendose: map['puercoCociendose'] ?? 0,
      puercoCongelados: map['puercoCongelados'] ?? 0,
      puercoVendidosHoy: map['puercoVendidosHoy'] ?? 0,
      eloteCocidos: map['eloteCocidos'] ?? 0,
      eloteCociendose: map['eloteCociendose'] ?? 0,
      eloteCongelados: map['eloteCongelados'] ?? 0,
      eloteVendidosHoy: map['eloteVendidosHoy'] ?? 0,
      horaFinCoccion: map['horaFinCoccion'] != null
          ? DateTime.parse(map['horaFinCoccion'])
          : null,
    );
  }
}
