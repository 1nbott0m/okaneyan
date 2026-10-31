import SwiftUI
import SwiftData

struct FinancialHorizonView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("moneywise.hideAmounts") private var hideAmounts = false
    let snapshot: FinanceSnapshot
    let protectedTotals: ProtectedReserveTotals
    let namespace: Namespace.ID
    @State private var days = 14
    @State private var selectedPointIndex = 0
    @State private var projectionAnchor = Date.now
    @State private var scenarioEnabled = false
    @FocusState private var isScenarioAmountFocused: Bool
    @State private var scenarioAmount = ""
    @State private var scenarioDate = Date.now
    @State private var isShowingProjectionValues = false

    private let ranges = [1, 7, 14, 30, 90]
    private var hypothetical: HypotheticalPurchase? {
        guard scenarioEnabled, let rubles = Money.parseRubles(scenarioAmount), rubles > 0,
              Money.canRepresent(rubles: rubles) else { return nil }
        return HypotheticalPurchase(amount: Money(rubles: rubles), date: scenarioDate, title: "Покупка")
    }
    private func hasReliableForecast(_ confidence: FinancialHorizon.Confidence) -> Bool {
        if case .reliable = confidence { return true }
        return false
    }
    var body: some View {
        let baseline = FinanceEngine().horizon(snapshot, days: days, now: projectionAnchor)
        let projection = hypothetical == nil ? baseline : FinanceEngine().horizon(snapshot, days: days, hypotheticalPurchase: hypothetical, now: projectionAnchor)
        let hasReliablePointForecast = hasReliableForecast(projection.confidence)
        ScrollViewReader { scroll in
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.xyaxis.line")
                            .modifier(FeatureMatchedGeometryModifier(id: "horizon-mark", namespace: namespace, enabled: !reduceMotion))
                        Text("ГОРИЗОНТ").tracking(1.8)
                    }
                    .font(AppTypography.detail(12, weight: .semibold))
                    .foregroundStyle(AppPalette.softAccent)
                    .padding(.bottom, 8)
                    Text("Деньги во времени")
                        .font(AppTypography.display(30, weight: .bold))
                    Text("Выбери момент на графике: увидишь баланс, свободные деньги и события, которые их меняют.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                rangePicker
                confidenceView(projection.confidence)
                if hasReliablePointForecast {
                    if scenarioEnabled {
                        scenarioEditor(projection, baseline: baseline) { index in
                            isScenarioAmountFocused = false
                            selectedPointIndex = index
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                                scroll.scrollTo("horizon-projection", anchor: .top)
                            }
                        }
                    } else {
                        scenarioStartButton
                    }
                }
                projectionChart(projection, baseline: baseline, hasReliablePointForecast: hasReliablePointForecast)
                    .id("horizon-projection")
                projectionSummary
                eventDetails
                Text("Это прогноз для планирования, а не обещание банка. Сценарий покупки не создаёт операцию и исчезает при выходе с экрана.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding(20)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if isScenarioAmountFocused {
                    Spacer()
                    Button("Готово") { isScenarioAmountFocused = false }
                }
            }
        }
        .background(AppPalette.canvas)
        .navigationTitle("Финансовый горизонт")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { projectionAnchor = .now }
        }
        .onChange(of: snapshot.dataUpdatedAt) { _, _ in projectionAnchor = .now }
    }

    private var scenarioStartButton: some View {
        Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.84)) {
                scenarioEnabled = true
                scenarioDate = Calendar.current.date(byAdding: .day, value: 1, to: projectionAnchor) ?? projectionAnchor
            }
        } label: {
            Label("Проверить покупку", systemImage: "slider.horizontal.3")
                .font(AppTypography.ui(17, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 44).padding(10)
                .background(AppPalette.accent, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                .foregroundStyle(AppPalette.hero)
        }
        .buttonStyle(.plain)
    }

    private func firstPurchaseEffectIndex(_ projection: FinancialHorizon, baseline: FinancialHorizon) -> Int? {
        guard projection.hypotheticalPurchase != nil else { return nil }
        return projection.points.indices.first { index in
            baseline.points.indices.contains(index) &&
                projection.points[index].date == baseline.points[index].date &&
                projection.points[index].projectedBalance != baseline.points[index].projectedBalance
        }
    }

    private var rangePicker: some View {
        HStack(spacing: 5) {
            ForEach(ranges, id: \.self) { range in
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.78)) { days = range; selectedPointIndex = 0 }
                } label: {
                    Text(range == 1 ? "День" : "\(range) дн.")
                        .font(AppTypography.ui(13, weight: days == range ? .semibold : .medium))
                        .foregroundStyle(days == range ? AppPalette.hero : Color.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background {
                            if days == range {
                                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppPalette.accent)
                                    .matchedGeometryEffect(id: "horizon-range", in: rangeNamespace)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(days == range ? .isSelected : [])
            }
        }
        .padding(5)
        .background(AppPalette.raisedSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @Namespace private var rangeNamespace

    @ViewBuilder private func confidenceView(_ confidence: FinancialHorizon.Confidence) -> some View {
        Group {
            switch confidence {
            case .reliable:
                Label("Баланс подтверждён · оценка обычных расходов доступна", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            case .uncertain(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            case .insufficient(let message):
                Label(message, systemImage: "info.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.footnote)
    }

    private func projectionChart(_ projection: FinancialHorizon, baseline: FinancialHorizon, hasReliablePointForecast: Bool) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(projection.hypotheticalPurchase == nil ? "ПРОГНОЗ БАЛАНСА" : "СЦЕНАРИЙ ПОКУПКИ")
                .font(AppTypography.detail(12, weight: .semibold)).tracking(1.4)
                .foregroundStyle(.secondary)
            if hasReliablePointForecast, !projection.points.isEmpty {
                let index = min(max(0, selectedPointIndex), projection.points.count - 1)
                let point = projection.points[index]
                HStack {
                    Button { selectedPointIndex = max(0, index - 1) } label: {
                        Image(systemName: "chevron.left").frame(width: 44, height: 44)
                    }
                    .disabled(index == 0)
                    .accessibilityLabel("Предыдущая точка прогноза")
                    Spacer(minLength: 4)
                    Text(point.date.formatted(date: .abbreviated, time: .shortened))
                        .font(AppTypography.detail(14, weight: .medium))
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("horizon.selectedDate")
                    Spacer(minLength: 4)
                    Button { selectedPointIndex = min(projection.points.count - 1, index + 1) } label: {
                        Image(systemName: "chevron.right").frame(width: 44, height: 44)
                    }
                    .disabled(index == projection.points.count - 1)
                    .accessibilityLabel("Следующая точка прогноза")
                }
                .buttonStyle(.plain).foregroundStyle(AppPalette.softAccent)
                FinanceSensitiveAmount(value: point.projectedBalance.formatted)
                    .font(AppTypography.amount(34, weight: .semibold))
                    .accessibilityIdentifier("horizon.selectedBalance")
                HStack(alignment: .firstTextBaseline) {
                    Text("Свободно после резервов").font(.subheadline).foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    FinanceSensitiveAmount(value: point.availableAfterReserves.formatted)
                        .font(AppTypography.amount(17, weight: .semibold))
                }
            }
            if projection.hypotheticalPurchase != nil,
               !projection.points.isEmpty,
               let point = projection.points.dropFirst(min(max(0, selectedPointIndex), projection.points.count - 1)).first,
               let original = baseline.points.first(where: { $0.date == point.date }) {
                VStack(spacing: 10) {
                    comparisonRow("Без покупки", amount: original.projectedBalance, identifier: "horizon.baselineBalance")
                    comparisonRow("Изменение от покупки", amount: point.projectedBalance - original.projectedBalance,
                                  identifier: "horizon.scenarioDelta")
                    if point.projectedBalance < .zero {
                        Label("На выбранный момент баланс ниже нуля", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.medium)).foregroundStyle(.orange)
                            .accessibilityIdentifier("horizon.shortage")
                    }
                }
                .padding(.vertical, 8)
            }
            if !hasReliablePointForecast {
                ContentUnavailableView("Точного графика пока нет", systemImage: "chart.xyaxis.line",
                    description: Text("Нужны свежий подтверждённый баланс и достаточно истории, чтобы оценить обычные расходы. Известные платежи смотри ниже."))
                    .frame(height: 190)
            } else if projection.points.isEmpty {
                ContentUnavailableView("Пока нечего прогнозировать", systemImage: "chart.xyaxis.line")
                    .frame(height: 180)
            } else {
                HorizonLineChart(points: projection.points,
                                 baselinePoints: projection.hypotheticalPurchase == nil ? [] : baseline.points,
                                 selectedIndex: $selectedPointIndex)
                    .frame(height: 190)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(chartAccessibilityLabel(for: projection))
                    .accessibilityIdentifier("horizon.chart")
                    .accessibilityAdjustableAction { direction in
                        let index = min(max(0, selectedPointIndex), projection.points.count - 1)
                        switch direction {
                        case .increment: selectedPointIndex = min(projection.points.count - 1, index + 1)
                        case .decrement: selectedPointIndex = max(0, index - 1)
                        @unknown default: break
                        }
                    }
                    .accessibilityValue(hideAmounts ? "Суммы скрыты" : projection.points[min(max(0, selectedPointIndex), projection.points.count - 1)].date.formatted(date: .abbreviated, time: .shortened))
                HStack {
                    Text(projection.points.first?.date.formatted(date: .abbreviated, time: .omitted) ?? "")
                    Spacer()
                    Text(projection.points.last?.date.formatted(date: .abbreviated, time: .omitted) ?? "")
                }
                .font(.caption2).foregroundStyle(.secondary)
                HStack(spacing: 18) {
                    Label { Text(projection.hypotheticalPurchase == nil ? "Баланс" : "С покупкой") } icon: { Rectangle().fill(AppPalette.softAccent).frame(width: 18, height: 2) }
                    Label { Text(projection.hypotheticalPurchase == nil ? "После резервов" : "Без покупки") } icon: {
                        Rectangle().stroke(.secondary, style: StrokeStyle(lineWidth: 1, dash: [3, 2])).frame(width: 18, height: 2)
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
                if projection.hypotheticalPurchase == nil && projection.points.allSatisfy({ $0.projectedBalance == $0.availableAfterReserves }) {
                    Text("На этом отрезке обе линии совпадают.").font(.caption).foregroundStyle(.secondary)
                }
                selectedPointEvents(projection, baseline: baseline)
                projectionValues(projection.points, purchaseIndex: firstPurchaseEffectIndex(projection, baseline: baseline))
            }
        }
        .padding(.vertical, 18)
        .overlay(alignment: .top) { Rectangle().fill(AppPalette.line).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(AppPalette.line).frame(height: 1) }
    }

    @ViewBuilder private func selectedPointEvents(_ projection: FinancialHorizon, baseline: FinancialHorizon) -> some View {
        if !projection.points.isEmpty {
            let index = min(max(0, selectedPointIndex), projection.points.count - 1)
            let point = projection.points[index]
            VStack(alignment: .leading, spacing: 9) {
                Text(index == 0 ? "Начальная точка — подтверждённый баланс" : "От предыдущей точки до выбранной")
                    .font(.caption).foregroundStyle(.secondary)
                if index > 0 {
                    HStack {
                        Text("Поступления в модели").font(.subheadline)
                        Spacer(minLength: 8)
                        FinanceSensitiveAmount(value: point.confirmedInflows.formatted)
                            .font(AppTypography.amount(15, weight: .medium))
                    }
                    HStack {
                        Text("Списания в модели").font(.subheadline)
                        Spacer(minLength: 8)
                        FinanceSensitiveAmount(value: point.confirmedOutflows.formatted)
                            .font(AppTypography.amount(15, weight: .medium))
                    }
                    Text("Обычные расходы дополнительно учтены по оценке. Сценарная покупка, если задана, входит в списания модели.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if firstPurchaseEffectIndex(projection, baseline: baseline) == index {
                    Label("Здесь учтена покупка в сценарии", systemImage: "cart")
                        .font(.caption).foregroundStyle(AppPalette.softAccent)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func projectionValues(_ points: [FinancialHorizon.Point], purchaseIndex: Int?) -> some View {
        DisclosureGroup(isExpanded: $isShowingProjectionValues) {
            VStack(spacing: 0) {
                ForEach(points) { point in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text(point.date.formatted(date: .abbreviated, time: .shortened))
                                .font(AppTypography.detail(13, weight: .medium))
                            Spacer()
                            if let purchaseIndex, points[purchaseIndex].id == point.id {
                                Text("Покупка в сценарии")
                                    .font(.caption2).foregroundStyle(AppPalette.accent)
                            }
                        }
                        HStack {
                            Text("Баланс на момент прогноза")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Spacer(minLength: 8)
                            FinanceSensitiveAmount(value: point.projectedBalance.formatted)
                                .font(AppTypography.amount(15, weight: .semibold))
                        }
                        HStack {
                            Text("Свободно после резервов")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Spacer(minLength: 8)
                            FinanceSensitiveAmount(value: point.availableAfterReserves.formatted)
                                .font(AppTypography.amount(15, weight: .medium))
                        }
                    }
                    .padding(.vertical, 11)
                    .accessibilityElement(children: .combine)
                    if point.id != points.last?.id {
                        Divider().overlay(AppPalette.line)
                    }
                }
            }
            .padding(.top, 5)
        } label: {
            Label("Значения прогноза по дням", systemImage: "list.bullet")
                .font(AppTypography.ui(15, weight: .semibold))
        }
        .tint(AppPalette.accent)
        .accessibilityHint("Открывает прогнозируемый баланс и свободную сумму после резервов для каждого дня.")
        .padding(.top, 3)
    }

    private func scenarioEditor(_ projection: FinancialHorizon, baseline: FinancialHorizon,
                                onSelect: @escaping (Int) -> Void) -> some View {
        let isApplied = projection.hypotheticalPurchase != nil
        return VStack(alignment: .leading, spacing: 15) {
            HStack {
                Label("Покупка в сценарии", systemImage: "cart")
                    .font(AppTypography.ui(17, weight: .bold))
                Spacer()
                Button("Убрать") {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85)) {
                        scenarioEnabled = false
                        scenarioAmount = ""
                    }
                }
                .font(AppTypography.ui(15, weight: .semibold)).foregroundStyle(AppPalette.accent)
            }
            HStack(spacing: 10) {
                TextField("Сумма", text: $scenarioAmount)
                    .keyboardType(.decimalPad)
                    .font(AppTypography.amount(22, weight: .semibold))
                    .accessibilityLabel("Сумма гипотетической покупки")
                    .focused($isScenarioAmountFocused)
                Text("₽").font(AppTypography.amount(20, weight: .semibold)).foregroundStyle(.secondary)
            }
            .padding(14)
            .background(AppPalette.raisedSurface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            DatePicker("Дата покупки", selection: $scenarioDate, in: Date.now..., displayedComponents: .date)
                .datePickerStyle(.compact)
            Text(scenarioAmount.isEmpty ? "Введи сумму, чтобы увидеть её влияние на прогноз." :
                 (hypothetical == nil ? "Проверь сумму покупки: укажи число в рублях и копейках." :
                  (!isApplied ? "Дата покупки находится за пределами выбранного периода. Выбери более раннюю дату или увеличь горизонт." :
                   "Покупка учтена только в этой временной модели.")))
                .font(.footnote).foregroundStyle(.secondary)
            if let index = firstPurchaseEffectIndex(projection, baseline: baseline) {
                Button("Показать сравнение") { onSelect(index) }
                    .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                if let shortage = projection.points.firstIndex(where: { $0.projectedBalance < .zero }) {
                    Button("К первой нехватке") { onSelect(shortage) }
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.orange).frame(minHeight: 44)
                }
            }
        }
        .padding(18)
        .background(AppPalette.raisedSurface, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
        .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .top)))
    }

    private func comparisonRow(_ title: String, amount: Money, identifier: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            FinanceSensitiveAmount(value: amount.formatted)
                .font(AppTypography.amount(17, weight: .semibold))
                .accessibilityIdentifier(identifier)
        }
    }

    private var projectionSummary: some View {
        VStack(spacing: 0) {
            horizonMetric("Сейчас на счетах",
                          value: snapshot.bankBalances.isEmpty ? "Нет баланса" : snapshot.currentBalance.formatted,
                          symbol: "building.columns", isSensitive: !snapshot.bankBalances.isEmpty)
            Divider().overlay(AppPalette.line).padding(.leading, 42)
            horizonMetric("Минимальный резерв", value: snapshot.protectedReserve.formatted, symbol: "lock.shield")
            Divider().overlay(AppPalette.line).padding(.leading, 42)
            horizonMetric("Именные резервы", value: protectedTotals.named.formatted, symbol: "lock.fill")
            Divider().overlay(AppPalette.line).padding(.leading, 42)
            horizonMetric("Резерв целей", value: protectedTotals.goals.formatted, symbol: "scope")
            Divider().overlay(AppPalette.line).padding(.leading, 42)
            horizonMetric("Обычные расходы в день",
                          value: snapshot.hasReliableSpendForecast ? snapshot.forecastDailySpend.formatted : "Нет оценки",
                          symbol: "arrow.down.right", isSensitive: snapshot.hasReliableSpendForecast)
        }
        .padding(.horizontal, 16)
        .background(AppPalette.surface, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 21, style: .continuous).stroke(AppPalette.line, lineWidth: 1))
    }

    private var eventDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Подтверждённые события")
                .font(AppTypography.ui(19, weight: .semibold))
            let upcomingIncome = snapshot.incomes.filter { $0.date >= .now && $0.date < (Calendar.current.date(byAdding: .day, value: days, to: .now) ?? .distantFuture) }
            ForEach(upcomingIncome) { income in
                eventRow(income.isConfirmed ? "Подтверждённое поступление" : "Ожидаемое · не учтено в графике",
                         date: income.date, amount: income.amount, icon: income.isConfirmed ? "arrow.down.left" : "clock", tint: income.isConfirmed ? .green : .orange)
            }
            let shown = snapshot.scheduledItems.filter { $0.isConfirmed && $0.dueDate >= .now && $0.dueDate < (Calendar.current.date(byAdding: .day, value: days, to: .now) ?? .distantFuture) }.sorted { $0.dueDate < $1.dueDate }
            if shown.isEmpty && upcomingIncome.isEmpty {
                Text("На выбранном отрезке нет подтверждённых событий.")
                    .font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 8)
            }
            ForEach(shown) { item in
                let isDebtReturn = item.kind == .debtCollection
                eventRow(item.title, date: item.dueDate, amount: item.amount,
                         icon: isDebtReturn ? "arrow.down.left" : "arrow.up.right",
                         tint: isDebtReturn ? .green : AppPalette.accent)
            }
        }
        .padding(18)
        .background(AppPalette.surface, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 21, style: .continuous).stroke(AppPalette.line, lineWidth: 1))
    }

    private func eventRow(_ title: String, date: Date, amount: Money, icon: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(tint)
                .frame(width: 34, height: 34).background(tint.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.medium))
                Text(date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            FinanceSensitiveAmount(value: amount.formatted).font(AppTypography.amount(15, weight: .semibold))
        }
    }

    private func horizonMetric(_ title: String, value: String, symbol: String, isSensitive: Bool = true) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(AppPalette.softAccent).frame(width: 24)
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            if isSensitive {
                FinanceSensitiveAmount(value: value).font(AppTypography.amount(15, weight: .semibold))
            } else {
                Text(value).font(AppTypography.ui(15, weight: .medium)).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 13)
    }

    private func chartAccessibilityLabel(for projection: FinancialHorizon) -> String {
        guard let first = projection.points.first, let last = projection.points.last else { return "Нет точек прогноза" }
        let title = projection.hypotheticalPurchase == nil ? "Прогноз остатка" : "Сценарий покупки"
        guard !hideAmounts else {
            return "\(title) на \(days) дней. Значения по дням можно открыть списком под графиком."
        }
        return "\(title) на \(days) дней: от \(first.projectedBalance.formatted) до \(last.projectedBalance.formatted). Значения по дням можно открыть списком под графиком."
    }
}

