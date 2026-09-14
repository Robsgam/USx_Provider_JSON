# SC_SLED — DEX Ticket

**Active ticket:** NONE YET — no DEX ticket has been created for SC_SLED.
Project: DEX (CJIS/USx/DEx Implementation) · Tenant: **NONE — SC_SLED is installed nowhere.**

⚠️ **This provider has NO tenant.** Every other provider names a `usx-<provider>.mark43.com` tenant
here; SC_SLED has none, which is why it is the only provider in the portfolio whose **import**
lifecycle stage is unmet (`report_mission_status` row: `X X X X . . .` — every other incomplete
provider reads `. . X`). The tenant has to exist before a sweep can run, so the usual ordering
("a never-tested provider is owed a SWEEP, not an import", Rob 2026-09-09) is inverted here by
necessity.

**Jira is HELD** (Rob 2026-07-31) and lifts ONE PROVIDER AT A TIME. No ticket is owed for SC_SLED
until the hold lifts for it specifically — `enforce` PHASE 2r printing `[GAP] DEX_TICKET.md does
NOT name v1.0` is the EXPECTED steady state, not a defect, and must never be listed as owed work.

<!-- STAGE-5 MARKERS. Machine-read by tools\audit_lifecycle.ps1. One line per release, written ONLY
     when the post has been approved and actually made. The Jira comment id is the point: it is the
     one fact this repo cannot derive from itself, which is why the gate stopped accepting "the
     version appears somewhere in this file" as evidence (every DEX_TICKET.md names its own current
     version, so that check could not fail). Format, exactly:
         POSTED: v<X.Y> comment <id> <YYYY-MM-DD>                                                -->
(no POSTED marker — nothing has been posted, and nothing may be until the hold lifts)

## What a first release line will have to say

v1.0 is the first ground-up provider built since the toolchain changed. Three things belong in the
release line that are NOT ordinary build notes, because a reader would otherwise mistake them for
defects:

1. **Two queries co-fire by design-for-now.** A plate entry sends BOTH `QVRQ` ("SC Vehicle
   Stolen/Reg") and `QV` ("Stolen Vehicle"), so the stolen check goes out twice; a name+sex+DOB
   entry sends both `QWDQ` and `QWA.N`, so the wanted check goes out twice. Rob 2026-09-14:
   *"build both and we can sort it out."* Neither masking mechanism is available yet — see the
   build script.
2. **`AdministrativeMessage` is STATUS: HYPOTHESIS** — a 6th card and the only non-search
   transaction. The first import must confirm the five real entities still render.
3. **An OLN-only person search returns no wanted check.** That is SC's design (QWDQ requires the
   full name triple; QWA defines no OLN-mandatory branch), not a gap in this build.
