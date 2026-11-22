#!/usr/bin/env python3
"""Respaldo de las tablas de Tamales POS desde Supabase a archivos JSON.

Descarga con paginación (Supabase devuelve máximo 1000 filas por consulta)
las tres tablas de la app y las guarda en una carpeta ``respaldo_AAAA-MM-DD``.
Usa solo la biblioteca estándar de Python, sin dependencias.

Variables de entorno requeridas:
    SUPABASE_URL
    SUPABASE_SERVICE_KEY
                          Se salta RLS, así que NUNCA va dentro de la app.
"""
import datetime
import json
import os
import pathlib
import sys
import urllib.request

URL = os.environ["SUPABASE_URL"].rstrip("/")
KEY = os.environ["SUPABASE_SERVICE_KEY"]
TABLAS = ["configuracion_precios", "inventario_actual", "pedidos"]
PAGINA = 1000


def encabezados() -> dict:
    """Cabeceras de autenticación según el tipo de clave."""
    h = {"apikey": KEY, "Accept": "application/json"}
    # Las claves sb_secret_ no son JWT; las service_role antiguas sí.
    if KEY.startswith("eyJ"):
        h["Authorization"] = f"Bearer {KEY}"
    return h


def descargar(tabla: str) -> list:
    """Descarga todas las filas de ``tabla`` en páginas de 1000."""
    filas, desde = [], 0
    while True:
        endpoint = (
            f"{URL}/rest/v1/{tabla}?select=*&order=id.asc"
            f"&limit={PAGINA}&offset={desde}"
        )
        req = urllib.request.Request(endpoint, headers=encabezados())
        with urllib.request.urlopen(req, timeout=60) as r:
            pagina = json.load(r)
        filas.extend(pagina)
        if len(pagina) < PAGINA:
            return filas
        desde += PAGINA


def main() -> None:
    carpeta = pathlib.Path(f"respaldo_{datetime.date.today().isoformat()}")
    carpeta.mkdir(exist_ok=True)
    for tabla in TABLAS:
        filas = descargar(tabla)
        (carpeta / f"{tabla}.json").write_text(
            json.dumps(filas, ensure_ascii=False, indent=1), encoding="utf-8"
        )
        print(f"{tabla}: {len(filas)} filas")
    if not any((carpeta / f"{t}.json").stat().st_size > 2 for t in TABLAS):
        sys.exit("Todas las tablas vinieron vacías: revisa la clave.")


if __name__ == "__main__":
    main()