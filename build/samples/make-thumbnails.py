#!/usr/bin/env python3
"""Draws the thumbnails of the sample reports (samples/thumbnails/*.png):
the first page of each report, which the welcome dialog of the designers
shows next to the list.

    python make-thumbnails.py <samples folder> <report-to-PDF command>

The report is printed to PDF by a command line printer of Report Manager,
called as  <command> <report.rep> -pdf <file.pdf>  (the .NET printreportpdf,
for example), and the page is rasterized by pdftoppm (poppler-utils), through
WSL on Windows.
"""
import os
import subprocess
import sys
import tempfile

WIDTH = 600   # pixels; the dialog scales it down


def run_pdftoppm(pdf, png_base):
    args = ['pdftoppm', '-f', '1', '-l', '1', '-singlefile', '-png',
            '-scale-to-x', str(WIDTH), '-scale-to-y', '-1']
    if os.name == 'nt':
        def wsl_path(p):
            p = os.path.abspath(p).replace('\\', '/')
            return '/mnt/%s%s' % (p[0].lower(), p[2:])
        subprocess.run(['wsl.exe', '-e'] + args + [wsl_path(pdf), wsl_path(png_base)], check=True)
    else:
        subprocess.run(args + [pdf, png_base], check=True)


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    folder, printer = sys.argv[1], sys.argv[2]
    out = os.path.join(folder, 'thumbnails')
    os.makedirs(out, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for name in sorted(os.listdir(folder)):
            if not name.endswith('.rep'):
                continue
            base = os.path.splitext(name)[0]
            pdf = os.path.join(tmp, base + '.pdf')
            subprocess.run([printer, os.path.join(folder, name), '-pdf', pdf], check=True,
                           stdout=subprocess.DEVNULL)
            run_pdftoppm(pdf, os.path.join(out, base))
            print('%s: %d bytes' % (os.path.join(out, base + '.png'),
                                     os.path.getsize(os.path.join(out, base + '.png'))))
    return 0


if __name__ == '__main__':
    sys.exit(main())
