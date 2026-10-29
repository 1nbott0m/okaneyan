# Аудит соответствия требований Okaneyan

**Дата:** 29 октября 2026 · **Область:** утверждённые ТЗ и решения диалога, текущий SwiftUI-проект и responsive web-превью.
**Результат:** направление и основные сценарии согласованы; полного приёмочного соответствия пока нет.

## Сводка

| Требование из ТЗ и диалога | Статус | Основание |
|---|---|---|
| iOS — основной продукт, веб — только предпросмотр | `VERIFIED` по исходникам | Есть SwiftUI-приложение с локальной SwiftData и отдельная демо-страница. Веб-превью прямо помечает demo-значения, отсутствие банковской синхронизации и границу FinanceEngine. |
| Выбранный визуальный путь A · Editorial: матовый charcoal, приглушённая роза, светлая тема как опция | `VERIFIED` в вебе; `PARTIAL` в iOS runtime | Превью открыто в тёмной теме, переключение на светлую и сохранение после перезагрузки проверены. SwiftUI задаёт dark как исходную тему и поддерживает light/system. iOS Simulator недоступен. |
| Не менять базовый дизайн радикально; вернуть выразительную карточку счёта | `VERIFIED` в исходниках и вебе | Обзор сохраняет выбранную Editorial-композицию и содержит карточку ручного демо-баланса, ведущую к подробностям счетов. |
| Достаточно данных как в приложении | `PARTIAL` | Превью показывает остаток, денежный горизонт, платежи, операции, лимиты, цель, резерв, прогноз, счета и аналитику. Веб-цифры синтетические и не вычисляются FinanceEngine. |
| Сравнения D1/D2/D3, навигация, раскрытие расчёта, смена периода, форма и маскирование сумм работают | `VERIFIED` в Chromium preview | Переключены все три направления и разделы «Обзор/Операции/План», период расходов, форма открылась с фокусом в поле суммы; детализация открывается. При включённом скрытии все 61 видимый денежный узел замаскирован; актуальная полная матрица сообщает о 0 ошибках консоли. |
| Тема, кириллица, бренд и иконки | `PARTIAL` | `okaneyan.` и утверждённые Orbit O мастера сохранены. Пользователь назначил Oswald display/brand, Onest UI/amounts, Golos Text small detail; точные OFL файлы и глифы сверены, а веб-превью их загрузило в light/dark на 390/1440. Нативная смена иконок и рендер шрифтов не запускались без полного Xcode/Simulator. |
| Анимация должна быть авторской, сохранять существующую хореографию и быть связана с готовностью приложения | `PARTIAL` | Orbit O сохраняет исходное появление и readiness hook. После 2,9 секунды ожидания спутник непрерывно обходит орбиту; сигнал `RootView` запускает плавный возврат в точку и вход. Web десятисекундный сценарий проходит stub-проверку. SwiftUI только разобран парсером: запуск на симуляторе/устройстве, реальный FPS, покадровая оценка и DA-01…DA-25 для этой заставки ещё не подтверждены. |
| Mobile UX: минимум 44 px, без перекрытий/горизонтального скролла и с доступной навигацией | `PARTIAL` | После исправления шапки 15 экранов Обзора/Операций/Плана при 320/360/375/390/430 имеют цели ≥44×44 CSS px; активная область без пересечений, header controls видимы и переполнения нет. В коротких landscape 844×390 и 932×430 ручная карточка счёта не пересекает нижнюю навигацию. Нативные safe areas, VoiceOver и устройство не проверены. |
| Accessibility и полноценный пользовательский QA | `NOT VERIFIED` | Настоящие VoiceOver/TalkBack, системная клавиатура, физические устройства, 200% масштаб, axe и независимые пользователи не проверялись. |

## Исправления этого прохода

