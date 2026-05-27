# Confluence — Announcements & Formatting

## Announcement / Doc Update

Normal prose, slightly more structured than Slack. Still casual. Use headers and bullets. No corporate boilerplate intro paragraphs.

## Header Reference Table

Every Confluence page starts with a 2-row × 4-column metadata table before any content or TOC:

| Ticket | `BP-XXXX` | Status | `STATUS LOZENGE` |
| Last Updated | `YYYY-MM-DD` | Owner | `Name` |

Use `ac:structured-macro ac:name="status"` for the status cell.
Colour mapping: Green = DONE/UNCHANGED, Yellow = IN PROGRESS, Blue = NEW, Red = BLOCKED.

## Images

Always centered. Wrap every image in `<p style="text-align: center;">`.

## Tables

Full-width with proportional columns. Use `data-layout="full-width"` on all `<table>` elements. Set explicit `style="width:XX%;"` on each `<th>`/`<td>` in the header row, proportional to expected content length.