private struct HorizonLineChart: View {
    let points: [FinancialHorizon.Point]
    let baselinePoints: [FinancialHorizon.Point]
    @Binding var selectedIndex: Int

    var body: some View {
        GeometryReader { geometry in
            let values = points.map { Double($0.projectedBalance.kopecks) } +
                (baselinePoints.isEmpty ? points.map { Double($0.availableAfterReserves.kopecks) }
                                        : baselinePoints.map { Double($0.projectedBalance.kopecks) })
            let low = min(values.min() ?? 0, 0)
            let high = max(values.max() ?? 1, 1)
            let spread = max(1, high - low)
            ZStack {
                ForEach(1..<4) { line in
                    Path { path in
                        let y = geometry.size.height * CGFloat(line) / 4
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }.stroke(AppPalette.line.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
                }
                seriesPath(size: geometry.size, low: low, spread: spread, available: false)
                    .stroke(AppPalette.softAccent, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                seriesPath(size: geometry.size, low: low, spread: spread, available: baselinePoints.isEmpty,
                           series: baselinePoints.isEmpty ? points : baselinePoints)
                    .stroke(Color.secondary, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [5, 4]))
                if low < 0 {
                    let zeroY = yPosition(.zero, low: low, spread: spread, height: geometry.size.height)
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: zeroY))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: zeroY))
                    }.stroke(Color.orange.opacity(0.65), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    Text("0 ₽").font(.caption2).foregroundStyle(.orange)
                        .position(x: 15, y: max(8, zeroY - 9))
                }
                // Event markers are data: confirmed cash flow or a hypothetical purchase.
                ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                    if point.confirmedInflows > .zero || point.confirmedOutflows > .zero {
                        Circle().fill(AppPalette.canvas)
                            .overlay(Circle().stroke(AppPalette.softAccent, lineWidth: 1.5))
                            .frame(width: 7, height: 7)
                            .position(x: xPosition(index, width: geometry.size.width),
                                      y: yPosition(point.projectedBalance, low: low, spread: spread, height: geometry.size.height))
                    }
                }
                if !points.isEmpty {
                    let index = min(max(0, selectedIndex), points.count - 1)
                    let x = xPosition(index, width: geometry.size.width)
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                    }.stroke(AppPalette.softAccent.opacity(0.5), lineWidth: 1)
                    Circle().fill(AppPalette.softAccent).frame(width: 9, height: 9)
                        .position(x: x, y: yPosition(points[index].projectedBalance, low: low, spread: spread, height: geometry.size.height))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { location in select(at: location.x, width: geometry.size.width) }
            .simultaneousGesture(DragGesture(minimumDistance: 10)
                .onChanged { value in
                    guard abs(value.translation.width) > abs(value.translation.height) * 1.15 else { return }
                    select(at: value.location.x, width: geometry.size.width)
                })
        }
    }

    private func select(at x: CGFloat, width: CGFloat) {
        guard !points.isEmpty, width > 0 else { return }
        selectedIndex = Int((min(1, max(0, x / width)) * CGFloat(points.count - 1)).rounded())
    }
    private func seriesPath(size: CGSize, low: Double, spread: Double, available: Bool,
                            series: [FinancialHorizon.Point]? = nil) -> Path {
        var path = Path()
        for (index, point) in (series ?? points).enumerated() {
            let value = available ? point.availableAfterReserves : point.projectedBalance
            let p = CGPoint(x: xPosition(index, width: size.width), y: yPosition(value, low: low, spread: spread, height: size.height))
            if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        return path
    }
    private func xPosition(_ index: Int, width: CGFloat) -> CGFloat {
        points.count <= 1 ? width / 2 : CGFloat(index) / CGFloat(points.count - 1) * width
    }
    private func yPosition(_ value: Money, low: Double, spread: Double, height: CGFloat) -> CGFloat {
        height - CGFloat((Double(value.kopecks) - low) / spread) * height * 0.88 - height * 0.06
    }
}

