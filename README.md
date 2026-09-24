# Chattynator Monkeypatch

Chattynator Monkeypatch is a small compatibility addon that extends Chattynator:

- Each detected Chattynator window appears in EllesmereUI Unlock Mode and can be moved and resized there.
- Chat backgrounds can use either one solid RGBA color or a two-stop RGBA gradient.
- Copy Messages includes up to 1,000 messages, five times Chattynator 223's 200-message limit.

It does not replace or edit files in either dependency. Chattynator-facing assumptions are isolated in `Adapter.lua`, so an upstream layout change should normally require a small adapter update instead of a rewrite.

## Requirements

- Chattynator
- EllesmereUI core

EllesmereUI Chat is a separate chat replacement and should normally remain disabled when Chattynator is in use.

## Configuration

Open **Options > AddOns > Chattynator Monkeypatch**, or enter `/cmp`.

The color swatches open Blizzard's color picker. Enter a hex RGB value in that picker's **Hex** field, then use the separate opacity slider for alpha.

Gradient start means bottom in Vertical mode and left in Horizontal mode. Gradient end means top or right, respectively.

If you create another Chattynator window after login, use **Rescan** in the settings or `/cmp rescan`. Opening EllesmereUI Unlock Mode also triggers a rescan.

## Copying development output

Use Chattynator's usual Copy Messages button or `/copy`. The larger copy includes available addon prints and `/dump` output, with the same tab filters, timestamps, formatting, and message order as Chattynator. Wrapped or multiline messages can occupy more than one visible line.

The right-side scrollbar supports dragging, arrow buttons, and clicking the track to page through the text. Mouse-wheel scrolling and text selection still use the native copy box.

Left-drag the Copy Chat title bar to move the open window. Its position is saved automatically across reopening and `/reload`; no Unlock Mode is needed. Dragging is disabled during combat.

The copy box is filled once per request. Chat history retention and saving are unchanged, so already discarded messages cannot be recovered and dumps are not added to saved history.

If a larger copy request fails after an update, the addon falls back to Chattynator's normal copy behavior and prints a notice. An unrecognized copy interface is left untouched.

## Compatibility behavior

The addon discovers Chattynator windows at runtime and patches their rendered background texture. It keeps its own geometry as a fallback while also asking the detected window to persist its position and size when that capability is available.

If a future Chattynator update changes the window signature, `/cmp status` will report zero detected windows. The compatibility logic to update is contained in `Adapter.lua`.
