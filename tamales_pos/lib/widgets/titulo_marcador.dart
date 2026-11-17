import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Amarillo "marcatextos" de los bocetos y verde limón de la pestaña activa.
const colorMarcador = Color(0xFFE0A526);
const colorActivo = Color(0xFFC6F135);

final moneda = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

/// Título de sección con fondo tipo marcatextos.
class TituloMarcador extends StatelessWidget {
  final String texto;
  final Widget? trailing;
  const TituloMarcador(this.texto, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: colorMarcador.withAlpha(210),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            texto,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}
