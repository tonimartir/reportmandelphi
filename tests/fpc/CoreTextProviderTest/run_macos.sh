#!/bin/bash
# El proveedor de texto Core Text de macOS (rtl_fpc/rpinfoprovct.pas,
# docs/coretext_provider_plan.md), de principio a fin:
#
#   1. CoreTextProviderTest: caras, metricas, anchuras, kerning, fuente
#      incrustada y TextExtent (ligaduras, clusters, HTML, sustitucion...).
#   2. PdfTest con RP_TEXT_ENGINE=coretext: htmltest.rep y arab2wordwrap.rep
#      a PDF, y el texto que extrae PDFKit (el ToUnicode y las anchuras /W,
#      como cualquier visor) tiene las palabras arabes enteras.
#   3. LclSnapshotTest (Core Text es el motor por defecto en macOS) y, para
#      sample4, bold, boldold, arab2wordwrap y htmltest, la vista previa contra
#      el PDF rasterizado (LclSnapshotTest/previewvspdf.swift): los glifos que
#      dibuja el PDF estan en la vista previa y al reves.
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
pdf htmltest "الاستدلال" "تغادر" "inferencia" "الجديد 1.0 بتحسين"
pdf arab2wordwrap "المستندات" "الرقمية" "PDF"

echo "== LclSnapshotTest y vista previa contra PDF"
SNAP="$SRC/tests/fpc/LclSnapshotTest"
if lazbuild --ws=cocoa --no-write-project "$SNAP/LclSnapshotTest.lpi" > "$DIR/build_snapshot.log" 2>&1 && swiftc -O -o "$DIR/previewvspdf" "$SNAP/previewvspdf.swift" > "$DIR/build_previewvspdf.log" 2>&1; then
    # Con un limite: una excepcion que llegara a la aplicacion abriria un dialogo modal
    (cd "$SNAP" && perl -e 'alarm 900; exec @ARGV' ./LclSnapshotTest > "$DIR/snapshot.log" 2>&1) || fail=1
    grep -E "ERROR|Test Results" "$DIR/snapshot.log"
    for rep in sample4 bold boldold arab2wordwrap htmltest; do
        line=$("$DIR/previewvspdf" "$SNAP/snapshot_$rep.png" "$SNAP/snapshot_${rep}_ref.pdf" 0.98 0.85 "$DIR/diff_$rep.png")
        if [ $? -ne 0 ]; then fail=1; echo "   $rep: FALLA, $line (diff_$rep.png)"; else echo "   $rep: $line"; fi
    done
else
    echo "   no compila (build_snapshot.log, build_previewvspdf.log)"
    fail=1
fi

if [ $fail -eq 0 ]; then
    echo "Core Text: todo correcto"
else
    echo "Core Text: hay fallos"
fi
exit $fail
