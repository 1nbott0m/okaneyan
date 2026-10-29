# Usability test matrix

**Runner:** Playwright against the local Chromium review preview. It is scripted interaction testing, not a study with participants.

## Viewports

| Viewport | Layout | Touch targets | Horizontal overflow | Screenshot |
|---|---|---|---|---|
| 320×844 | portrait narrow | pass | none | `screenshots/mobile/320.png` |
| 360×844 | compact Android width | pass | none | `screenshots/mobile/360.png` |
| 375×844 | compact iPhone width | pass | none | `screenshots/mobile/375.png` |
| 390×844 | iPhone width | pass | none | `screenshots/mobile/390.png` |
| 430×932 | large phone | pass | none | `screenshots/mobile/430.png` |
| 768×1024 | tablet | pass | none | `screenshots/mobile/768.png` |
| 1024×768 | tablet landscape / compact desktop | pass | none | `screenshots/mobile/1024.png` |
| 844×390 | phone landscape | pass | none | `screenshots/mobile/landscape-844x390.png` |
| 932×430 | phone landscape | pass | none | `screenshots/mobile/landscape-932x430.png` |
| 1440×900 | desktop | mouse layout pass | none | `screenshots/after/1440.png` |
| 1920×1080 | wide desktop | mouse layout pass | none | `screenshots/after/1920.png` |

## Action scenarios

| Scenario | Result |
|---|---|
| Find labeled balance and manual/reserve values | `PASS` — screen/AX content exposes labels, units and values. |
| Switch to Plan and return | `PASS` — Playwright confirmed Plan content active; transition may use View Transitions. |
| Expand/collapse balance breakdown and timeline | `PASS` — `aria-expanded` / `aria-hidden` update and reverse; all six synthetic rows appear; `416,500 − 180,000 − 136,000 − 40,000 − 18,000 = 42,500 ₽`; no horizontal overflow across tested viewports. |
| Switch theme; hide and restore amounts | `PASS` — theme token changes; amount text masks and restores. |
| Open add form | `PASS` — first focus to amount field; empty form is invalid. |
| Keyboard tab / reverse tab / Escape | `PASS` — focus stays inside dialog and returns to opener. |
| Add demonstration row | `PASS` — row and status toast appear; full reload clears the row. |
| Toast vs bottom navigation | `PASS` — rectangles do not overlap at 390×844. |
| Reduce motion | `PASS` — CSS computed disclosure/row transition `0s`; page animations remain suppressed by `0.00001s`. |
| Slow/offline/server error/retry | `NOT_APPLICABLE` — preview makes no network/API requests. |
| Empty operations / long localized strings / extreme balance | `UNTESTED` — data is fixed and no generated states were added. |
| Physical touch, one-handed reach, human task completion | `NOT_CONDUCTED` — no physical device/participants. |
