MARK43 LOGO -- DROP THE OFFICIAL FILE HERE
==========================================

Put the official logo at:      tools/assets/mark43_logo.svg     (preferred)
                        or:    tools/assets/mark43_logo.png
                        or:    tools/assets/mark43_logo.jpg

render_officer_guide.ps1 picks it up automatically from then on -- every provider's guide, no
argument needed. It is embedded as a base64 data URI rather than linked, because the PDF is produced
by headless Edge and an external <img src> renders as a broken box in the printed sheet.
A one-off path can also be passed with -LogoFile <path>.

WHERE mark43_logo.png CAME FROM (added 2026-09-03)
-----------------------------------------------
The official files live in the All-Employees-Global SharePoint
(Shared Documents / Mark43 Brand / Mark43 Logo), which this tooling cannot reach. The Confluence
Brand Resources page (Marketing space, page 4462313473) is explicit:

    "Do not stretch or compress / Do not alter scale or alignment
     Do not use outlines or effects / Do not alter colors"

Hand-rolling an SVG lookalike would breach the very guideline it was meant to honour, so the header
currently carries the company NAME set in brand navy. That is text, not a logo, and breaches nothing.

FORMAT GUIDANCE, from the same page:
  .SVG  scales without quality loss -- ideal here, and smallest as a data URI
  .PNG  transparent background, larger file
  .EPS  print/vendor use -- NOT usable by this tool
Prefer SVG or PNG.

BRAND FACTS APPLIED BY THE GUIDE (all sourced from that page, none from memory)
------------------------------------------------------------------------------
  Palette   #24364E Dark Navy   #134DD1 Blue   #B4C7CF Grey
  Font      Arial -- the page assigns Archivo to website/marketing collateral and Arial to
            "all other internal and external docs and slides". An officer guide is the latter.
  Name      "Mark43" -- no space between Mark and 43, and never "M43", not even internally.

RESOLVED 2026-09-03 -- mark43_logo.png IS NOW PRESENT
-----------------------------------------------------
Source: https://mark43.com/wp-content/uploads/Mark43-Logo.png  (624 x 112 PNG, 5,193 bytes)
That is the logo Mark43 serves in the header of its own public website -- published by Mark43,
not redrawn, not traced, not approximated. It satisfies the brand rules by construction: nothing
is stretched, recoloured or outlined, because it is the file itself.

SharePoint remains the canonical library and holds the .SVG and .EPS masters. If you can drop the
SVG here it will supersede this PNG automatically -- the renderer prefers .svg, then .png, then .jpg.
