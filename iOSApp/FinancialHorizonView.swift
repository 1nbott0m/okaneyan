import SwiftUI
import SwiftData

struct FinancialHorizonView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("moneywise.hideAmounts") private var hideAmounts = false
    let snapshot: FinanceSnapshot
    let protectedTotals: ProtectedReserveTotals
    let namespace: Namespace.ID
    @State private var days = 14
    @State private var scenarioEnabled = false
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
        let projection = FinanceEngine().horizon(snapshot, days: days, hypotheticalPurchase: hypothetical)
        let hasReliablePointForecast = hasReliableForecast(projection.confidence)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(AppPalette.accent.gradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .modifier(FeatureMatchedGeometryModifier(id: "horizon-mark", namespace: namespace, enabled: !reduceMotion))
                        .padding(.bottom, 6)
                    Text("Деньги во времени")
                        .font(AppTypography.display(30, weight: .bold))
                    Text("Планируй спокойнее: видны подтверждённые платежи, поступления и защищённые суммы.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                rangePicker
                confidenceView(projection.confidence)
                projectionChart(projection, hasReliablePointForecast: hasReliablePointForecast)
                if scenarioEnabled && hasReliablePointForecast {
                    scenarioEditor(isApplied: projection.hypotheticalPurchase != nil)
                }
                projectionSummary
                eventDetails
                if !scenarioEnabled && hasReliablePointForecast {
                    Button {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.84)) {
                            scenarioEnabled = true
                            scenarioDate = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
                        }
                    } label: {
                        Label("Проверить покупку", systemImage: "slider.horizontal.3")
                            .font(AppTypography.ui(17, weight: .bold))
                            .frame(maxWidth: .infinity).padding(15)
                            .background(AppPalette.accent, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                Text("Это прогноз для планирования, а не обещание банка. Сценарий покупки не создаёт операцию и исчезает при выходе с экрана.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding(20)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(AppPalette.canvas)
        .navigationTitle("Финансовый горизонт")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var rangePicker: some View {
        HStack(spacing: 5) {
            ForEach(ranges, id: \.self) { range in
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.78)) { days = range }
                } label: {
                    Text(range == 1 ? "День" : "\(range) дн.")
                        .font(AppTypography.ui(13, weight: days == range ? .semibold : .medium))
                        .foregroundStyle(days == range ? Color.white : Color.secondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
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

    private func projectionChart(_ projection: FinancialHorizon, hasReliablePointForecast: Bool) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .firstTextBaseline) {
                Text(projection.hypotheticalPurchase == nil ? "Прогноз остатка" : "Сценарий покупки")
                    .font(AppTypography.ui(19, weight: .semibold))
                Spacer()
                if hasReliablePointForecast, let last = projection.points.last {
                    FinanceSensitiveAmount(value: last.projectedBalance.formatted)
                        .font(AppTypography.amount(17, weight: .semibold))
                }
            }
            if !hasReliablePointForecast {
                ContentUnavailableView("Точного графика пока нет", systemImage: "chart.xyaxis.line",
                    description: Text("Нужны свежий подтверждённый баланс и достаточно истории, чтобы оценить обычные расходы. Известные платежи смотри ниже."))
                    .frame(height: 190)
            } else if projection.points.isEmpty {
                ContentUnavailableView("Пока нечего прогнозировать", systemImage: "chart.xyaxis.line")
                    .frame(height: 180)
            } else {
                HorizonLineChart(points: projection.points)
                    .frame(height: 190)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(chartAccessibilityLabel(for: projection))
                HStack {
                    Text(projection.points.first?.date.formatted(date: .abbreviated, time: .omitted) ?? "")
                    Spacer()
                    Text(projection.points.last?.date.formatted(date: .abbreviated, time: .omitted) ?? "")
                }
                .font(.caption2).foregroundStyle(.secondary)
                projectionValues(projection.points)
            }
        }
        .padding(18)
        .background(AppPalette.surface, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 23, style: .continuous).stroke(AppPalette.line, lineWidth: 1))
    }

    private func projectionValues(_ points: [FinancialHorizon.Point]) -> some View {
        DisclosureGroup(isExpanded: $isShowingProjectionValues) {
            VStack(spacing: 0) {
                ForEach(points) { point in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text(point.date.formatted(date: .abbreviated, time: .omitted))
                                .font(AppTypography.detail(13, weight: .medium))
                            Spacer()
                            if point.isHypotheticalPurchaseDay {
                                Text("Покупка в сценарии")
                                    .font(.caption2).foregroundStyle(AppPalette.accent)
                            }
                        }
                        HStack {
                            Text("Баланс на конец дня")
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

    private func scenarioEditor(isApplied: Bool) -> some View {
        VStack(alignment: .leading, spacing: 15) {
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
        }
        .padding(18)
        .background(AppPalette.raisedSurface, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var projectionSummary: some View {
        VStack(spacing: 0) {
            horizonMetric("Сейчас на счетах", value: snapshot.currentBalance.formatted, symbol: "building.columns")
            Divider().overlay(AppPalette.line).padding(.leading, 42)
            horizonMetric("Минимальный резерв", value: snapshot.protectedReserve.formatted, symbol: "lock.shield")
            Divider().overlay(AppPalette.line).padding(.leading, 42)
            horizonMetric("Именные резервы", value: protectedTotals.named.formatted, symbol: "lock.fill")
            Divider().overlay(AppPalette.line).padding(.leading, 42)
            horizonMetric("Резерв целей", value: protectedTotals.goals.formatted, symbol: "scope")
            Divider().overlay(AppPalette.line).padding(.leading, 42)
            horizonMetric("Обычные расходы в день", value: snapshot.hasReliableSpendForecast ? snapshot.forecastDailySpend.formatted : "Нет оценки", symbol: "arrow.down.right")
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
                eventRow(item.title, date: item.dueDate, amount: item.amount, icon: "arrow.up.right", tint: AppPalette.accent)
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

    private func horizonMetric(_ title: String, value: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(AppPalette.softAccent).frame(width: 24)
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            FinanceSensitiveAmount(value: value).font(AppTypography.amount(15, weight: .semibold))
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

    var body: some View {
        GeometryReader { geometry in
            let values = points.map { Double($0.projectedBalance.kopecks) }
            let low = min(values.min() ?? 0, 0)
            let high = max(values.max() ?? 1, 1)
            let spread = max(1, high - low)
            ZStack {
                ForEach(1..<4) { line in
                    Path { path in
                        let y = geometry.size.height * CGFloat(line) / 4
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                    .stroke(AppPalette.line.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
                }
                chartPath(size: geometry.size, low: low, spread: spread, fill: true)
                    .fill(LinearGradient(colors: [AppPalette.softAccent.opacity(0.26), AppPalette.softAccent.opacity(0.01)], startPoint: .top, endPoint: .bottom))
                chartPath(size: geometry.size, low: low, spread: spread, fill: false)
                    .stroke(AppPalette.softAccent, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                if let purchaseIndex = points.firstIndex(where: \.isHypotheticalPurchaseDay) {
                    let x = xPosition(purchaseIndex, count: points.count, width: geometry.size.width)
                    Path { path in path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: geometry.size.height)) }
                        .stroke(AppPalette.accent.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    Circle().fill(AppPalette.accent).frame(width: 8, height: 8)
                        .position(x: x, y: yPosition(points[purchaseIndex], low: low, spread: spread, height: geometry.size.height))
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func chartPath(size: CGSize, low: Double, spread: Double, fill: Bool) -> Path {
        var path = Path()
        guard !points.isEmpty else { return path }
        for (index, point) in points.enumerated() {
            let p = CGPoint(x: xPosition(index, count: points.count, width: size.width),
                            y: yPosition(point, low: low, spread: spread, height: size.height))
            if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        if fill {
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
            path.closeSubpath()
        }
        return path
    }

    private func xPosition(_ index: Int, count: Int, width: CGFloat) -> CGFloat {
        count <= 1 ? width / 2 : CGFloat(index) / CGFloat(count - 1) * width
    }

    private func yPosition(_ point: FinancialHorizon.Point, low: Double, spread: Double, height: CGFloat) -> CGFloat {
        let normalized = (Double(point.projectedBalance.kopecks) - low) / spread
        return height - CGFloat(normalized) * (height * 0.88) - height * 0.06
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

    private var namedTotal: Money { protectedTotals.named }
    private var protectedTotal: Money { minimumReserve + protectedTotals.named + protectedTotals.goals }
    private var shortfall: Money { max(.zero, protectedTotal - balance) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(AppPalette.hero, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .modifier(FeatureMatchedGeometryModifier(id: "reserve-mark", namespace: namespace, enabled: !reduceMotion))
                        .padding(.bottom, 6)
                    Text("Оставь часть денег в покое")
                        .font(AppTypography.display(29, weight: .bold))
                    Text("Создай отдельные резервы под свои планы. Это внутреннее распределение денег, приложение не блокирует средства в банке. Если сумма уже записана как цель или плановый платёж, привяжи резерв к ней — расчёт не вычтет её дважды.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                balanceCard
                if shortfall > .zero {
                    Label("Защищённые суммы превышают текущий баланс на \(shortfall.formatted). Проверь суммы или обнови остатки.", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.medium)).foregroundStyle(.orange)
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
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
                Button { isAdding = true } label: {
                    Label("Создать резерв", systemImage: "plus")
                        .font(AppTypography.ui(17, weight: .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(15)
                        .background(AppPalette.accent, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                .buttonStyle(.plain)
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
                goals: goals, planItems: planItems, saveTitle: "Сохранить") { title, amount, goalID, planID, occurrenceDate in
                update(reserve, title: title, amount: amount, goalID: goalID, planID: planID, occurrenceDate: occurrenceDate)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let undoRecord {
                HStack(spacing: 12) {
                    Text(undoRecord.wasDeleted ? "Резерв удалён" : "Сумма резерва изменена")
                        .font(.subheadline.weight(.medium)).foregroundStyle(.white)
                    Spacer()
                    Button("Отменить") { undo(undoRecord) }
                        .font(.subheadline.weight(.bold)).foregroundStyle(AppPalette.softAccent)
                }
                .padding(.horizontal, 18).padding(.vertical, 14)
                .background(AppPalette.hero, in: Capsule())
                .padding(.horizontal, 16).padding(.bottom, 8)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .alert("Не удалось сохранить резерв", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("Понятно", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Всего защищено").font(.subheadline).foregroundStyle(.white.opacity(0.72))
                    FinanceSensitiveAmount(value: protectedTotal.formatted)
                        .font(AppTypography.amount(30, weight: .semibold)).foregroundStyle(.white)
                }
                Spacer()
                Image(systemName: "lock.shield.fill").font(.system(size: 22)).foregroundStyle(AppPalette.softAccent)
            }
            HStack {
                reserveBreakdown("Минимум", value: minimumReserve)
                Spacer()
                reserveBreakdown("Конверты", value: namedTotal)
                Spacer()
                reserveBreakdown("Цели", value: protectedTotals.goals)
            }
            Rectangle().fill(.white.opacity(0.12)).frame(height: 1)
            HStack {
                Text("Баланс счетов").font(.footnote).foregroundStyle(.white.opacity(0.65))
                Spacer()
                FinanceSensitiveAmount(value: balance.formatted).font(AppTypography.amount(13, weight: .semibold)).foregroundStyle(.white)
            }
        }
        .padding(19)
        .background(AppPalette.hero, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppPalette.softAccent.opacity(0.22), lineWidth: 1))
    }

    private func reserveBreakdown(_ title: String, value: Money) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption2).foregroundStyle(.white.opacity(0.55))
            FinanceSensitiveAmount(value: value.formatted).font(AppTypography.amount(12, weight: .semibold)).foregroundStyle(.white.opacity(0.9))
        }
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
        } catch { errorMessage = error.localizedDescription }
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
        } catch { errorMessage = error.localizedDescription }
    }

    private func delete(_ reserve: StoredProtectedReserve) {
        let backup = ProtectedReserveUndo(id: reserve.id, title: reserve.title, amountKopecks: reserve.amountKopecks,
            createdAt: reserve.createdAt, wasDeleted: true, linkedGoalID: reserve.linkedGoalID,
            linkedPlanItemID: reserve.linkedPlanItemID, linkedOccurrenceDate: reserve.linkedOccurrenceDate)
        do {
            try context.transaction { context.delete(reserve) }
            undoRecord = backup
        } catch { errorMessage = error.localizedDescription }
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
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct ProtectedReserveEditor: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let saveTitle: String
    let goals: [StoredGoal]
    let planItems: [StoredPlanItem]
    let onSave: (String, Money, UUID?, UUID?, Date?) -> Void
    @State private var name: String
    @State private var amountText: String
    @State private var target: ProtectedReserveTarget
    @State private var selectedGoalID: UUID?
    @State private var selectedPlanItemID: UUID?
    @State private var occurrenceDate: Date
    @State private var validationMessage: String?

    init(title: String, initialTitle: String, initialAmount: Money, initialGoalID: UUID?,
         initialPlanItemID: UUID?, initialOccurrenceDate: Date, goals: [StoredGoal],
         planItems: [StoredPlanItem], saveTitle: String,
         onSave: @escaping (String, Money, UUID?, UUID?, Date?) -> Void) {
        self.title = title
        self.saveTitle = saveTitle
        self.goals = goals
        self.planItems = planItems
        self.onSave = onSave
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
                    Text("Чтобы освободить часть, укажи меньшую сумму. Разница вернётся в доступный остаток, сам баланс счёта останется прежним.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let validationMessage {
                    Section { Text(validationMessage).foregroundStyle(.red).font(.footnote) }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
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
                    .disabled(parsedAmount == nil || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
            case .income: "Подтверждённое поступление"
            }
        }
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
                        Text("Свободно сейчас").font(.caption).foregroundStyle(.secondary)
                        if let freeCash {
                            FinanceSensitiveAmount(value: freeCash.formatted).font(AppTypography.amount(20, weight: .semibold))
                        } else {
                            Text("—").font(AppTypography.amount(20, weight: .semibold))
                        }
                    }
                }
                .padding(17)
                .background(AppPalette.surface)
                if freeCash == nil {
                    Label(freeCashExplanation, systemImage: "info.circle")
                        .font(.footnote).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Свободная сумма не рассчитана. \(freeCashExplanation)")
                }
                Picker("Представление", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                Group {
                    switch mode {
                    case .composition: compositionView
                    case .list: listView
                    }
                }
                .animation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.86), value: mode)
                Text("Категории могут пересекаться: резерв, цель и подтверждённый платёж не являются независимыми счетами и не складываются друг с другом.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(AppPalette.canvas)
        .navigationTitle("Структура денег")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedNode) { node in
            NavigationStack {
                VStack(alignment: .leading, spacing: 18) {
                    Image(systemName: node.kind.symbol).font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(AppPalette.accent).frame(width: 54, height: 54)
                        .background(AppPalette.softAccent.opacity(0.16), in: Circle())
                    Text(node.title).font(AppTypography.ui(25, weight: .semibold))
                    FinanceSensitiveAmount(value: node.amount.formatted)
                        .font(AppTypography.amount(32, weight: .semibold))
                    Text(node.kind.label).font(AppTypography.detail(13, weight: .medium))
                    Text("Эта сумма уже отражена в общем балансе. Она используется для планирования и не перемещается между банковскими счетами.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppPalette.canvas)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { selectedNode = nil } } }
            }
            .presentationDetents([.medium])
        }
    }

    private var compositionView: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Доступно после плана").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if let freeCash {
                    FinanceSensitiveAmount(value: freeCash.formatted).font(AppTypography.amount(20, weight: .semibold))
                } else {
                    Text("—").font(AppTypography.amount(20, weight: .semibold))
                }
            }
            .padding(.vertical, 14)
            Divider().overlay(AppPalette.line)
            ForEach(nodes) { node in
                Button { selectedNode = node } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(node.title).font(.subheadline)
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Rectangle().fill(AppPalette.line)
                                    Rectangle().fill(node.kind == .income ? AppPalette.muted : AppPalette.accent)
                                        .frame(width: geometry.size.width * share(for: node))
                                }
                            }
                            .frame(height: 2)
                            .accessibilityHidden(true)
                        }
                        Spacer(minLength: 10)
                        FinanceSensitiveAmount(value: node.amount.formatted)
                            .font(AppTypography.amount(15, weight: .semibold)).monospacedDigit()
                    }
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(node.title), \(node.amount.formatted)")
                .accessibilityHint("Открыть сведения о категории")
                Divider().overlay(AppPalette.line)
            }
            if nodes.isEmpty {
                Text("Категории появятся, когда будут добавлены резервы, цели или подтверждённые планы.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 16)
            }
        }
    }

    private func share(for node: FinancialGravityNode) -> CGFloat {
        let maximum = nodes.map { NSDecimalNumber(decimal: $0.amount.decimalRubles).doubleValue }.max() ?? 1
        guard maximum > 0 else { return 0 }
        let amount = NSDecimalNumber(decimal: node.amount.decimalRubles).doubleValue
        return max(0.035, min(1, CGFloat(sqrt(amount / maximum))))
    }

    private var listView: some View {
        VStack(spacing: 0) {
            if let freeCash {
                gravityRow(title: "Свободно сейчас", amount: freeCash, kind: .reserve, isFree: true)
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
                .accessibilityLabel("\(node.title), \(node.amount.formatted)")
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

private struct FinanceSensitiveAmount: View {
    @AppStorage("moneywise.hideAmounts") private var hideAmounts = false
    let value: String

    var body: some View {
        Text(hideAmounts ? "••••••" : value).monospacedDigit()
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
