# Touch-target audit

Method: Playwright DOM bounding rectangles for visible buttons, links, fields and ARIA button/tab roles after entry animations settled. Touch-area target is 44×44 CSS px. Icon art remains visually small inside larger button bounds.

| Viewport | Visible controls | Below 44×44 | Intersections | Document overflow |
|---|---:|---:|---:|---:|
| 320×844 | 13 | 0 | 0 | 0 px |
| 360×844 | 13 | 0 | 0 | 0 px |
| 375×844 | 13 | 0 | 0 | 0 px |
| 390×844 | 13 | 0 | 0 | 0 px |
| 430×932 | 13 | 0 | 0 | 0 px |
| 768×1024 | 14 | 0 | 0 | 0 px |
| 1024×768 | 14 | 0 | 0 | 0 px |
| 844×390 landscape | 14 | 0 | 0 | 0 px |
| 932×430 landscape | 14 | 0 | 0 | 0 px |

Key neighbor gaps: concept selector 8 px; mobile tab grid 8 px; top action buttons ≥8 px. Controls in normal transaction rows are not interactive.

1440×900 and 1920×1080 desktop have 14 controls below 44 px by design for mouse density; no touch-enabled desktop hardware was supplied. Mobile touch pass does not claim those targets are touch-safe.

Touch emulation and DOM geometry do not replace a real iPhone/Android tap-accuracy session.

## Последний responsive ретест — 29.10.2026

- Playwright повторно открыл Обзор, Операции и План при 320/360/375/390/430 px: 15 состояний, все интерактивные DOM-цели не меньше 44×44 CSS px, без горизонтального переполнения.
- В текущей видимой рабочей зоне нет перекрывающихся или частично закрытых целей; нижняя навигация не заслоняет доступные цели. Остальные секции страницы проверяются прокруткой, а не учитываются как одновременно видимые кнопки.
- Для 360–390 px найденное до этого обрезание Settings устранено: все три действия шапки находятся внутри её правой границы.
- В 844×390 и 932×430 карточка ручного счёта завершается выше фиксированной нижней навигации; горизонтального переполнения нет.
- Этот результат относится к web-preview и расчёту DOM-прямоугольников. Физическая точность попадания, iOS safe areas и native TabView остаются `NOT VERIFIED`.