private struct ProtectedReserveUndo: Identifiable {
    let id: UUID
    let title: String
    let amountKopecks: Int64
    let createdAt: Date
    let wasDeleted: Bool
    let linkedGoalID: UUID?
    let linkedPlanItemID: UUID?
    let linkedOccurrenceDate: Date?
}

private enum ProtectedReserveTarget: String, CaseIterable, Identifiable {
    case independent = "Отдельный резерв"
    case goal = "Накопительная цель"
    case occurrence = "Плановый платёж"
    var id: String { rawValue }
}

struct ProtectedReservesView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("moneywise.hideAmounts") private var hideAmounts = false
    @Query(sort: \StoredProtectedReserve.createdAt) private var reserves: [StoredProtectedReserve]
    @Query(sort: \StoredGoal.title) private var goals: [StoredGoal]
    @Query(sort: \StoredPlanItem.dueDate) private var planItems: [StoredPlanItem]
    let balance: Money
    let minimumReserve: Money
    let protectedTotals: ProtectedReserveTotals
    let namespace: Namespace.ID
    @State private var editingReserve: StoredProtectedReserve?
    @State private var isAdding = false
    @State private var undoRecord: ProtectedReserveUndo?
    @State private var errorMessage: String?
    @State private var commitPulse = 0

    private var namedTotal: Money { protectedTotals.named }
    private var protectedTotal: Money { minimumReserve + protectedTotals.named + protectedTotals.goals }
    private var shortfall: Money { max(.zero, protectedTotal - balance) }
    private var shortfallWarning: String {
        hideAmounts
            ? "Защищённые суммы превышают текущий баланс. Проверь суммы или обнови остатки."
            : "Защищённые суммы превышают текущий баланс на \(shortfall.formatted). Проверь суммы или обнови остатки."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                            .modifier(FeatureMatchedGeometryModifier(id: "reserve-mark", namespace: namespace, enabled: !reduceMotion))
                        Text("ЗАЩИЩЕНО В ПЛАНЕ").tracking(1.4)
                    }
                    .font(AppTypography.detail(12, weight: .semibold)).foregroundStyle(AppPalette.softAccent)
                    .padding(.bottom, 8)
                    Text("Оставь часть денег в покое")
                        .font(AppTypography.display(29, weight: .bold))
                    Text("Резервы исключаются из свободных денег по плану. В банке деньги остаются на счёте.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                balanceCard
                if shortfall > .zero {
                    Label(shortfallWarning, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.medium)).foregroundStyle(.orange)
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                Button { isAdding = true } label: {
                    Label("Создать резерв", systemImage: "plus")
                        .font(AppTypography.ui(17, weight: .bold)).foregroundStyle(AppPalette.hero)
                        .frame(maxWidth: .infinity).padding(15)
                        .background(AppPalette.accent, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Твои конверты").font(AppTypography.ui(20, weight: .semibold))
                        Spacer()
                        Text("\(reserves.count)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    if reserves.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "tray").font(.system(size: 26)).foregroundStyle(AppPalette.softAccent)
                            Text("Пока нет отдельных резервов").font(AppTypography.ui(15, weight: .semibold))
                            Text("Добавь, например, «Ноутбук», «Отпуск» или «Подушка». Их суммы будут вычтены из свободного остатка.")
                                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 24)
                    } else {
                        ForEach(reserves) { reserve in
                            Button { editingReserve = reserve } label: {
                                reserveRow(reserve)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Изменить или освободить часть", systemImage: "slider.horizontal.3") { editingReserve = reserve }
                                Button("Удалить резерв", systemImage: "trash", role: .destructive) { delete(reserve) }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Удалить", systemImage: "trash", role: .destructive) { delete(reserve) }
                            }
                        }
                    }
                }
                .padding(18)
                .background(AppPalette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AppPalette.line, lineWidth: 1))
                Text("Изменения здесь влияют на расчёт свободных денег и прогноз. Баланс счёта и история операций не меняются.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(AppPalette.canvas)
        .navigationTitle("Резервы")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isAdding) {
            ProtectedReserveEditor(title: "Новый резерв", initialTitle: "", initialAmount: .zero,
                initialGoalID: nil, initialPlanItemID: nil, initialOccurrenceDate: .now,
                goals: goals, planItems: planItems, saveTitle: "Создать") { title, amount, goalID, planID, occurrenceDate in
                add(title: title, amount: amount, goalID: goalID, planID: planID, occurrenceDate: occurrenceDate)
            }
        }
        .sheet(item: $editingReserve) { reserve in
            ProtectedReserveEditor(title: "Резерв", initialTitle: reserve.title, initialAmount: reserve.amount,
                initialGoalID: reserve.linkedGoalID, initialPlanItemID: reserve.linkedPlanItemID,
                initialOccurrenceDate: reserve.linkedOccurrenceDate ?? .now,
                goals: goals, planItems: planItems, saveTitle: "Сохранить", onRelease: { delete(reserve) }) { title, amount, goalID, planID, occurrenceDate in
                update(reserve, title: title, amount: amount, goalID: goalID, planID: planID, occurrenceDate: occurrenceDate)
            }
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.55), trigger: commitPulse)
        .safeAreaInset(edge: .top, spacing: 0) {
            if let undoRecord {
                HStack(spacing: 12) {
                    Text(undoRecord.wasDeleted ? "Резерв удалён" : "Сумма резерва изменена")
                        .font(.subheadline.weight(.medium)).foregroundStyle(.white)
                    Spacer()
                    Button("Отменить") { undo(undoRecord) }
                        .font(.subheadline.weight(.bold)).foregroundStyle(AppPalette.softAccent)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("reserve.undo")
                }
                .padding(.horizontal, 18).padding(.vertical, 4)
                .background(AppPalette.hero, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppPalette.metalEdge.opacity(0.5), lineWidth: 1))
                .padding(.horizontal, 16).padding(.vertical, 8)
                .transition(reduceMotion ? .identity : .move(edge: .top).combined(with: .opacity))
            }
        }
        .alert("Не удалось сохранить резерв", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("Понятно", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("ВСЕГО ЗАЩИЩЕНО").font(AppTypography.detail(12, weight: .semibold)).tracking(1.5)
                        .foregroundStyle(AppPalette.heroMuted)
                    FinanceSensitiveAmount(value: protectedTotal.formatted)
                        .font(AppTypography.amount(32, weight: .semibold)).foregroundStyle(AppPalette.heroInk)
                        .accessibilityIdentifier("reserve.protectedTotal")
                }
                Spacer(minLength: 8)
                Image(systemName: "lock.fill").font(.system(size: 20, weight: .medium))
                    .foregroundStyle(AppPalette.softAccent).accessibilityHidden(true)
            }
            ReserveAllocationRail(balance: balance, amounts: [minimumReserve, namedTotal, protectedTotals.goals])
                .frame(height: 54)
                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.9), value: commitPulse)
                .accessibilityHidden(true)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top) {
                    reserveBreakdown("Минимум", value: minimumReserve, color: AppPalette.heroMuted)
                    Spacer()
                    reserveBreakdown("Конверты", value: namedTotal, color: AppPalette.softAccent)
                    Spacer()
                    reserveBreakdown("Цели", value: protectedTotals.goals, color: .white)
                }
                VStack(alignment: .leading, spacing: 12) {
                    reserveBreakdown("Минимум", value: minimumReserve, color: AppPalette.heroMuted)
                    reserveBreakdown("Конверты", value: namedTotal, color: AppPalette.softAccent)
                    reserveBreakdown("Цели", value: protectedTotals.goals, color: .white)
                }
            }
            Rectangle().fill(AppPalette.heroLine).frame(height: 1)
            HStack {
                Text("Баланс счетов").font(.footnote).foregroundStyle(AppPalette.heroMuted)
                Spacer(minLength: 8)
                FinanceSensitiveAmount(value: balance.formatted)
                    .font(AppTypography.amount(15, weight: .semibold)).foregroundStyle(AppPalette.heroInk)
            }
            HStack {
                Text("Вне резервов").font(.footnote).foregroundStyle(AppPalette.heroMuted)
                Spacer(minLength: 8)
                FinanceSensitiveAmount(value: max(.zero, balance - protectedTotal).formatted)
                    .font(AppTypography.amount(17, weight: .semibold)).foregroundStyle(AppPalette.heroInk)
                    .accessibilityIdentifier("reserve.outsideReserves")
            }
            Text("До учёта будущих платежей и обычных расходов.")
                .font(.caption).foregroundStyle(AppPalette.heroMuted)
        }
        .padding(20)
        .background(LinearGradient(colors: [Color(white: 0.18), AppPalette.hero, Color(white: 0.075)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(LinearGradient(colors: [AppPalette.metalHighlight.opacity(0.65), .black, AppPalette.metalEdge],
                                   startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
    }

    private func reserveBreakdown(_ title: String, value: Money, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 4, height: 4)
                Text(title).font(.caption).foregroundStyle(AppPalette.heroMuted)
            }
            FinanceSensitiveAmount(value: value.formatted)
                .font(AppTypography.amount(13, weight: .semibold)).foregroundStyle(AppPalette.heroInk)
        }
        .fixedSize(horizontal: true, vertical: true)
    }

    private func reserveRow(_ reserve: StoredProtectedReserve) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "circle.hexagongrid.fill").foregroundStyle(AppPalette.softAccent)
                .frame(width: 40, height: 40).background(AppPalette.softAccent.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(reserve.title).font(AppTypography.detail(15, weight: .medium)).foregroundStyle(.primary)
                Text(reserveTargetDescription(reserve)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            FinanceSensitiveAmount(value: reserve.amount.formatted).font(AppTypography.amount(15, weight: .semibold))
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
        }
        .padding(13)
        .background(AppPalette.raisedSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
    }

    private func reserveTargetDescription(_ reserve: StoredProtectedReserve) -> String {
        if let id = reserve.linkedGoalID, let goal = goals.first(where: { $0.id == id }) {
            return "Учитывается вместе с целью «\(goal.title)»"
        }
        if let id = reserve.linkedPlanItemID, let item = planItems.first(where: { $0.id == id }) {
            let date = reserve.linkedOccurrenceDate?.formatted(date: .abbreviated, time: .omitted) ?? "дата не выбрана"
            return "Для платежа «\(item.title)» · \(date)"
        }
        return "Отдельный резерв · можно изменить или освободить"
    }

    private func add(title: String, amount: Money, goalID: UUID?, planID: UUID?, occurrenceDate: Date?) {
        let reserve = StoredProtectedReserve(title: title, amount: amount, linkedGoalID: goalID,
            linkedPlanItemID: planID, linkedOccurrenceDate: occurrenceDate)
        do {
            try context.transaction { context.insert(reserve) }
            isAdding = false
            undoRecord = nil
            commitPulse &+= 1
        } catch { context.rollback(); errorMessage = error.localizedDescription }
    }

    private func update(_ reserve: StoredProtectedReserve, title: String, amount: Money,
                        goalID: UUID?, planID: UUID?, occurrenceDate: Date?) {
        let oldAmount = reserve.amountKopecks
        let oldTitle = reserve.title
        let oldGoalID = reserve.linkedGoalID
        let oldPlanID = reserve.linkedPlanItemID
        let oldOccurrenceDate = reserve.linkedOccurrenceDate
        guard oldAmount != amount.kopecks || oldTitle != title || oldGoalID != goalID || oldPlanID != planID || oldOccurrenceDate != occurrenceDate else { editingReserve = nil; return }
        do {
            try context.transaction {
                reserve.title = title; reserve.amountKopecks = amount.kopecks
                reserve.linkedGoalID = goalID; reserve.linkedPlanItemID = planID
                reserve.linkedOccurrenceDate = occurrenceDate
            }
            undoRecord = ProtectedReserveUndo(id: reserve.id, title: oldTitle, amountKopecks: oldAmount,
                createdAt: reserve.createdAt, wasDeleted: false, linkedGoalID: oldGoalID,
                linkedPlanItemID: oldPlanID, linkedOccurrenceDate: oldOccurrenceDate)
            editingReserve = nil
            commitPulse &+= 1
        } catch { context.rollback(); errorMessage = error.localizedDescription }
    }

    private func delete(_ reserve: StoredProtectedReserve) {
        let backup = ProtectedReserveUndo(id: reserve.id, title: reserve.title, amountKopecks: reserve.amountKopecks,
            createdAt: reserve.createdAt, wasDeleted: true, linkedGoalID: reserve.linkedGoalID,
            linkedPlanItemID: reserve.linkedPlanItemID, linkedOccurrenceDate: reserve.linkedOccurrenceDate)
        do {
            try context.transaction { context.delete(reserve) }
            undoRecord = backup
            editingReserve = nil
            commitPulse &+= 1
        } catch { context.rollback(); errorMessage = error.localizedDescription }
    }

    private func undo(_ record: ProtectedReserveUndo) {
        do {
            if record.wasDeleted {
                let restored = StoredProtectedReserve(id: record.id, title: record.title,
                    amount: Money(kopecks: record.amountKopecks), createdAt: record.createdAt,
                    linkedGoalID: record.linkedGoalID, linkedPlanItemID: record.linkedPlanItemID,
                    linkedOccurrenceDate: record.linkedOccurrenceDate)
                try context.transaction { context.insert(restored) }
            } else if let reserve = reserves.first(where: { $0.id == record.id }) {
                try context.transaction {
                    reserve.title = record.title; reserve.amountKopecks = record.amountKopecks
                    reserve.linkedGoalID = record.linkedGoalID; reserve.linkedPlanItemID = record.linkedPlanItemID
                    reserve.linkedOccurrenceDate = record.linkedOccurrenceDate
                }
            }
            undoRecord = nil
            commitPulse &+= 1
        } catch { context.rollback(); errorMessage = error.localizedDescription }
    }
}

