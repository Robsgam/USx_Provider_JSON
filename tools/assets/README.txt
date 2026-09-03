MARK43 LOGO -- DROP THE OFFICIAL FILE HERE
==========================================

Put the official logo at:      tools/assets/mark43_logo.svg     (preferred)
                        or:    tools/assets/mark43_logo.png
                        or:    tools/assets/mark43_logo.jpg

render_officer_guide.ps1 picks it up automatically from then on -- every provider's guide, no
argument needed. It is embedded as a base64 data URI rather than linked, because the PDF is produced
by headless Edge and an external <img src> renders as a broken box in the printed sheet.
A one-off path can also be passed with -LogoFile <path>.

WHY THERE IS NO FILE HERE YET, AND WHY NOTHING WAS DRAWN INSTEAD
---------------------------------------------------------------
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
