#!/bin/bash
# reptotxt -xml with the Linux64 binaries (run.ps1 -Linux runs it in an ubuntu:26.04 container, the
# repository in /r): the conversion of repman/repsamples (each one verified by
# reptotxt) and the PDFs of the DFM and of the XML of the reports that run without a database
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >/dev/null && apt-get install -y -qq libfreetype6 fontconfig fonts-dejavu-core libicu-dev libharfbuzz0b >/dev/null 2>&1
X=/r/repman/utils/reptotxt/binrl64/reptotxt
P=/r/repman/utils/printreptopdf/binrl64/printreptopdf
cp -r /r/repman/repsamples /tmp/rs && cd /tmp/rs
mkdir -p /tmp/out && "$X" -xml /tmp/rs /tmp/out | tail -1
norm() { LC_ALL=C sed -E "s/\(D:[0-9+Z'-]+\)/(D)/g; s/\/ID ?\[[^]]*\]/\/ID[]/g" "$1"; }
for r in arabonly sample4; do
  "$P" -q -u /tmp/rs/$r.rep /tmp/$r.dfm.pdf; a=$?
  "$P" -q -u /tmp/out/$r.rep /tmp/$r.xml.pdf; b=$?
  if [ -s /tmp/$r.dfm.pdf ] && cmp -s <(norm /tmp/$r.dfm.pdf) <(norm /tmp/$r.xml.pdf); then
    echo "$r: PDFs identical but the date and /ID (exit $a/$b, $(stat -c %s /tmp/$r.dfm.pdf) bytes)"
  else
    echo "$r: PDFs differ or missing (exit $a/$b)"
  fi
done
