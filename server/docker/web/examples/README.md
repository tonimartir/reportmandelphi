# Imagenes derivadas con clientes de BD propietarios

La imagen base `tonimartir/reportman-web` ya incluye las librerias cliente
**libres** (apt), asi que FireDAC y Zeos conectan a estos backends sin pasos
extra:

| Base de datos | Protocolo Zeos (ej.) | Driver FireDAC | Paquete incluido |
|---|---|---|---|
| PostgreSQL | postgresql | PG | libpq5 |
| MySQL / MariaDB | mysql / mariadb | MySQL | libmariadb3 |
| Firebird | firebird-3.0 | FB | libfbclient2 |
| Interbase | interbase | IB | libfbclient2 |
| SQLite | sqlite | SQLite | libsqlite3-0 |
| MS SQL Server (FreeTDS) | mssql | (ODBC/TDBX) | freetds-bin, libsybdb5, tdsodbc |
| Sybase ASE | sybase | (ODBC) | freetds-bin, libsybdb5 |
| ODBC PostgreSQL / MySQL | odbc | ODBC | odbc-postgresql, odbc-mariadb |

> **Firebird**: `libfbclient2` es de licencia libre (IPL/MPL) y lo usan tanto el
> driver FireDAC FB como el protocolo `firebird` de Zeos. Va incluido en la base.

Los clientes **propietarios** no se incluyen (licencia / descarga manual). Se
anaden en una imagen derivada `FROM tonimartir/reportman-web`:

| Cliente | Fichero de ejemplo | Notas |
|---|---|---|
| Microsoft ODBC 18 (SQL Server) | `Dockerfile.mssql` | repo de Microsoft, acepta EULA automaticamente |
| Oracle Instant Client | `Dockerfile.oracle` | descarga el zip de Oracle (licencia) |
| IBM Db2 CLI | `Dockerfile.db2` | descarga el paquete de IBM (licencia) |
| Progress DataDirect (ODBC) | `Dockerfile.datadirect` | descarga el paquete Linux de Progress (licencia); registra el `.so` en `/etc/odbcinst.ini` (unixODBC) |

FireDAC y Zeos comparten las mismas `.so` nativas: instalar el cliente del
backend habilita ambos motores.

## Construir una imagen derivada

```bash
# Asegura la imagen base en local (o haz pull):
#   docker pull tonimartir/reportman-web:latest
docker build -f server/docker/web/examples/Dockerfile.mssql \
  -t reportman-web-mssql:latest \
  server/docker/web/examples
```

Para Oracle/Db2/DataDirect, deja primero el paquete descargado en esta carpeta
con el nombre que indica cada Dockerfile, y luego construye igual. DataDirect
expone drivers ODBC: el `.so` se registra en `/etc/odbcinst.ini` y Reportman
conecta por ODBC (protocolo Zeos `odbc` o FireDAC ODBC).

Si tu imagen base tiene otro nombre/tag (p.ej. la local `reportman-web:latest`),
pasalo con `--build-arg BASE_IMAGE=reportman-web:latest`.

Ejecuta la imagen derivada con los mismos puertos, variables y volumenes que la
base (ver el README principal).
