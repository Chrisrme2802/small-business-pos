/// Define las modalidades de precio aplicables a cada pedido.
enum TipoTarifa {
  /// Tarifa estándar aplicada a compradores individuales.
  publico,

  /// Tarifa mayoreo tiendas y revendedores.
  tienda,
}

/// Representa un pedido individual de tamales dentro del punto de venta.
///
/// Almacena las cantidades solicitadas por sabor, congela los precios unitarios
/// vigentes y controla el estado de entrega, pago y ciclo semanal.
class Pedido {
  /// Identificador único del pedido.
  final String id;

  /// Nombre del cliente particular o de la tienda que realiza el encargo.
  final String cliente;

  /// Modalidad de tarifa aplicada ([TipoTarifa.publico] o [TipoTarifa.tienda]).
  final TipoTarifa tarifa;

  /// Cantidad de tamales de puerco incluidos en el pedido.
  final int cantidadPuerco;

  /// Cantidad de tamales de elote incluidos en el pedido.
  final int cantidadElote;

  /// Precio unitario del tamal de puerco congelado al crear el pedido.
  final double precioPuercoAplicado;

  /// Precio unitario del tamal de elote congelado al crear el pedido.
  final double precioEloteAplicado;

  /// Marca de tiempo exacta en la que se capturó el pedido en la aplicación.
  final DateTime horaRegistro;

  /// Fecha y hora programada para entregar el pedido.
  ///
  /// Cuando es `null`, indica que el pedido es para entrega inmediata.
  final DateTime? horaEntrega;

  /// Indica si los tamales ya fueron entregados al cliente o tienda.
  final bool entregado;

  /// Indica si el importe total del pedido ya fue liquidado.
  final bool pagado;

  /// Identificador del ciclo semanal al que pertenece el pedido.
  ///
  /// Toma el valor `'actual'` mientras la semana sigue abierta y se actualiza
  /// con la fecha de cierre (por ejemplo, `'2026-11-16'`) al realizar el corte.
  final String semanaId;

  /// Crea una instancia inmutable de [Pedido].
  const Pedido({
    required this.id,
    required this.cliente,
    required this.tarifa,
    this.cantidadPuerco = 0,
    this.cantidadElote = 0,
    required this.precioPuercoAplicado,
    required this.precioEloteAplicado,
    required this.horaRegistro,
    this.horaEntrega,
    this.entregado = false,
    this.pagado = false,
    this.semanaId = 'actual',
  });

  /// Indica si el pedido requiere entrega inmediata ([horaEntrega] es `null`).
  bool get esInmediato => horaEntrega == null;

  /// Suma total de piezas de tamales en el pedido
  /// ([cantidadPuerco] + [cantidadElote]).
  int get totalTamales => cantidadPuerco + cantidadElote;

  /// Importe monetario total del pedido calculado con los precios congelados.
  double get totalPesos =>
      (cantidadPuerco * precioPuercoAplicado) +
      (cantidadElote * precioEloteAplicado);

  /// Devuelve una nueva instancia reemplazando únicamente los campos indicados.
  ///
  /// Si [limpiarHoraEntrega] es `true`, convierte el pedido a entrega inmediata
  /// forzando [horaEntrega] a `null`.
  Pedido copyWith({
    String? id,
    String? cliente,
    TipoTarifa? tarifa,
    int? cantidadPuerco,
    int? cantidadElote,
    double? precioPuercoAplicado,
    double? precioEloteAplicado,
    DateTime? horaRegistro,
    DateTime? horaEntrega,
    bool limpiarHoraEntrega = false,
    bool? entregado,
    bool? pagado,
    String? semanaId,
  }) {
    return Pedido(
      id: id ?? this.id,
      cliente: cliente ?? this.cliente,
      tarifa: tarifa ?? this.tarifa,
      cantidadPuerco: cantidadPuerco ?? this.cantidadPuerco,
      cantidadElote: cantidadElote ?? this.cantidadElote,
      precioPuercoAplicado: precioPuercoAplicado ?? this.precioPuercoAplicado,
      precioEloteAplicado: precioEloteAplicado ?? this.precioEloteAplicado,
      horaRegistro: horaRegistro ?? this.horaRegistro,
      horaEntrega: limpiarHoraEntrega
          ? null
          : (horaEntrega ?? this.horaEntrega),
      entregado: entregado ?? this.entregado,
      pagado: pagado ?? this.pagado,
      semanaId: semanaId ?? this.semanaId,
    );
  }

  /// Serializa el pedido a un mapa clave-valor compatible con bases de datos
  /// en la nube (Supabase).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cliente': cliente,
      'tarifa': tarifa.name,
      'cantidadPuerco': cantidadPuerco,
      'cantidadElote': cantidadElote,
      'precioPuercoAplicado': precioPuercoAplicado,
      'precioEloteAplicado': precioEloteAplicado,
      'horaRegistro': horaRegistro.toIso8601String(),
      'horaEntrega': horaEntrega?.toIso8601String(),
      'entregado': entregado,
      'pagado': pagado,
      'semanaId': semanaId,
    };
  }

  /// Reconstruye una instancia de [Pedido] a partir de un [map].
  factory Pedido.fromMap(Map<String, dynamic> map) {
    return Pedido(
      id: map['id'] ?? '',
      cliente: map['cliente'] ?? 'Mostrador',
      tarifa: map['tarifa'] == 'tienda'
          ? TipoTarifa.tienda
          : TipoTarifa.publico,
      cantidadPuerco: map['cantidadPuerco'] ?? 0,
      cantidadElote: map['cantidadElote'] ?? 0,
      precioPuercoAplicado: (map['precioPuercoAplicado'] ?? 0).toDouble(),
      precioEloteAplicado: (map['precioEloteAplicado'] ?? 0).toDouble(),
      horaRegistro: DateTime.parse(map['horaRegistro']),
      horaEntrega: map['horaEntrega'] != null
          ? DateTime.parse(map['horaEntrega'])
          : null,
      entregado: map['entregado'] ?? false,
      pagado: map['pagado'] ?? false,
      semanaId: map['semanaId'] ?? 'actual',
    );
  }
}