- Маскирование сумм ранее пропускало часть платежей, лимитов, разбивки, целей и резерва. Все числовые суммы помечены для маскирования; проверено на раскрытой детализации и всем текущем DOM.
- Удалён моноширинный fallback для CoFo Drifter: до получения лицензированных CoFo-файлов используется штатный системный sans-serif.
- Добавлена компактная двумерная раскладка карточки счёта и резерва для короткого landscape-экрана. Playwright повторно подтвердил на 844×390 и 932×430: карточка заканчивается до фиксированной нижней навигации; горизонтального переполнения нет.
- Обнаружено и исправлено обрезание кнопки настроек при ширине 360–390 px: на этих размерах шапка оставляет краткую отметку «ДЕМО» и скрывает дату. Повторная матрица подтвердила видимость всех header actions и отсутствие переполнения.

## Проверки и ограничения

- Текущий Chromium IAB: страница непустая (`okaneyan. — Personal Finance preview`), выбранные A и dark сохранены; навигация, смена периода, переключение темы с сохранением после перезагрузки, раскрытие и скрытие сумм проверены. Форма открылась и установила фокус на `amountInput`; закрытие работает. Console warnings/errors: нет.
- `swift build`: exit 0 с предупреждениями о недостающих путях текущих Command Line Tools. `swift run --skip-build moneywise-checks`: **316 PASS, 0 FAIL**. Это проверки локальной финансовой логики, не iOS UI acceptance.
- Последний Swift source pass: `swiftc -frontend -parse` прошёл для `MoneyWiseApp.swift` и `OkaneyanCinematicIntro.swift`. Он не type-check’ит iOS target.
- `swift test`: Swift package сообщает `no tests found`; проверочный набор проекта запускается отдельным executable `moneywise-checks`.
- iOS build/simulator: `NOT VERIFIED`. Установлены Command Line Tools, но `xcodebuild` сообщает, что нужен полный Xcode.
- Playwright responsive pass 2026-10-29: 15 комбинаций обзор/операции/план для 320/360/375/390/430 px; все цели не меньше 44×44 CSS px, header controls остаются внутри шапки, нет переполнения или console errors. Дополнительно 844×390 и 932×430: карточка счёта выше нижней навигации; документ не переполняет ширину.
- Регистр содержит 180 гипотез: 41 `VERIFIED`, 22 `NOT_APPLICABLE`, 117 `UNTESTED`. Это не эквивалент полного QA и не закрывает native/device acceptance.

## Осталось для полного соответствия

1. Запустить уже подключённую Orbit O хореографию в SwiftUI на симуляторе/устройстве и проверить readiness/reduced-motion путь.
2. Проверить физический iPhone, системные safe areas, клавиатуру, VoiceOver и Dynamic Type; web-preview замеры не заменяют этот native acceptance.
3. Собрать и запустить SwiftUI-приложение полным Xcode; проверить встроенные app icons, темы, типографику и startup на устройстве/симуляторе.
4. Получить лицензированные CoFo-файлы, если именно эти начертания должны отображаться в приложении, и проверить Cyrillic glyph coverage.

---

## Checkpoint: MoneyWise Design Research specification

**Дата:** 29 октября 2026 · **Статус:** промежуточная сверка, не итоговая приёмка. Основание — `MoneyWise_DESIGN_RESEARCH_TZ_2026.md`, фактический просмотр локального preview при доступной ширине 600 CSS px, три живых motion demos, текущие research-файлы и ограничение среды по Xcode/custom viewport. Статусы ниже описывают только текущие доказательства.

