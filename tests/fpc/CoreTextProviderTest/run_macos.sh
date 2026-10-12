#!/bin/bash
# El proveedor de texto Core Text de macOS (rtl_fpc/rpinfoprovct.pas,
# docs/coretext_provider_plan.md), de principio a fin:
#
#   1. CoreTextProviderTest: caras, metricas, anchuras, kerning, fuente
#      incrustada y TextExtent (ligaduras, clusters, HTML, sustitucion...).
#   2. PdfTest con RP_TEXT_ENGINE=coretext: htmltest.rep y arab2wordwrap.rep
#      a PDF, y el texto que extrae PDFKit (el ToUnicode y las anchuras /W,
#      como cualquier visor) tiene las palabras arabes enteras.
#
# Despues de compilar los paquetes (packages/fpc/build_fpc.sh) en el Mac:
#   tests/fpc/CoreTextProviderTest/run_macos.sh
# Sale con 1 si algo falla. Los PDF quedan en tests/fpc/CoreTextProviderTest.
set -uo pipefail

DIR=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$DIR/../../.." && pwd)
T=${RM_MACOS_TOOLS:-$HOME/dev}
if ! command -v lazbuild > /dev/null && [ -f "$T/env.sh" ]; then
    . "$T/env.sh"
fi
fail=0

lazbuild --no-write-project "$DIR/CoreTextProviderTest.lpi" > "$DIR/build.log" 2>&1 || { echo "No compila CoreTextProviderTest (build.log)"; exit 1; }
lazbuild --no-write-project "$SRC/tests/fpc/PdfTest/PdfTest.lpi" > "$DIR/build_pdftest.log" 2>&1 || { echo "No compila PdfTest (build_pdftest.log)"; exit 1; }

echo "== CoreTextProviderTest"
(cd "$DIR" && ./CoreTextProviderTest > "$DIR/provider.log" 2>&1)
if [ $? -ne 0 ]; then
    grep -E "FAILED" "$DIR/provider.log"
    fail=1
fi
tail -1 "$DIR/provider.log"

pdf() {
    local rep=$1; shift
    echo "== $rep (Core Text)"
    (cd "$SRC/tests/fpc/PdfTest" && RP_TEXT_ENGINE=coretext ./PdfTest "$rep.rep" "$DIR/ct_$rep.pdf" > "$DIR/pdftest_$rep.log" 2>&1) || { echo "   PdfTest fallo (pdftest_$rep.log)"; fail=1; return; }
    swift "$DIR/pdftext.swift" "$DIR/ct_$rep.pdf" "$@" > "$DIR/text_$rep.log" 2>&1 || fail=1
    grep -E "CHECK" "$DIR/text_$rep.log"
}
pdf htmltest "الاستدلال" "تغادر" "inferencia"
pdf arab2wordwrap "المستندات" "الرقمية" "PDF"

if [ $fail -eq 0 ]; then
    echo "Core Text: todo correcto"
else
    echo "Core Text: hay fallos"
fi
exit $fail
