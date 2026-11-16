/// Tarifas unitarias vigentes para la venta de tamales.
///
/// Separa los precios públicos de los de las tiendas.
class ConfiguracionPrecios {
  /// Precio unitario del tamal de puerco para venta al público en general.
  final double puercoPublico;

  /// Precio unitario del tamal de puerco para venta a tiendas.
  final double puercoTienda;

  /// Precio unitario del tamal de elote para venta al público en general.
  final double elotePublico;

  /// Precio unitario del tamal de elote para venta a tiendas.
  final double eloteTienda;

  /// Crea una instancia inmutable de [ConfiguracionPrecios].
  ///
  /// Si no se especifican valores, utiliza las tarifas base por defecto.
  const ConfiguracionPrecios({
    this.puercoPublico = 18.0,
    this.puercoTienda = 16.5,
    this.elotePublico = 17.0,
    this.eloteTienda = 15.5,
  });

  /// Devuelve una nueva instancia reemplazando únicamente los precios indicados.
  ConfiguracionPrecios copyWith({
    double? puercoPublico,
    double? puercoTienda,
    double? elotePublico,
    double? eloteTienda,
  }) {
    return ConfiguracionPrecios(
      puercoPublico: puercoPublico ?? this.puercoPublico,
      puercoTienda: puercoTienda ?? this.puercoTienda,
      elotePublico: elotePublico ?? this.elotePublico,
      eloteTienda: eloteTienda ?? this.eloteTienda,
    );
  }

  /// Serializa la configuración de precios a un mapa clave-valor
  /// compatible con bases de datos en la nube (Supabase).
  Map<String, dynamic> toMap() {
    return {
      'puercoPublico': puercoPublico,
      'puercoTienda': puercoTienda,
      'elotePublico': elotePublico,
      'eloteTienda': eloteTienda,
    };
  }

  /// Reconstruye una instancia de [ConfiguracionPrecios] a partir de un [map].
  ///
  /// Asigna los precios base por defecto en caso de que alguna clave falte o nula
  factory ConfiguracionPrecios.fromMap(Map<String, dynamic> map) {
    return ConfiguracionPrecios(
      puercoPublico: (map['puercoPublico'] ?? 18.0).toDouble(),
      puercoTienda: (map['puercoTienda'] ?? 16.5).toDouble(),
      elotePublico: (map['elotePublico'] ?? 17.0).toDouble(),
      eloteTienda: (map['eloteTienda'] ?? 15.5).toDouble(),
    );
  }
}