| ID | Статус | Текущее доказательство / что остаётся |
|---|---|---|
| DA-01 | `VERIFIED` | Фактические поверхности различены: SwiftUI/iOS — продукт, `preview/index.html` — синтетический web-просмотр. Ограничения записаны в `AGENTS.md`. |
| DA-02 | `PARTIAL` | `design/research/2026-source-index.md` теперь учитывает 45 напрямую осмотренных работ: 43 в четырёх целевых категориях (11 product/mobile, 11 editorial/brand, 10 motion, 11 type/material) и отдельно 2 live fintech-template demo. 36 уникальных source pages/demos/specimens имеют сохранённые captures. Права на шаблоны/шрифты и полная независимая проверка источников не закрыты; витрины приложений не выдаются за runtime. |
| DA-03 | `PARTIAL` | Требуемый количественный минимум выполнен по четырём категориям, но доказательства разного типа: product/mobile включает опубликованные store/case screens, motion включает только десять просмотренных browser demos; Florin/Tessel дополнены как отдельные interactive web-template demos. Это не подтверждает native app behavior или производительность. Японский сайт 三次元 The Classic просмотрен напрямую и включён в editorial/brand; пустой Orizon Dribbble по-прежнему исключён. |
| DA-04 | `PARTIAL` | В репозитории 50 reference cards; R-15–R-50 имеют сохранённые source/live/store/specimen captures и adaptation/rejection critique. Три новых карты — японская editorial-композиция и две fintech template demo — явно размечены как внутренний анализ; независимой критики всё ещё нет, поэтому G3/DA-22 и полный DA-04 не закрыты. |
| DA-05 | `PARTIAL` | В браузере реально активированы и осмотрены 10 live examples: Stillwet, shared-layout tabs, tilt, direct drag, accordion, shared-layout modal, notification stack, line graph, spring-follow cursor и iOS-like slider. По MoneyWise-превью сняты все четыре роли motion, включая Reduced Motion варианты для feedback/navigation/signature и state. Новый D1 perimeter glint работает только при прямом горизонтальном drag и прекращается на release; точные времена, keyboard paths, interruption, independent G3 и native performance остаются открытыми. |
| DA-06 | `PARTIAL` | D1/D2/D3 сравниваются на одном сценарии и сохраняют 7 500 ₽; D2 использует split readout, D3 — журнальную ленту. D1/A «Тихий горизонт» выбран по DEC-008; отдельная проверка выразительной различимости всех трёх вариантов и G3-критика не завершены. |
| DA-07 | `VERIFIED` | Soft Matte Fintech и композиция A «Тихий горизонт» утверждены в DEC-008; пользователь подтвердил сохранение тёмной версии с Living Card. Отвергнутые направления и границы зафиксированы в `design/02-art-direction.md` и `design/rejected-patterns.md`; D2/D3 остаются review-only. |
| DA-08 | `PARTIAL` | Принципы доступной суммы, подтверждённых/ожидаемых поступлений, маркера общего layout и optional-only tilt соотнесены с UX. D1 web Living Card получила сдержанный металлический край и короткий жестовый блик по DEC-008; материал не заходит на текст и не двигается в idle. Полный список приёмов/состояний и native render ещё не ревьюированы. |
| DA-09 | `PARTIAL` | Свежие кадры D1/A зафиксированы после owner feedback: на главной сохранена одна Living Card, ближайшие платежи, последние операции и две короткие сводки; повторяющаяся аналитика/планирование перемещены с entry surface. Уточнены подписи минимального порога (`180 000 ₽`) и агрегата защищённых сумм (`215 000 ₽`); ручной баланс теперь показан реестровой строкой без псевдокарты. Удалена повторная вертикальная подпись статуса дохода; дата, сумма и «ожидается» остались в контексте. Матрица проверила D1/D2/D3 на 390/768/1440. Native fidelity, полный визуальный регресс и независимая G3-критика не завершены. |
| DA-10 | `PARTIAL` | Операции и План проверены на web ширинах 320–430 и основные состояния на 390/768/1440 без обычного переполнения. Новый text-only стресс на 150/200% для Overview/Operations/Plan до ролевой типографической правки показывал пересечение текста суммы/строк/мобильной навигации при 200%; после правки названия операций и вкладки переносятся, но hero-сумма и некоторые подписи ещё ограничены. Кадры/диагностика записаны в `design/research/visual-gap-audit.md` и `outputs/moneywise-large-text-stress-report.json`. Это не iOS Dynamic Type и не закрывает нативный QA. Длинные переводы и полная light/dark матрица всех разделов не проверены. |
| DA-11 | `PARTIAL` | В web-preview и SwiftUI FinancialGravity использует редакционную ведомость состава с отдельным доступным остатком; Playwright matrix прошла три ширины. Swift package build, проверка Swift-синтаксиса и MoneyCore checks прошли после удаления мёртвых орбитальных helpers и переименования режима в `composition`. Нативный runtime и остальные экраны всё ещё требуют полного визуального обхода. |
| DA-12 | `PARTIAL` | Пользователь утвердил роли Oswald 500/600 / Onest UI+amounts / Golos Text detail; CSS и `AppTypography` используют эти роли, документы и source tokens обновлены. Web computed styles and the eight-state type study are recorded. Native app rendering/Dynamic Type are still unverified. |
| DA-13 | `PARTIAL` | Selected Google Fonts binaries are pinned to repository commit `9862abc066c9b83bf84c3e8ed1fc2d8d48f9bbf0`; exact SIL OFL 1.1 notices, SHA-256, `ЯяЁё ₽ № −1 000 000,50` coverage and variable axes are in `design/asset-provenance.md`. Chromium computed styles/load checks pass at 390/1440 in light/dark; Golos/Onest detail comparison is captured. App resources and runtime registration are implemented, but iOS target build and native glyph rendering remain unverified without Xcode/Simulator. CoFo files are still excluded. |
| DA-14 | `PARTIAL` | Общие бренд/цветовые принципы сохранены в текущем preview и концептах; соответствие всех трёх режимов в SwiftUI не просмотрено в симуляторе. |
| DA-15 | `PARTIAL` | В web-preview работают навигация, disclosure, маскирование, Horizon 7/30/90, гипотеза покупки без записи, Gravity, reserve release/undo и operation modal; account preview control gives the explicit iOS boundary and the manual balance is presented as a ledger entry. Updated labels distinguish the minimum threshold from the aggregate protected amount. Matrix passes after D1 overview cleanup. SwiftUI source preserves matched-geometry shortcuts and account add/edit through a new list route; the new native card gesture parses but touch runtime and iOS FPS are not verified without Xcode/Simulator. |
| DA-16 | `PARTIAL` | `prefers-reduced-motion` в web-preview проверен при disclosure, feedback, navigation, signature и D2 surface: состояния остаются доступны, переходы отключаются. SwiftUI root tabs, SensitiveAmount и startup intro теперь читают `accessibilityReduceMotion`; источник просмотрен, но поведение не запускалось на iOS device/Simulator, и это не объявляется native verification. |
| DA-17 | `PARTIAL` | Web-preview проверен на 320/360/375/390/430 px для Обзора, Операций и Плана (15 комбинаций), а также на 768/1440 px для основных направлений. В проверенных состояниях нет горизонтального переполнения; все видимые интерактивные цели на телефонах не меньше 44×44 CSS px. Native screenshot/QA, VoiceOver, системные safe areas, клавиатура и Dynamic Type остаются недоступны без полного Xcode/Simulator. |
| DA-18 | `PARTIAL` | Light/dark на трёх направлениях, тема с сохранением, hidden amounts, expanded disclosure, 7-дневный отрицательный forecast и empty transaction state проверены в web-preview. Пустой реестр проверен на 390/768/1440 в обеих темах; добавление скрывает empty message и показывает демо-операцию в истории. `1 000 000,50 ₽` проходит в одну строку на 390 px для D1/D2/D3 при базовом размере. Отдельный агрессивный web stress 200% показал переполнение/пересечение текста внутри элементов; он не эквивалентен Dynamic Type. Native error/empty screenshot, системный large text и длинные локализованные строки не проверены. |
| DA-19 | `PARTIAL` | Сохранены D1/D2/D3 кадры 390/768/1440, дополнительные theme/state captures и актуальные empty-state before/after кадры для web-preview; по каждому направлению есть 4.4-секундная запись раскрытия Living Card. Созданы motion клипы для feedback/navigation/state/signature с reduced-motion вариантами. Новый D1 glint имеет before/after в 390/1440 и обеих темах, плюс кадр активного жеста. Horizon/Gravity, purchase-scenario, reserve undo и modal states подтверждены. Нативные before/after, timing/FPS на устройстве и полный acceptance остаются открытыми. |
| DA-20 | `PARTIAL` | Для empty-state, D2 surface и двух D1 Living Card итераций сохранены G0 before-captures, reference/direction notes, G2 after-captures и G4. Rim жест/Reduce Motion/vertical scroll и удаление дублирующей надписи имеют отдельные браузерные сценарии; полная matrix 390/768/1440 повторно прошла. G3 независимой критики не выполнен; native G4 остаётся BLOCKED без iOS runtime. |
| DA-21 | `PARTIAL` | Три неизменённых Google Fonts variable binaries включены с SIL OFL 1.1 notices; exact hashes and upstream commit are recorded. No third-party imagery or implementation code was copied. CoFo remains unbundled/unlicensed; provenance of pre-existing brand exports and final native resource verification remain open. |
| DA-22 | `NOT TESTED` | Аргументированное сравнение есть, но независимой оценки по каждому критерию нет; оценка 4/5 не заявляется. |
| DA-23 | `PARTIAL` | В рамках дизайн-патча не менялись MoneyCore/FinanceEngine; веб-сценарий помечен demo. Сквозная сверка на iOS runtime после визуальных правок не запускалась. |
| DA-24 | `PARTIAL` | Добавлен root `AGENTS.md`, описаны gates и локальные asset/type ограничения. Их автоматическое соблюдение последующими PR и regression baselines ещё не доказано. |
| DA-25 | `PARTIAL` | Созданы промежуточный audit, visual QA matrix, gate checklist и self-review. Итоговый отчёт остаётся partial, пока пункты исследования, native/accessibility и независимой критики не закрыты. |

