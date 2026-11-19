import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/pedido.dart';
import 'titulo_marcador.dart';

/// Abre un diálogo modal centrando el recibo digital [TarjetaTicket] de [pedido]
/// junto con sus opciones para compartir el ticket formal o cerrar.
Future<void> mostrarTicket(BuildContext context, Pedido pedido) {
  return showDialog(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TarjetaTicket(pedido: pedido),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Comprobante visual de un pedido dentro de la interfaz de la aplicación.
///
/// Conserva la estética cálida de la app para consulta rápida y genera aparte
/// un **ticket formal tipo nota de venta térmica** en PNG de alta resolución
/// al pulsar **Compartir ticket** o **Guardar PNG**.
class TarjetaTicket extends StatefulWidget {
  /// Pedido cuyos detalles se renderizan en el comprobante.
  final Pedido pedido;

  /// Crea una instancia de [TarjetaTicket].
  const TarjetaTicket({super.key, required this.pedido});

  @override
  State<TarjetaTicket> createState() => _TarjetaTicketState();
}

class _TarjetaTicketState extends State<TarjetaTicket> {
  /// Llave del botón compartir para pasar [sharePositionOrigin] en Windows/iPad.
  final GlobalKey _botonCompartirKey = GlobalKey();

  /// Evita pulsaciones múltiples mientras se renderiza y comparte el ticket PNG.
  bool _compartiendo = false;

  /// Formateador de moneda en pesos mexicanos (`$0.00`).
  static final NumberFormat _moneda = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
  );

  /// Devuelve un folio corto y legible a partir de [Pedido.id].
  String get _folioLegible {
    final limpio = widget.pedido.id.trim();
    if (limpio.length <= 8) return '#$limpio';
    return '#${limpio.substring(limpio.length - 8)}';
  }

  /// Revisa si es gratis y si no manda el valor normal
  String _importe(double valor) =>
      widget.pedido.esGratis ? 'GRATIS' : _moneda.format(valor);

  /// Dibuja en memoria mediante [ui.PictureRecorder] un ticket formal tipo
  /// impresora térmica de tienda (fondo blanco, tipografía monoespaciada,
  /// columnas alineadas y totales) y lo devuelve como bytes PNG.
  Future<Uint8List> _generarImagenTicketFormal() async {
    final p = widget.pedido;
    const double ancho = 580;
    const double margenX = 36;
    const double anchoUtil = ancho - (margenX * 2);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final fondoBlanco = Paint()..color = const Color(0xFFFFFFFF);
    final bordeSutil = Paint()
      ..color = const Color(0xFFD4D4D8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    TextPainter crearTexto(
      String texto, {
      double size = 20,
      FontWeight weight = FontWeight.w500,
      Color color = const Color(0xFF111827),
      TextAlign align = TextAlign.left,
      double? maxWidth,
    }) {
      final tp = TextPainter(
        text: TextSpan(
          text: texto,
          style: TextStyle(
            fontFamily: 'Consolas',
            fontFamilyFallback: const ['Courier New', 'monospace'],
            fontSize: size,
            fontWeight: weight,
            color: color,
            letterSpacing: 0.4,
          ),
        ),
        textAlign: align,
        textDirection: ui.TextDirection.ltr,
      );
      tp.layout(maxWidth: maxWidth ?? anchoUtil);
      return tp;
    }

    final subtotalPuerco = p.cantidadPuerco * p.precioPuercoAplicado;
    final subtotalElote = p.cantidadElote * p.precioEloteAplicado;

    final fechaTexto = DateFormat('dd/MM/yyyy  HH:mm').format(p.horaRegistro);
    final tarifaTexto = p.tarifa == TipoTarifa.tienda ? 'TIENDA' : 'PÚBLICO';
    final estadoPago = p.cancelado
        ? 'CANCELADO'
        : (p.esGratis
              ? 'CORTESÍA'
              : (p.pagado ? 'PAGADO' : 'PENDIENTE DE PAGO'));

    double altoTotal = 460;
    if (p.cantidadPuerco > 0) altoTotal += 62;
    if (p.cantidadElote > 0) altoTotal += 62;

    final rectTotal = Rect.fromLTWH(0, 0, ancho, altoTotal);
    canvas.drawRect(rectTotal, fondoBlanco);
    canvas.drawRect(rectTotal.deflate(6), bordeSutil);

    double y = 36;

    void dibujarCentrado(
      String texto, {
      double size = 20,
      FontWeight weight = FontWeight.w500,
      Color color = const Color(0xFF111827),
      double espacioDespues = 6,
    }) {
      final tp = crearTexto(
        texto,
        size: size,
        weight: weight,
        color: color,
        align: TextAlign.center,
      );
      tp.paint(canvas, Offset((ancho - tp.width) / 2, y));
      y += tp.height + espacioDespues;
    }

    void dibujarFila(
      String izquierda,
      String derecha, {
      double size = 19,
      FontWeight weight = FontWeight.w500,
      Color color = const Color(0xFF111827),
      double espacioDespues = 8,
    }) {
      final tpIzq = crearTexto(
        izquierda,
        size: size,
        weight: weight,
        color: color,
      );
      final tpDer = crearTexto(
        derecha,
        size: size,
        weight: weight,
        color: color,
      );
      tpIzq.paint(canvas, Offset(margenX, y));
      tpDer.paint(canvas, Offset(ancho - margenX - tpDer.width, y));
      y +=
          (tpIzq.height > tpDer.height ? tpIzq.height : tpDer.height) +
          espacioDespues;
    }

    void dibujarSeparador({String caracter = '-'}) {
      final linea = List.filled(42, caracter).join();
      final tp = crearTexto(
        linea,
        size: 18,
        color: const Color(0xFF6B7280),
        align: TextAlign.center,
      );
      tp.paint(canvas, Offset((ancho - tp.width) / 2, y));
      y += tp.height + 10;
    }

    // 1. Encabezado comercial
    dibujarCentrado(
      'TAMALES',
      size: 32,
      weight: FontWeight.w800,
      espacioDespues: 4,
    );
    dibujarCentrado(
      'NOTA DE VENTA',
      size: 18,
      weight: FontWeight.w700,
      color: const Color(0xFF4B5563),
      espacioDespues: 14,
    );

    dibujarSeparador(caracter: '=');

    // 2. Datos del comprobante
    dibujarFila('FOLIO:', _folioLegible, weight: FontWeight.w700);
    dibujarFila('FECHA:', fechaTexto);
    dibujarFila('CLIENTE:', p.cliente.toUpperCase(), weight: FontWeight.w700);
    dibujarFila('TARIFA:', tarifaTexto);
    dibujarFila(
      'ESTATUS:',
      estadoPago,
      weight: FontWeight.w700,
      color: p.cancelado
          ? const Color(0xFFB91C1C)
          : (p.pagado ? const Color(0xFF15803D) : const Color(0xFFB45309)),
      espacioDespues: 12,
    );

    dibujarSeparador();

    // 3. Encabezado de tabla de conceptos
    dibujarFila(
      'CANT  CONCEPTO',
      'IMPORTE',
      size: 17,
      weight: FontWeight.w700,
      color: const Color(0xFF4B5563),
      espacioDespues: 10,
    );

    // 4. Renglones de productos
    if (p.cantidadPuerco > 0) {
      dibujarFila(
        '${p.cantidadPuerco.toString().padLeft(2)} × Tamal de puerco',
        _importe(subtotalPuerco),
        size: 20,
        weight: FontWeight.w700,
        espacioDespues: 2,
      );
      dibujarFila(
        '     Precio unitario: ${_importe(p.precioPuercoAplicado)}',
        '',
        size: 16,
        color: const Color(0xFF4B5563),
        espacioDespues: 12,
      );
    }

    if (p.cantidadElote > 0) {
      dibujarFila(
        '${p.cantidadElote.toString().padLeft(2)} × Tamal de elote',
        _importe(subtotalElote),
        size: 20,
        weight: FontWeight.w700,
        espacioDespues: 2,
      );
      dibujarFila(
        '     Precio unitario: ${_importe(p.precioEloteAplicado)}',
        '',
        size: 16,
        color: const Color(0xFF4B5563),
        espacioDespues: 12,
      );
    }

    dibujarSeparador(caracter: '=');

    // 5. Totales
    dibujarFila(
      'PIEZAS TOTALES:',
      '${p.totalPiezas} pzas',
      size: 19,
      weight: FontWeight.w600,
      espacioDespues: 8,
    );
    dibujarFila(
      'TOTAL A PAGAR:',
      _importe(p.totalPesos),
      size: 26,
      weight: FontWeight.w800,
      espacioDespues: 16,
    );

    dibujarSeparador();

    // 6. Pie del ticket
    dibujarCentrado(
      '¡GRACIAS POR SU PREFERENCIA!',
      size: 18,
      weight: FontWeight.w700,
      espacioDespues: 4,
    );
    dibujarCentrado(
      'Conserve este comprobante para cualquier aclaración',
      size: 14,
      color: const Color(0xFF6B7280),
      espacioDespues: 0,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(ancho.toInt(), (y + 28).toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Genera el ticket formal en PNG. En Android/iOS abre la hoja nativa de
  /// compartir; en Windows lo guarda directamente en la carpeta de Descargas
  /// para evitar el fallo conocido del diálogo "Compartir" de Windows 11.
  Future<void> _compartirTicketFormal() async {
    if (_compartiendo) return;
    setState(() => _compartiendo = true);

    try {
      final pngBytes = await _generarImagenTicketFormal();
      final folioLimpio = _folioLegible.replaceAll('#', '');
      final nombreArchivo = 'Ticket_Tamales_$folioLimpio.png';

      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final dirDescargas =
            await getDownloadsDirectory() ??
            await getApplicationDocumentsDirectory();
        final archivo = File(
          '${dirDescargas.path}${Platform.pathSeparator}$nombreArchivo',
        );
        await archivo.writeAsBytes(pngBytes, flush: true);

        if (Platform.isWindows) {
          // Abre el Explorador de Windows con el ticket PNG ya seleccionado
          await Process.run('explorer.exe', ['/select,', archivo.path]);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ticket guardado en Descargas: $nombreArchivo'),
            ),
          );
        }
        return;
      }

      // En Android / iOS usa el menú nativo de compartir
      final dir = await getTemporaryDirectory();
      final archivo = File('${dir.path}/$nombreArchivo');
      await archivo.writeAsBytes(pngBytes, flush: true);

      await Share.shareXFiles([XFile(archivo.path)]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo exportar el ticket: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _compartiendo = false);
    }
  }

  /// Copia un resumen estructurado en texto plano al portapapeles.
  Future<void> _copiarTexto() async {
    final p = widget.pedido;
    final lineas = <String>[
      'TAMALES · Nota de Venta $_folioLegible',
      'Cliente: ${p.cliente}',
      'Tarifa: ${p.tarifa == TipoTarifa.tienda ? 'Tienda' : 'Público'}',
      'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(p.horaRegistro)}',
      'Estatus: ${p.cancelado ? 'CANCELADO' : (p.pagado ? 'Pagado' : 'Por cobrar')}',
      '---',
      if (p.cantidadPuerco > 0)
        '${p.cantidadPuerco} × Tamal de puerco (${_importe(p.precioPuercoAplicado)} c/u) = ${_importe(p.cantidadPuerco * p.precioPuercoAplicado)}',
      if (p.cantidadElote > 0)
        '${p.cantidadElote} × Tamal de elote (${_importe(p.precioEloteAplicado)} c/u) = ${_importe(p.cantidadElote * p.precioEloteAplicado)}',
      '---',
      'TOTAL (${p.totalPiezas} pzas): ${_importe(p.totalPesos)}',
    ];

    await Clipboard.setData(ClipboardData(text: lineas.join('\n')));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket copiado al portapapeles')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pedido = widget.pedido;
    final subtotalPuerco = pedido.cantidadPuerco * pedido.precioPuercoAplicado;
    final subtotalElote = pedido.cantidadElote * pedido.precioEloteAplicado;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Vista cálida dentro de la app
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEF),
            border: Border.all(color: Colors.black54),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(child: TituloMarcador('Tamales')),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _folioLegible,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      pedido.cliente,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (pedido.cancelado)
                    _construirEtiquetaEstado(
                      texto: 'CANCELADO',
                      fondo: Colors.red.shade100,
                      colorTexto: Colors.red.shade900,
                    )
                  else
                    _construirEtiquetaEstado(
                      texto: pedido.pagado ? 'PAGADO' : 'POR COBRAR',
                      fondo: pedido.pagado
                          ? const Color(0xFFD9F99D)
                          : Colors.amber.shade100,
                      colorTexto: Colors.black87,
                    ),
                ],
              ),
              const SizedBox(height: 10),

              _construirFilaMetadato(
                etiqueta: 'Tarifa',
                valor: pedido.tarifa == TipoTarifa.tienda
                    ? 'Tienda'
                    : 'Público',
              ),
              _construirFilaMetadato(
                etiqueta: 'Registrado',
                valor: DateFormat('dd/MM/yyyy HH:mm')
                    .format(pedido.horaRegistro),
              ),

              const Divider(height: 22),

              if (pedido.cantidadPuerco > 0)
                _construirRenglonProducto(
                  nombre: 'Tamal de puerco',
                  cantidad: pedido.cantidadPuerco,
                  precioUnitario: pedido.precioPuercoAplicado,
                  subtotal: subtotalPuerco,
                ),
              if (pedido.cantidadElote > 0) ...[
                if (pedido.cantidadPuerco > 0) const SizedBox(height: 10),
                _construirRenglonProducto(
                  nombre: 'Tamal de elote',
                  cantidad: pedido.cantidadElote,
                  precioUnitario: pedido.precioEloteAplicado,
                  subtotal: subtotalElote,
                ),
              ],

              const Divider(height: 22),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        '${pedido.totalPiezas} pieza(s) en total',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _importe(pedido.totalPesos),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      decoration: pedido.cancelado
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                '¡Gracias por su preferencia!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Acciones de exportación
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                key: _botonCompartirKey,
                onPressed: _compartiendo ? null : _compartirTicketFormal,
                icon: _compartiendo
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.receipt_long, size: 18),
                label: const Text('Compartir ticket'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _copiarTexto,
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copiar'),
            ),
          ],
        ),
      ],
    );
  }

  /// Construye una insignia compacta para el estatus financiero o de cancelación.
  Widget _construirEtiquetaEstado({
    required String texto,
    required Color fondo,
    required Color colorTexto,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 11,
          color: colorTexto,
        ),
      ),
    );
  }

  /// Construye un renglón clave-valor alineado para los metadatos del pedido.
  Widget _construirFilaMetadato({
    required String etiqueta,
    required String valor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            etiqueta,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          Text(
            valor,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  /// Construye la línea de desglose con cantidad, precio unitario y subtotal.
  Widget _construirRenglonProducto({
    required String nombre,
    required int cantidad,
    required double precioUnitario,
    required double subtotal,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$cantidad × $nombre',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${_importe(precioUnitario)} c/u',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
        Text(
          _importe(subtotal),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
