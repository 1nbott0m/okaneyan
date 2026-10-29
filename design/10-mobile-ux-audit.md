# Mobile UX & Usability audit

**Scope:** the local browser review preview, `preview/index.html`. The shipping app is iOS; this audit does not clear native app acceptance.

## Findings and corrections

| ID | Priority | Reproduction / issue | Correction | Retest |
|---|---|---|---|---|
| MUX-01 | P2 | At portrait 320–430 px the theme/privacy controls, concept choices and several actions were below 44 px. | Expanded hit areas to 44 CSS px; kept SVG artwork compact. | `VERIFIED`: 0 undersized targets at 320/360/375/390/430. |
| MUX-02 | P2 | At 844×390 and 932×430, desktop sidebar/layout remained visible and consumed phone landscape space. | Added landscape-phone layout with mobile nav, compact two-column content and safe-area-aware padding. | `VERIFIED`: no horizontal overflow; sidebar hidden, bottom navigation visible. |
| MUX-03 | P1 | Dialog opened and closed, but focus could return to document root after accessibility-triggered activation. | Capture click source explicitly; focus numeric input on next frame; trap Tab; restore focus on close. | `VERIFIED`: Playwright opened, cycled focus, escaped and returned to Add button. |
| MUX-04 | P2 | Muted text / input boundaries were weak on the light surface. | Raised muted and control-border tokens while preserving rose/soft matte palette. | `VERIFIED`: sampled text ≥4.7:1; field border ≥3.74:1 (light) and 3.43:1 (dark). |
| MUX-05 | P2 | Mobile numeric input used 12 px typography and risked Safari auto-zoom. | 16 px mobile/tablet input and decimal input mode. | `VERIFIED` computed CSS; Safari itself `NOT VERIFIED`. |
| MUX-06 | P2 | Success toast could cover bottom navigation. | Toast now sits above the navigation and remains 3.2 s. | `VERIFIED`: 390×844 toast/nav rectangles do not overlap. |
| MUX-07 | P3 | Timeline used inconsistent weekday label for 29 Oct 2026. | Changed Wednesday to Thursday. | `VERIFIED` in current source and screenshot. |

## Remaining risk

- Dynamic Island/Home Indicator insets are wired through CSS env values, but emulation returns zero and no physical iPhone is available: `NOT VERIFIED`.
- Real software keyboard, 200% zoom, VoiceOver/TalkBack, browser compatibility, real touch accuracy and one-handed usability are `NOT VERIFIED` / `NOT_CONDUCTED`.
- Loading/network/server/empty/error scenarios do not exist in this static-data demo and were not simulated.

## Обновление аудита · 29 октября 2026

- Повторно найдено неполное маскирование: часть сумм на горизонте, лимитах, целях и резерве оставалась видимой. Все денежные узлы добавлены к `.amount`; после раскрытия расчёта проверено: все 42 узла скрыты, незамаскированных видимых значений с `₽` нет.
- Матричный landscape-проход ранее выявил наложение карточки счёта на нижнюю навигацию в 844×390 и 932×430. Добавлена компактная двухколоночная композиция карточки и резерва (78 px). Повторный замер после этой правки ещё не проведён; MUX-02 снова открыт до ретеста.
- В 1280×720 DOM-замер обнаружил, что нижняя навигация задевала подпись денежного горизонта. Добавлен короткий экранный ритм для viewport высотой до 760 px; на этой же ширине пересечение больше не наблюдается (подпись заканчивается на 640 px, меню начинается на 654 px).
- Кнопки остаются увеличены до touch-размера. Но финальные размеры в landscape после последнего CSS override следует подтвердить браузерной матрицей, а не считать это доказанным только по CSS.

## Повторная приёмка responsive preview — 29 октября 2026

- MUX-02 закрыт для web-preview: на 844×390 и 932×430 компактная строка счёта завершается выше нижней навигации.
- MUX-08 найден и исправлен: при 360–390 px дата выталкивала кнопку настроек за границу шапки. Теперь дата заменяется короткой меткой «ДЕМО», а все три действия остаются видны.
- Playwright проверил Обзор / Операции / План при 320/360/375/390/430 px. 15 состояний прошли по целям ≥44×44 CSS px, отсутствию переполнения и пересечений в доступной области; консоль без ошибок.
- Web-preview часть аудита подтверждена; физическое устройство, экранная клавиатура, системные safe areas, VoiceOver, Dynamic Type и пользовательские сессии остаются `NOT VERIFIED`/`NOT CONDUCTED`.