**Не закрыты количественные/качественные проверки:** DA-02…DA-06, DA-08…DA-10, DA-12…DA-25 имеют `PARTIAL`/`NOT TESTED` статусы в таблице. DA-07 подтверждён владельцем. DA-17 не является незакрытым пунктом пользовательского веб-preview: его ограничения относятся к iOS runtime, VoiceOver, safe areas и Dynamic Type. Полную проверку приложения нельзя объявлять завершённой до native и независимого QA.

## Продолжение аудита — 29 октября 2026

### Основной и сравнительный режимы preview

- `preview/index.html`: default URL оставляет D1/A «Тихий горизонт» и скрывает панель сравнения; `?compare=1` включает D1/D2/D3, а выбор направления сохраняет этот флаг в URL.
- Свежая Chromium-проверка на 390/768/1440: default D1, picker hidden; comparison D1/D2/D3 reachable; amount remains 7 500 ₽; zero overflow and console errors. Full regression matrix passed with forecast, hidden amounts, Reduce Motion, Gravity, reserve/Undo, theme persistence and modal focus checks.
- Before/after frames: `outputs/moneywise-picker-before-{390,768,1440}.png`, `outputs/moneywise-picker-default-after-{390,768,1440}.png`, `outputs/moneywise-picker-compare-after-{390,768,1440}.png`.
- Это подтверждает только web preview. D1 product direction is already owner-approved in DEC-008; no new choice was requested. G3 independent critique and native iOS remain incomplete.