private struct ReserveAllocationRail: View {
    let balance: Money
    let amounts: [Money]
    private let colors = [AppPalette.heroMuted, AppPalette.softAccent, Color.white]

    var body: some View {
        GeometryReader { geometry in
            let width = max(0, geometry.size.width - 8)
            let denominator = max(1, Double(balance.kopecks))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.75))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(LinearGradient(colors: [.black, .white.opacity(0.18)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
                HStack(spacing: 0) {
                    ForEach(amounts.indices, id: \.self) { index in
                        let previous = amounts.prefix(index).reduce(0.0) { $0 + max(0, Double($1.kopecks)) }
                        let start = min(1, previous / denominator)
                        let end = min(1, (previous + max(0, Double(amounts[index].kopecks))) / denominator)
                        ZStack {
                            Rectangle().fill(LinearGradient(colors: [colors[index].opacity(0.9), colors[index].opacity(0.45)],
                                                           startPoint: .top, endPoint: .bottom))
                            Canvas { context, size in
                                for x in stride(from: CGFloat(3), to: size.width, by: 4) {
                                    var rib = Path()
                                    rib.move(to: CGPoint(x: x, y: 5))
                                    rib.addLine(to: CGPoint(x: x, y: size.height - 5))
                                    context.stroke(rib, with: .color(.black.opacity(0.18)), lineWidth: 0.5)
                                }
                            }
                            Rectangle().strokeBorder(.white.opacity(0.16), lineWidth: 1)
                        }
                        .frame(width: max(0, width * CGFloat(end - start)))
                    }
                }
                .frame(height: max(0, geometry.size.height - 8))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .padding(4)
            }
        }
    }
}

