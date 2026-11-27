import 'dart:async';

import 'package:flutter/material.dart';

/// Muestra un diálogo de confirmación cuyo botón definitivo permanece
/// deshabilitado durante [segundos] para evitar toques accidentales.
///
/// Devuelve `true` solo si la persona confirmó; cualquier otra salida
/// (cancelar, tocar fuera) devuelve `false`.
Future<bool> confirmarConEspera(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  required String textoConfirmar,
  Color? colorConfirmar,
  int segundos = 3,
}) async {
  final resultado = await showDialog<bool>(
    context: context,
    builder: (_) => _DialogoConEspera(
      titulo: titulo,
      mensaje: mensaje,
      textoConfirmar: textoConfirmar,
      colorConfirmar: colorConfirmar,
      segundos: segundos,
    ),
  );
  return resultado == true;
}

/// Diálogo modal con cuenta regresiva antes de habilitar la confirmación.
class _DialogoConEspera extends StatefulWidget {
  final String titulo;
  final String mensaje;
  final String textoConfirmar;
  final Color? colorConfirmar;
  final int segundos;

  const _DialogoConEspera({
    required this.titulo,
    required this.mensaje,
    required this.textoConfirmar,
    required this.colorConfirmar,
    required this.segundos,
  });

  @override
  State<_DialogoConEspera> createState() => _DialogoConEsperaState();
}

class _DialogoConEsperaState extends State<_DialogoConEspera> {
  late int _restantes = widget.segundos;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _restantes = (_restantes - 1).clamp(0, widget.segundos));
      if (_restantes == 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listo = _restantes == 0;
    return AlertDialog(
      title: Text(widget.titulo),
      content: Text(widget.mensaje),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Volver'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: widget.colorConfirmar,
            foregroundColor: widget.colorConfirmar == null
                ? null
                : Colors.white,
          ),
          onPressed: listo ? () => Navigator.of(context).pop(true) : null,
          child: Text(
            listo ? widget.textoConfirmar : 'Espera $_restantes s...',
          ),
        ),
      ],
    );
  }
}