### Палитра и единая Living Card

- `AppPalette` in `iOSApp/AppTypography.swift` now uses the light/dark hex roles in `design/05-design-system.md`, including `muted` referenced by Financial Gravity and restrained metal edge/highlight roles. The recurring checker `work/pw-audit/check-palette-contract.mjs` confirms 32 paired semantic values against CSS.
- The D1 web Living Card now uses the same graphite hero role and light foreground roles in both themes, matching its existing SwiftUI treatment by source-level value.
- `swiftc -frontend -parse` passed for affected SwiftUI sources, `swift build` exited 0 (with existing missing Command Line Tools framework-path warnings), and the latest `swift run --skip-build moneywise-checks` produced 328 PASS lines. Calculated hero contrast ratios are above 7.6:1 for primary, muted and rose roles in both themes; this calculation does not substitute for native accessibility inspection.
- Chromium captures and computed styles confirm the web card at 390/1440 in light/dark and expanded/collapsed states; captured files are listed in `design/visual-qa-matrix.md`. Full Xcode app-target build, simulator rendering, VoiceOver and native contrast remain unverified.

### Mobile Living Card density

- Baseline at 390 CSS px: 323 px card, feature launchers at y=690. After: 293 px, launchers at y=660. Both dark/light themes retain the same 7 500 ₽, next-income disclosure and three horizon markers.
- The browser check exercises 360/375/390/430/768/1440 widths in light and dark, disclosure and seven breakdown rows; no horizontal overflow or browser errors. Current full matrix and empty-state regression pass.
- Native `AvailableBalanceCard` received a small vertical-spacing reduction, but only Swift parsing was possible. Xcode/Simulator render, VoiceOver and Dynamic Type remain `BLOCKED` in this environment.

