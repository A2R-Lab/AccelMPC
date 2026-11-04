#!/usr/bin/env python3
"""Redact every occurrence of a string from a PDF in place (true redaction, text removed)."""
import sys, pymupdf
path, needle = sys.argv[1], sys.argv[2]
doc = pymupdf.open(path)
n = 0
for page in doc:
    for rect in page.search_for(needle):
        page.add_redact_annot(rect, fill=(1, 1, 1))
        n += 1
    page.apply_redactions()
doc.set_metadata({})
doc.del_xml_metadata()
doc.save(path + ".tmp", garbage=4, deflate=True)
doc.close()
import os; os.replace(path + ".tmp", path)
assert n > 0, f"{needle!r} not found in {path}"
print(f"redacted {n} occurrence(s) of {needle!r} in {path}")
