import 'olla_coccion.dart';

/// Representa el estado operativo del inventario diario.
///
/// Controla el flujo completo del producto (congelado, en cocción, listo para
/// entregar y vendido en el día), así como la marca de tiempo objetivo para
/// calcular el temporizador de la vaporera.
class Inventario {
  /// Cantidad de tamales de puerco listos para entrega inmediata.
  final int puercoCocidos;

  /// Cantidad de tamales de puerco almacenados en congelador.
  final int puercoCongelados;

  /// Acumulado de tamales de puerco entregados o vendidos durante la jornada.
  final int puercoVendidosHoy;

  /// Cantidad de tamales de elote listos para entrega inmediata.
  final int eloteCocidos;

  /// Cantidad de tamales de elote almacenados en congelador.
  final int eloteCongelados;

  /// Acumulado de tamales de elote entregados o vendidos durante la jornada.
  final int eloteVendidosHoy;

  /// Lista de vaporeras u ollas actualmente en proceso de cocción.
  final List<OllaCoccion> ollasActivas;

  /// Crea una instancia inmutable de [Inventario].
  ///
  /// Inicializa todos los contadores en `0` y sin cocción activa si no se proporciona
  const Inventario({
    this.puercoCocidos = 0,
    this.puercoCongelados = 0,
    this.puercoVendidosHoy = 0,
    this.eloteCocidos = 0,
    this.eloteCongelados = 0,
    this.eloteVendidosHoy = 0,
    this.ollasActivas = const [],
  });

  /// Total de tamales de puerco cociéndose sumando todas las [ollasActivas].
  int get puercoCociendose =>
      ollasActivas.fold(0, (suma, olla) => suma + olla.cantidadPuerco);

  /// Total de tamales de elote cociéndose sumando todas las [ollasActivas].
  int get eloteCociendose =>
      ollasActivas.fold(0, (suma, olla) => suma + olla.cantidadElote);

  /// Suma total de tamales de puerco disponibles en el día sin vender
  /// ([puercoCocidos] + [puercoCociendose] + [puercoCongelados]).
  int get totalPuercoDisponible =>
      puercoCocidos + puercoCociendose + puercoCongelados;

  /// Suma total de tamales de elote disponibles en el día sin vender
  /// ([eloteCocidos] + [eloteCociendose] + [eloteCongelados]).
  int get totalEloteDisponible =>
      eloteCocidos + eloteCociendose + eloteCongelados;

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
    List<OllaCoccion>? ollasActivas,
  }) {
    return Inventario(
      puercoCocidos: puercoCocidos ?? this.puercoCocidos,
      puercoCongelados: puercoCongelados ?? this.puercoCongelados,
      puercoVendidosHoy: puercoVendidosHoy ?? this.puercoVendidosHoy,
      eloteCocidos: eloteCocidos ?? this.eloteCocidos,
      eloteCongelados: eloteCongelados ?? this.eloteCongelados,
      eloteVendidosHoy: eloteVendidosHoy ?? this.eloteVendidosHoy,
      ollasActivas: ollasActivas ?? this.ollasActivas,
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
      'ollasActivas': ollasActivas.map((o) => o.toMap()).toList(),
    };
  }

  /// Reconstruye una instancia de [Inventario] a partir de un [map].
  factory Inventario.fromMap(Map<String, dynamic> map) {
    final ollasRaw = map['ollasActivas'] as List<dynamic>? ?? [];
    return Inventario(
      puercoCocidos: map['puercoCocidos'] ?? 0,
      puercoCongelados: map['puercoCongelados'] ?? 0,
      puercoVendidosHoy: map['puercoVendidosHoy'] ?? 0,
      eloteCocidos: map['eloteCocidos'] ?? 0,
      eloteCongelados: map['eloteCongelados'] ?? 0,
      eloteVendidosHoy: map['eloteVendidosHoy'] ?? 0,
      ollasActivas: ollasRaw
          .map((e) => OllaCoccion.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