### D1 mobile destination spacing

- A fresh 390 px capture exposed a 204 px `.side-metrics` container around one visible 112 px row; an inherited second grid row left ~92 px blank and delayed the three destination links.
- Reset the D1 mobile grid to a single auto row. After capture: row 112 px, overview grid ends y=548, feature list starts y=568, and all three destination titles are above the fixed nav. The 1440 px layout is unchanged.
- Re-ran `work/pw-audit/moneywise-design-matrix-current.mjs`: all nine D1/D2/D3 × 390/768/1440 combinations, privacy/theme/reduced-motion, Horizon ranges, purchase projection, Gravity, reserve Undo and modal focus passed; no overflow or console errors. `check-palette-contract.mjs` confirms all 32 CSS/SwiftUI semantic color values match. Native was unchanged in this earlier pass; independent G3 and iOS runtime QA remain incomplete.

- Повторно сверены DA-01…DA-25, gate checklist и roadmap. Обнаружено и исправлено устаревшее резюме: оно называло DA-07 и DA-17 незакрытыми, хотя направление утверждено, а браузерная адаптивность проверена. Теперь остаточные пробелы сформулированы отдельно от выполненных web проверок.
- Проверено наличие полного Xcode: `xcodebuild -version` сообщает, что требуется Xcode; активен только `/Library/Developer/CommandLineTools`. Поэтому SwiftUI-target, симулятор, устройство, VoiceOver и Dynamic Type в этом окружении не могут получить статус runtime-verified.
- Самооценка `design/final-design-review.md` остаётся именно self-review; независимый G3 и DA-22 не подменены самооценкой.
- Дополнено исследование живыми кадрами Florin и Tessel (desktop/mobile) и 三次元 The Classic (desktop). Florin's illustrated bill-sharing button изменил демонстрационный статус `waiting` → `paid`, но это не реальный перевод; Tessel's four-step tour открыл approval-request screen, а результат `Approve` остался неподтверждён. Refero live styles search вернул `NO_SUBSCRIPTION`; выдача не использована.
- Fresh D1 baseline at 390/1440 exposed a 54–74 px comparison toolbar in default product view; this has now been removed from the default route and retained at the explicit `?compare=1` route. See current before/after captures and regression matrix above.
- Сверка выявила расхождение palette tokens между `05-design-system.md`, web D1 и SwiftUI; semantic contract теперь выровнен в исходниках и Living Card согласована между темами. Требуется полноценный iOS runtime для проверки native rendering и contrast; это остаётся `BLOCKED` без Xcode/Simulator.

