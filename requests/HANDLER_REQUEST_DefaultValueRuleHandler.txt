# Engineering Request: New Handler — DefaultValueRuleHandler

**Requested by:** Rob Sgambellone (rob.sgambellone@mark43.com)
**Date:** 2026-05-07
**Component:** HandlerConfiguration.java — ConnectCIC QIDM rule handler
**Priority:** Medium
**Scope:** New handler (small — follows existing handler pattern)

---

## Problem

When a user leaves a form field blank, the platform skips that QIDM attribute entirely during XML serialization. There is no way to provide a fallback value for blank fields at the QIDM level. The attribute is either sent with the user's value or not sent at all.

This creates a usability problem on every provider where blank vs. populated fields control query routing. The most common case: providers that route in-state queries differently from out-of-state queries based on whether the State field is populated. Officers must know to leave State blank for in-state searches. If they accidentally select their own state, the query routes as out-of-state and returns different results.

There is no platform mechanism to default a value at serialization time while still allowing user override. Form-level `initialValue` cannot be used because a pre-filled State field changes which query combination fires, breaking the routing logic entirely. This is documented internally as Limitation #30 and affects 9 of 18 active providers.

## Requested Behavior

A new rule handler, `DefaultValueRuleHandler`, with the following logic:

1. If the sourceField has a value (user entered or selected something), pass that value through unchanged.
2. If the sourceField is blank (user left the field empty), return `arguments[0]` as the attribute value.

The handler would be configured on a QIDM attribute the same way existing handlers are configured, with one argument specifying the default value.

## Dependency

This handler only works if the platform invokes rule handlers *before* deciding to skip blank-sourced attributes. If the platform checks for blank sourceFields first and skips the attribute without invoking the handler, the default value never executes.

**If this ordering is not currently the case, the handler requires a small change to the serialization pipeline:** invoke the handler first, then check whether the result is blank before deciding to skip. This is the critical implementation detail that determines feasibility.

## What This Solves

**Eliminates the "leave blank for in-state" usability problem.** The State field can remain empty on the form (preserving correct combo routing), while the handler fills in the provider's own state code at serialization time. The outbound XML always contains a State value. In-state queries send the home state automatically. Out-of-state queries send whatever the user selected. Officers no longer need to understand the routing implications of a blank field.

**Removes label-hint workarounds.** Nine providers currently display labels like "State (leave blank for XX)" to guide officers. With this handler, the label reverts to "State" and the system handles the defaulting silently.

**Enables server-side defaults without form-side effects.** Any field that should have a fallback value in XML but must remain optional on the form can use this handler. The form stays clean, combo routing stays correct, and the XML is always well-formed.

## Scope

One new handler class following the same pattern as `CommsysParseDateRuleHandler` and `FormatStringRuleHandler`. Single argument. No new dependencies. Registration in the existing handler map.

## Risk

Low for the handler itself. The serialization pipeline change (if needed) carries slightly more risk because it affects the order of operations for all attributes, but the impact is contained: handlers that return a non-blank value for a blank input would now cause the attribute to serialize, which is exactly the intended behavior. Existing handlers that only operate on non-blank inputs are unaffected because their blank-input behavior is unchanged (handler returns blank, attribute still skips).

## Verification

Configure a QIDM attribute with this handler and `arguments = ['defaultValue']`. Test two scenarios:

1. User enters a value on the form. The XML element should contain the user's value.
2. User leaves the field blank. The XML element should contain `'defaultValue'`.

If scenario 2 produces no XML element (attribute skipped), the serialization ordering needs the pipeline adjustment described above.