private struct ProtectedReserveEditor: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let saveTitle: String
    let goals: [StoredGoal]
    let planItems: [StoredPlanItem]
    let onSave: (String, Money, UUID?, UUID?, Date?) -> Void
    let onRelease: (() -> Void)?
    @State private var confirmRelease = false
    @State private var name: String
    @State private var amountText: String
    @State private var target: ProtectedReserveTarget
    @State private var selectedGoalID: UUID?
    @State private var selectedPlanItemID: UUID?
    @State private var occurrenceDate: Date
    @State private var validationMessage: String?

    init(title: String, initialTitle: String, initialAmount: Money, initialGoalID: UUID?,
         initialPlanItemID: UUID?, initialOccurrenceDate: Date, goals: [StoredGoal],
         planItems: [StoredPlanItem], saveTitle: String, onRelease: (() -> Void)? = nil,
         onSave: @escaping (String, Money, UUID?, UUID?, Date?) -> Void) {
        self.title = title
        self.saveTitle = saveTitle
        self.goals = goals
        self.planItems = planItems
        self.onSave = onSave
        self.onRelease = onRelease
        _name = State(initialValue: initialTitle)
        _amountText = State(initialValue: NSDecimalNumber(decimal: initialAmount.decimalRubles).stringValue)
        _selectedGoalID = State(initialValue: initialGoalID ?? goals.first?.id)
        _selectedPlanItemID = State(initialValue: initialPlanItemID ?? planItems.first?.id)
        _occurrenceDate = State(initialValue: initialOccurrenceDate)
        _target = State(initialValue: initialGoalID.map { _ in .goal } ?? initialPlanItemID.map { _ in .occurrence } ?? .independent)
    }

    private var parsedAmount: Money? {
        guard let value = Money.parseRubles(amountText), value > 0, Money.canRepresent(rubles: value) else { return nil }
        return Money(rubles: value)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("О резерве") {
                    TextField("Название, например «Отпуск»", text: $name)
                    TextField("Сумма, ₽", text: $amountText).keyboardType(.decimalPad)
                    Picker("Учитывать как", selection: $target) {
                        ForEach(ProtectedReserveTarget.allCases) { Text($0.rawValue).tag($0) }
                    }
                    if target == .goal {
                        if goals.isEmpty { Text("Сначала создай накопительную цель.").font(.footnote).foregroundStyle(.secondary) }
                        else {
                            Picker("Цель", selection: $selectedGoalID) {
                                ForEach(goals) { goal in Text(goal.title).tag(Optional(goal.id)) }
                            }
                        }
                    } else if target == .occurrence {
                        if planItems.isEmpty { Text("Сначала добавь плановый платёж.").font(.footnote).foregroundStyle(.secondary) }
                        else {
                            Picker("Платёж", selection: $selectedPlanItemID) {
                                ForEach(planItems) { item in Text(item.title).tag(Optional(item.id)) }
                            }
                            DatePicker("Дата списания", selection: $occurrenceDate, displayedComponents: .date)
                            if let item = planItems.first(where: { $0.id == selectedPlanItemID }),
                               !ScheduledRecurrence.isOccurrence(occurrenceDate, of: item.scheduled) {
                                Text("Выбери дату одного из запланированных списаний.").font(.footnote).foregroundStyle(.orange)
                            }
                        }
                    }
                    Text("Связанный резерв не считается второй раз поверх цели или платежа. Для платежа выбирай дату конкретного списания; отдельный резерв учитывается полностью.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    Text("Уменьши сумму, чтобы освободить часть резерва. Связанные цели и платежи продолжат учитываться; итог свободных денег зависит от их сумм. Баланс счёта останется прежним.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if onRelease != nil {
                    Section {
                        Button("Освободить весь резерв", role: .destructive) { confirmRelease = true }
                        Text("Удаление можно отменить на экране резервов.").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if let validationMessage {
                    Section { Text(validationMessage).foregroundStyle(.red).font(.footnote) }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Освободить весь резерв?", isPresented: $confirmRelease, titleVisibility: .visible) {
                Button("Освободить резерв", role: .destructive) { onRelease?() }
                Button("Отмена", role: .cancel) { }
            } message: {
                Text("Запись резерва будет удалена. Связанные цели и платежи сохранятся и продолжат учитываться в плане. Баланс счёта не изменится.")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saveTitle) {
                        guard let amount = parsedAmount, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            validationMessage = "Введи название и положительную сумму в рублях и копейках."
                            return
                        }
                        let goalID = target == .goal ? selectedGoalID : nil
                        let planID = target == .occurrence ? selectedPlanItemID : nil
                        if target == .goal && !goals.contains(where: { $0.id == goalID }) {
                            validationMessage = "Выбери существующую цель."; return
                        }
                        if target == .occurrence {
                            guard let planID, let item = planItems.first(where: { $0.id == planID }),
                                  item.isConfirmed,
                                  ScheduledRecurrence.isOccurrence(occurrenceDate, of: item.scheduled) else {
                                validationMessage = "Выбери существующее плановое списание."; return
                            }
                        }
                        onSave(name.trimmingCharacters(in: .whitespacesAndNewlines), amount,
                            goalID, planID, planID == nil ? nil : occurrenceDate)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct FinancialGravityNode: Identifiable {
    enum Kind: Equatable {
        case minimum, reserve, goal, obligation, income

        var label: String {
            switch self {
            case .minimum: "Минимальная защита"
            case .reserve: "Именной резерв"
            case .goal: "Накопительная цель"
            case .obligation: "Подтверждённые платежи"
            case .income: "Будущие поступления"
            }
        }
        var explanation: String {
            switch self {
            case .income:
                "Эти будущие поступления ещё не входят в текущий баланс. Они влияют на прогноз в согласованные даты ближайших 30 дней."
            case .obligation:
                "Это подтверждённые плановые списания на ближайшие 30 дней. Они уменьшают прогноз в свои даты, а не означают уже проведённый расход."
            case .minimum:
                "Это общий защитный порог внутри текущего баланса. Он уменьшает свободную сумму по плану и не создаёт отдельный банковский счёт."
            case .reserve:
                "Это именные резервы внутри текущего баланса. Деньги остаются на счёте; связь с целями и платежами защищает от повторного вычитания."
            case .goal:
                "Это уже выделенные суммы для целей и связанных конвертов. Они учитываются в защите денег; цель и связанный резерв нельзя складывать повторно."
            }
        }
        var isFuture: Bool { self == .income || self == .obligation }

        var symbol: String {
            switch self {
            case .minimum: "lock.shield.fill"
            case .reserve: "circle.hexagongrid.fill"
            case .goal: "scope"
            case .obligation: "arrow.up.right"
            case .income: "arrow.down.left"
            }
        }
    }

    let id: String
    let title: String
    let amount: Money
    let kind: Kind
}

struct FinancialGravityView: View {
    private enum Mode: String, CaseIterable { case composition = "Состав", list = "Подробности" }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("moneywise.hideAmounts") private var hideAmounts = false
    let balance: Money
    let freeCash: Money?
    let freeCashExplanation: String
    let nodes: [FinancialGravityNode]
    let namespace: Namespace.ID
    @State private var mode: Mode = .composition
    @State private var selectedNode: FinancialGravityNode?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Куда направлены деньги")
                        .font(AppTypography.display(29, weight: .bold))
                    Text("Структура по реальному балансу, подтверждённым планам и твоим резервам.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Баланс счетов").font(.caption).foregroundStyle(.secondary)
                        FinanceSensitiveAmount(value: balance.formatted).font(AppTypography.amount(20, weight: .semibold))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Свободно по плану").font(.caption).foregroundStyle(.secondary)
                        if let freeCash {
                            FinanceSensitiveAmount(value: freeCash.formatted).font(AppTypography.amount(20, weight: .semibold))
                        } else {
                            Text("—").font(AppTypography.amount(20, weight: .semibold))
                        }
                    }
                }
                .padding(.vertical, 16)
                .overlay(alignment: .top) { Rectangle().fill(AppPalette.line).frame(height: 1) }
                .overlay(alignment: .bottom) { Rectangle().fill(AppPalette.line).frame(height: 1) }
                if freeCash == nil {
                    Label(freeCashExplanation, systemImage: "info.circle")
                        .font(.footnote).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Свободная сумма не рассчитана. \(freeCashExplanation)")
                }
                Text("Категории могут пересекаться: резерв, цель и подтверждённый платёж не являются независимыми счетами и не складываются друг с другом.")
                    .font(.footnote).foregroundStyle(.secondary)
                Picker("Представление", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                Group {
                    switch mode {
                    case .composition:
                        if dynamicTypeSize.isAccessibilitySize {
                            Text("Крупный текст: структура показана списком.").font(.footnote).foregroundStyle(.secondary)
                            listView
                        } else { compositionView }
                    case .list: listView
                    }
                }
                .animation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.86), value: mode)
            }
            .padding(20)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: 96).accessibilityHidden(true)
        }
        .background(AppPalette.canvas)
        .navigationTitle("Структура денег")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedNode) { node in
            NavigationStack {
                ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    GravityMaterialObject(tint: tint(for: node.kind), diameter: 68)
                        .overlay(Image(systemName: node.kind.symbol).font(.title3).foregroundStyle(.white)
                            .shadow(color: .black, radius: 1)).accessibilityHidden(true)
                    Text(node.title).font(AppTypography.ui(25, weight: .semibold))
                    FinanceSensitiveAmount(value: node.amount.formatted)
                        .font(AppTypography.amount(32, weight: .semibold))
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .accessibilityIdentifier("gravity.detailAmount")
                    Text(node.kind.label).font(AppTypography.detail(13, weight: .medium))
                    Text(node.kind.explanation)
                        .font(.subheadline).foregroundStyle(.secondary)
                        .accessibilityIdentifier("gravity.nodeExplanation")
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(AppPalette.canvas)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { selectedNode = nil } } }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var compositionView: some View {
        VStack(alignment: .leading, spacing: 14) {
            if nodes.isEmpty {
                Text("Категории появятся, когда будут добавлены резервы, цели или подтверждённые планы.")
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                GeometryReader { geometry in
                    let origin = CGPoint(x: geometry.size.width * 0.5, y: geometry.size.height * 0.44)
                    ZStack {
                        ForEach(nodes) { node in
                            let location = position(for: node.kind, in: geometry.size)
                            Path { path in
                                path.move(to: origin)
                                path.addLine(to: CGPoint(x: location.x, y: location.y - 16))
                            }
                            .stroke(AppPalette.muted.opacity(0.8), style: StrokeStyle(lineWidth: 1,
                                dash: node.kind.isFuture ? [3, 5] : []))
                            .accessibilityHidden(true)
                        }
                        VStack(spacing: 5) {
                            Image(systemName: "building.columns").font(.title3)
                            Text("БАЛАНС").font(AppTypography.detail(10, weight: .semibold)).tracking(1)
                        }
                        .foregroundStyle(AppPalette.heroMuted)
                        .frame(width: 108, height: 76)
                        .background(AppPalette.hero, in: Ellipse())
                        .overlay(Ellipse().stroke(LinearGradient(colors: [AppPalette.metalHighlight.opacity(0.7),
                            AppPalette.metalEdge.opacity(0.15), AppPalette.metalEdge], startPoint: .topLeading,
                            endPoint: .bottomTrailing), lineWidth: 1))
                        .position(origin)
                        .accessibilityHidden(true)
                        ForEach(nodes) { node in
                            Button { selectedNode = node } label: {
                                VStack(spacing: 6) {
                                    GravityMaterialObject(tint: tint(for: node.kind), diameter: diameter(for: node))
                                        .overlay {
                                            if diameter(for: node) >= 24 {
                                                Image(systemName: node.kind.symbol).font(.system(size: 14, weight: .medium))
                                                    .foregroundStyle(.white).shadow(color: .black, radius: 1)
                                            }
                                        }
                                        .frame(width: 80, height: 80)
                                    Text(shortTitle(for: node.kind)).font(AppTypography.detail(12, weight: .medium))
                                        .foregroundStyle(.primary).frame(height: 24)
                                }
                                .frame(width: 100, height: 112)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(nodeAccessibilityLabel(for: node))
                            .accessibilityIdentifier("gravity.map.\(node.id)")
                            .accessibilityHint("Открыть точную сумму и её роль в плане")
                            .position(position(for: node.kind, in: geometry.size))
                        }
                    }
                }
                .frame(height: 350)
                HStack(spacing: 18) {
                    Label { Text("Защита денег") } icon: { Rectangle().fill(AppPalette.softAccent).frame(width: 16, height: 1) }
                    Label { Text("Будущие события") } icon: {
                        Rectangle().stroke(.secondary, style: StrokeStyle(lineWidth: 1, dash: [3, 3])).frame(width: 16, height: 1)
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
                Text("Площади объектов сравнивают суммы категорий, а не доли баланса. Нажми объект для точного значения.")
                    .font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("gravity.scaleExplanation")
            }
        }
    }

    private func diameter(for node: FinancialGravityNode) -> CGFloat {
        let maximum = max(1, nodes.map { Double($0.amount.kopecks) }.max() ?? 1)
        return CGFloat(sqrt(max(0, Double(node.amount.kopecks)) / maximum)) * 76
    }
    private func position(for kind: FinancialGravityNode.Kind, in size: CGSize) -> CGPoint {
        let unit: CGPoint
        switch kind {
        case .minimum: unit = CGPoint(x: 0.22, y: 0.18)
        case .reserve: unit = CGPoint(x: 0.78, y: 0.18)
        case .goal: unit = CGPoint(x: 0.16, y: 0.62)
        case .obligation: unit = CGPoint(x: 0.84, y: 0.62)
        case .income: unit = CGPoint(x: 0.5, y: 0.76)
        }
        return CGPoint(x: unit.x * size.width, y: unit.y * size.height)
    }
    private func shortTitle(for kind: FinancialGravityNode.Kind) -> String {
        switch kind {
        case .minimum: "Минимум"
        case .reserve: "Резервы"
        case .goal: "Цели"
        case .obligation: "Платежи"
        case .income: "Поступления"
        }
    }
    private func tint(for kind: FinancialGravityNode.Kind) -> Color {
        switch kind {
        case .minimum: AppPalette.heroMuted
        case .reserve: AppPalette.softAccent
        case .goal: .white
        case .obligation: AppPalette.accent
        case .income: AppPalette.metalHighlight
        }
    }

    private func nodeAccessibilityLabel(for node: FinancialGravityNode) -> String {
        hideAmounts ? "\(node.title), сумма скрыта" : "\(node.title), \(node.amount.formatted)"
    }

    private var listView: some View {
        VStack(spacing: 0) {
            if let freeCash {
                gravityRow(title: "Свободно по плану", amount: freeCash, kind: .reserve, isFree: true)
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(AppPalette.accent)
                        .frame(width: 34, height: 34).background(AppPalette.softAccent.opacity(0.14), in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Свободная сумма не рассчитана").font(.subheadline.weight(.medium))
                        Text(freeCashExplanation).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    Text("—").font(AppTypography.amount(15, weight: .semibold))
                }
                .padding(.vertical, 13)
                .accessibilityElement(children: .combine)
            }
            ForEach(nodes) { node in
                Divider().overlay(AppPalette.line).padding(.leading, 48)
                Button { selectedNode = node } label: {
                    gravityRow(title: node.title, amount: node.amount, kind: node.kind)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(nodeAccessibilityLabel(for: node))
                .accessibilityIdentifier("gravity.list.\(node.id)")
                .accessibilityHint("Открыть сведения о категории")
            }
        }
        .padding(.horizontal, 0)
        .background(AppPalette.surface)
    }

    private func gravityRow(title: String, amount: Money, kind: FinancialGravityNode.Kind, isFree: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isFree ? "sparkle" : kind.symbol)
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(AppPalette.accent)
                .frame(width: 34, height: 34).background(AppPalette.softAccent.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.medium))
                Text(isFree ? "После резервов, платежей и оценки расходов" : kind.label)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            FinanceSensitiveAmount(value: amount.formatted).font(AppTypography.amount(15, weight: .semibold))
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }

}

/// Static procedural material: node area is data; shadows and etched arcs establish depth.
private struct GravityMaterialObject: View {
    let tint: Color
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Ellipse().fill(Color.black.opacity(0.6))
                .frame(width: diameter * 0.86, height: diameter * 0.18)
                .blur(radius: diameter * 0.08).offset(y: diameter * 0.48 + 3)
            Circle().fill(RadialGradient(colors: [.white.opacity(0.92), tint.opacity(0.85),
                tint.opacity(0.38), .black], center: UnitPoint(x: 0.26, y: 0.18),
                startRadius: 0, endRadius: diameter * 0.94))
            Circle().stroke(AngularGradient(colors: [.white.opacity(0.7), .black.opacity(0.7),
                tint.opacity(0.4), .white.opacity(0.5)], center: .center), lineWidth: 0.7)
            Canvas { context, size in
                for index in 0..<6 {
                    var arc = Path()
                    arc.addArc(center: CGPoint(x: size.width * 0.5, y: size.height * 0.5),
                               radius: size.width * (0.32 + CGFloat(index) * 0.025),
                               startAngle: .degrees(195), endAngle: .degrees(295), clockwise: false)
                    context.stroke(arc, with: .color(.white.opacity(0.04)), lineWidth: 0.35)
                }
            }
            Ellipse().stroke(.white.opacity(0.35), lineWidth: 0.5)
                .frame(width: diameter * 0.30, height: diameter * 0.10)
                .rotationEffect(.degrees(-32)).offset(x: -diameter * 0.17, y: -diameter * 0.28)
        }
        .frame(width: diameter, height: diameter)
    }
}

private struct FinanceSensitiveAmount: View {
    @AppStorage("moneywise.hideAmounts") private var hideAmounts = false
    let value: String

    var body: some View {
        Text(hideAmounts ? "••••••" : value).monospacedDigit()
            .accessibilityLabel(hideAmounts ? "Сумма скрыта" : value)
    }
}

struct FeatureMatchedGeometryModifier: ViewModifier {
    let id: String
    let namespace: Namespace.ID
    let enabled: Bool

    @ViewBuilder func body(content: Content) -> some View {
        if enabled { content.matchedGeometryEffect(id: id, in: namespace) }
        else { content }
    }
}
