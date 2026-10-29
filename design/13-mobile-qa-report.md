# Mobile QA report

**Date:** 2026-10-29 · **Target:** static review preview · **Final status:** browser pass; G4 not accepted.

## Implemented and verified

- 44×44 CSS px visible hit areas on 320, 360, 375, 390, 430, 768, 1024, and phone landscape 844×390 / 932×430.
- Zero target intersections after animations settle; 8 px gap in concept and bottom navigation.
- No horizontal document overflow at all tested widths, including 1440 and 1920.
- Distinct portrait and phone-landscape compositions, visible labeled navigation.
- Safe-area env hooks for top, bottom and side insets.
- Required labels, decimal amount input, 16 px mobile input, dynamic-height scrollable dialog.
- Keyboard focus entry, trap, Escape close and focus return verified.
- Toast placed above nav.
- Reduced-motion CSS behavior verified.
- Expanded balance breakdown remains overflow-free at 320/360/390/430/768/1024/1440 and 844×390/932×430; disclosure button measures 44 px. Synthetic example arithmetic reconciles.
- WCAG text/control contrast sampled against actual light/dark tokens.
- Before/after screenshots saved.

## Unverified / not conducted

- Physical iPhone and Android: `NOT VERIFIED`; browser touch emulation is not real touch.
- Safari iOS, Chrome Android, Firefox and Safari macOS: `NOT VERIFIED`.
- Dynamic Island, Home Indicator, real system keyboard and device viewport changes: `NOT VERIFIED`.
- 200% text/browser zoom and full WCAG reflow: `NOT VERIFIED`.
- VoiceOver/TalkBack and axe-core scan: `NOT VERIFIED`.
- Long amounts, very long localized labels, empty/error/loading/server states: `UNTESTED` or `NOT_APPLICABLE` to static preview.
- Real-user usability: `NOT_CONDUCTED`.
- Lighthouse/Core Web Vitals and mobile animation performance: `NOT VERIFIED`.
- Native SwiftUI screens and data flows: `NOT VERIFIED` by browser screenshots.

**Acceptance:** the tested browser preview passes its measured viewport/touch/focus subset. The full Mobile Usability Acceptance and final G3 remain open because physical iOS/Android, zoom, assistive technology, independent review and human testing are not evidenced.

## Актуализация 29 октября 2026

- Приватность раскрытого денежного расчёта перепроверена после исправления: все 42 суммы маскируются; видимые строки валюты не остаются.
- Для landscape 844×390 / 932×430 добавлена компактная строка счёта и резерва, чтобы убрать найденное пересечение карточки с нижней навигацией. Конкретный ретест с viewport после этой правки `NOT RUN`; предыдущие landscape-строки выше не закрывают эту регрессию.
- Текущий браузер доступен в 1280×720; тема dark, выбран A. На этом экране перепроверены переходы разделов, light/dark с сохранением после reload, смена недели/месяца, раскрытие и приватность, открытие и закрытие демо-формы с фокусом суммы. Ошибок/предупреждений консоли нет.
- В том же 1280×720 обнаружено и исправлено наложение последней подписи денежного горизонта на нижнюю навигацию: верхние интервалы сокращены для высоты до 760 px. DOM-геометрия после обновления: край подписи 640 px, верх навигации 654 px, пересечения нет.
- Полный Xcode/симулятор отсутствует, iOS UI и device acceptance остаются `NOT VERIFIED`.

## Responsive ретест после шапки — 29 октября 2026

- Playwright повторно проверил Обзор / Операции / План на 320/360/375/390/430 px: 15 экранов, все цели ≥44×44 CSS px, 0 переполнений, 0 пересечений в доступной viewport-зоне, console errors: 0.
- Для 360–390 px все действия шапки находятся внутри её границ; короткая метка «ДЕМО» сохраняется.
- В 844×390 и 932×430 карточка ручного счёта заканчивается выше нижней навигации.
- Скриншоты: `outputs/moneywise-mobile-{overview,transactions,plan}-{320,360,375,390,430}.png`, `outputs/moneywise-landscape-844x390.png`, `outputs/moneywise-landscape-932x430.png`.
- По-прежнему не подтверждены физический iPhone, Safari, safe areas, клавиатура, VoiceOver и Dynamic Type.
