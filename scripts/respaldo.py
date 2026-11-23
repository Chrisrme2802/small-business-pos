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
import urllib.error
import urllib.request

URL = os.environ.get("SUPABASE_URL", "").strip().rstrip("/")
KEY = os.environ.get("SUPABASE_SERVICE_KEY", "").strip()
TABLAS = ["configuracion_precios", "inventario_actual", "pedidos"]
PAGINA = 1000


def validar_entorno() -> None:
    """Detiene el script con un mensaje claro si los secretos son incorrectos."""
    if not URL or not KEY:
        sys.exit(
            "Faltan secretos en GitHub -> "
            f"SUPABASE_URL: {'ok' if URL else 'VACÍO'} | "
            f"SUPABASE_SERVICE_KEY: {'ok' if KEY else 'VACÍO'} "
            "(revisa que el nombre esté escrito exactamente igual)."
        )
    if not KEY.startswith(("sb_secret_", "eyJ")):
        # Solo se imprime el prefijo, que no es sensible.
        sys.exit(
            f"La clave guardada empieza con '{KEY[:12]}...' y no parece una clave "
            "secreta (debe empezar con 'sb_secret_')."
        )
    print(f"Proyecto: {URL} | clave: {KEY[:10]}... ({len(KEY)} caracteres)")


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
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                pagina = json.load(r)
        except urllib.error.HTTPError as e:
            cuerpo = e.read().decode("utf-8", "replace")
            sys.exit(f"Error HTTP {e.code} al leer '{tabla}': {cuerpo}")
        filas.extend(pagina)
        if len(pagina) < PAGINA:
            return filas
        desde += PAGINA


def main() -> None:
    validar_entorno()
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