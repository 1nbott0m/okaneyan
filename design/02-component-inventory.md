# Инвентаризация компонентов web preview

| Компонент | Варианты / состояния | Семантика / заметки |
|---|---|---|
| Боковая навигация | Overview / Operations / Plan; active; settings demo | `<nav aria-label>` + кнопки с текстом. В landscape phone скрыта, включается нижняя навигация. |
| Нижняя навигация | Overview / Operations / Plan; active | Подписи иконок присутствуют; `aria-label` у контейнера; target ≥44 CSS px в touch matrix. |
| Концепт-переключатель | A / B / C, `aria-pressed` | Только review-инструмент для арт-дирекшна, не production feature. |
| Theme / hide-amount actions | Toggle, меняющиеся доступные названия | Иконки имеют `aria-label`; hit-area 44×44 на touch viewport. |
| Balance card / horizon | Collapsed / expanded | Кнопка с `aria-expanded`; timeline имеет accessible label. |
| Data panels / transaction rows | Static, hover visual on desktop | Сам panel не является кнопкой; ссылки действий остаются явными. |
| Primary / secondary / link button | Normal / active / focus-visible | Семантические `<button>`; touch sizing for mobile/tablet. |
| Form fields | Required title / numeric amount; focus | Label wraps each input; amount uses `type=number`, `inputmode=decimal`, `autocomplete=off`; mobile font 16px. |
| Modal dialog | Open / invalid / success / Escape / close button / backdrop / focus trap | `role=dialog`, `aria-modal`, `aria-labelledby`; scrollable dialog capped to dynamic viewport. |
| Toast | Status announcement; success/demo notices | `role=status`, `aria-live=polite`; mobile toast positioned above bottom nav. |
| Progress bars | Static limit/goal visuals | Numeric amounts/percentages also appear as text; not interactive charts. |

**Наблюдение по реализации:** все варианты находятся в одном HTML-файле; есть централизованные CSS custom properties, но часть компонентных значений и demo-текстов остаётся inline. Это небольшой preview, не компонентная библиотека.
