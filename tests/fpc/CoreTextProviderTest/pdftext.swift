// The text a PDF viewer extracts from a PDF (PDFKit reads the ToUnicode of
// the fonts as any viewer): checks that the glyphs of ligatures and Arabic
// forms copy as their characters. Used by run_macos.sh.
//
//   swift pdftext.swift file.pdf [expected text]...
// Prints the text; exit code 1 when an expected text is missing.
import Foundation
import PDFKit

let args = CommandLine.arguments
guard args.count >= 2, let doc = PDFDocument(url: URL(fileURLWithPath: args[1])) else {
  print("cannot open the PDF")
  exit(2)
}
var text = ""
for i in 0..<doc.pageCount {
  text += doc.page(at: i)?.string ?? ""
}
print(text)
var missing = 0
for expected in args.dropFirst(2) {
  if text.contains(expected) {
    print("[CHECK OK]     the text has \"\(expected)\"")
  } else {
    print("[CHECK FAILED] the text has no \"\(expected)\"")
    missing += 1
  }
}
exit(missing == 0 ? 0 : 1)
