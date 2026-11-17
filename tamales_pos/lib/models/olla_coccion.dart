/// Representa una vaporera u olla activa en proceso de cocción.
///
/// Permite gestionar múltiples tandas de cocción simultáneas dentro del
/// carrusel superior, cada una con sus propias cantidades de puerco y elote
/// y su temporizador independiente.
class OllaCoccion {
  /// Identificador único.
  final String id;

  /// Etiqueta visible en la interfaz.
  final String nombre;

  /// Cantidad de tamales de puerco cociéndose en esta olla.
  final int cantidadPuerco;

  /// Cantidad de tamales de elote cociéndose en esta olla.
  final int cantidadElote;

  /// Fecha y hora exacta en la que finalizará la cocción de esta olla.
  final DateTime horaFin;

  /// Crea una instancia inmutable de [OllaCoccion].
  const OllaCoccion({
    required this.id,
    required this.nombre,
    this.cantidadPuerco = 0,
    this.cantidadElote = 0,
    required this.horaFin,
  });

  /// Suma total de tamales cociéndose en esta olla ([cantidadPuerco] + [cantidadElote]).
  int get totalPiezas => cantidadPuerco + cantidadElote;

  /// Calcula el tiempo restante comparando [horaFin] contra el reloj actual.
  ///
  /// Devuelve [Duration.zero] si el tiempo de cocción ya concluyó.
  Duration get tiempoRestante {
    final diferencia = horaFin.difference(DateTime.now());
    return diferencia.isNegative ? Duration.zero : diferencia;
  }

  /// Indica si el temporizador de esta olla ya llegó a cero.
  bool get estaLista => tiempoRestante == Duration.zero;

  /// Serializa la olla a un mapa clave-valor para almacenamiento en la nube.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'cantidadPuerco': cantidadPuerco,
      'cantidadElote': cantidadElote,
      'horaFin': horaFin.toIso8601String(),
    };
  }

  /// Reconstruye una instancia de [OllaCoccion] a partir de un [map].
  factory OllaCoccion.fromMap(Map<String, dynamic> map) {
    return OllaCoccion(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? 'Olla',
      cantidadPuerco: map['cantidadPuerco'] ?? 0,
      cantidadElote: map['cantidadElote'] ?? 0,
      horaFin: DateTime.parse(map['horaFin']),
    );
  }
}
