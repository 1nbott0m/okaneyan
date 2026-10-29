import XCTest

final class MoneyWiseUserFlowTests: XCTestCase {
    @MainActor
    func testAccountAndTransactionPersistAfterRelaunch() throws {
        let app = XCUIApplication()
        app.launch()

        let accountsLink = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Счета и источники баланса"))
            .firstMatch
        XCTAssertTrue(accountsLink.waitForExistence(timeout: 20), "Обзор должен открыться")
        let initialAccountCountLabel = accountsLink.label
        guard let initialAccountCount = Int(initialAccountCountLabel.split(separator: ",").last?.trimmingCharacters(in: .whitespaces) ?? "") else {
            XCTFail("Не удалось определить число счетов из подписи: \(initialAccountCountLabel)")
            return
        }
        accountsLink.tap()

        let addAccountButton = app.buttons["Добавить счёт"]
        XCTAssertTrue(addAccountButton.waitForExistence(timeout: 5))
        addAccountButton.tap()

        let suffix = String(UUID().uuidString.prefix(8))
        let accountName = "Проверочный счёт \(suffix)"
        let accountNameField = app.textFields["Название счёта"]
        XCTAssertTrue(accountNameField.waitForExistence(timeout: 5))
        accountNameField.tap()
        accountNameField.typeText(accountName)

        let balanceField = app.textFields["Баланс, ₽"]
        balanceField.tap()
        balanceField.typeText("10000")
        app.buttons["Сохранить"].tap()

        XCTAssertTrue(app.staticTexts[accountName].waitForExistence(timeout: 5), "Счёт должен сохраниться в SwiftData")
        app.navigationBars.buttons.firstMatch.tap()

        let merchant = "Проверочная покупка \(suffix)"
        let addTransactionButton = app.buttons["Добавить операцию"]
        XCTAssertTrue(addTransactionButton.waitForExistence(timeout: 5))
        addTransactionButton.tap()

        let merchantField = app.textFields["Название"]
        XCTAssertTrue(merchantField.waitForExistence(timeout: 5))
        merchantField.tap()
        merchantField.typeText(merchant)
        let amountField = app.textFields["Сумма, ₽"]
        amountField.tap()
        amountField.typeText("350")
        app.buttons["Сохранить"].tap()

        XCTAssertTrue(app.staticTexts[merchant].waitForExistence(timeout: 10), "Покупка должна появиться на обзоре")

        app.terminate()
        app.launch()

        let refreshedAccountsLink = app.buttons.matching(NSPredicate(
            format: "label CONTAINS %@", "Счета и источники баланса, \(initialAccountCount + 1)"
        )).firstMatch
        XCTAssertTrue(refreshedAccountsLink.waitForExistence(timeout: 10), "Счёт должен обновить сводное число после перезапуска")
        refreshedAccountsLink.tap()
        XCTAssertTrue(app.staticTexts[accountName].waitForExistence(timeout: 10), "Счёт должен пережить перезапуск")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts[merchant].waitForExistence(timeout: 10), "Операция должна пережить перезапуск")
    }

    @MainActor
    func testCSVImportAndRepeatedStatementDeduplication() throws {
        let app = XCUIApplication()
        app.launchEnvironment["MONEYWISE_TEST_IMPORT_FIXTURE"] = "mw_import_fixture.csv"
        app.launch()
        let importButton = app.buttons["Импортировать операции"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 15))
        importButton.tap()
        XCTAssertTrue(app.navigationBars["Предпросмотр выписки"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Найдено операций: 1"].exists)
        XCTAssertTrue(app.staticTexts["CSV тест операция"].exists)
        let confirmImport = app.navigationBars.buttons["Импортировать"]
        XCTAssertTrue(confirmImport.waitForExistence(timeout: 8))
        XCTAssertTrue(confirmImport.isEnabled)
        confirmImport.tap()
        XCTAssertTrue(app.alerts["Импорт завершён"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.alerts.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Добавлено операций: 1")).firstMatch.exists)
        app.alerts.buttons["Понятно"].tap()

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["CSV тест операция"].waitForExistence(timeout: 10), "Импортированная операция должна сохраниться после перезапуска")
        importButton.tap()
        XCTAssertTrue(app.navigationBars["Предпросмотр выписки"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Уже в истории · пропущу при импорте"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Новые операции"].exists, "Повторная выписка должна быть распознана как уже импортированная")
        app.navigationBars.buttons["Отмена"].tap()
    }
}


extension MoneyWiseUserFlowTests {
    @MainActor
    func testPurchaseCheckIsReachableAndFailsClosedWithoutFinancialData() throws {
        let app = XCUIApplication()
        app.launch()

        let purchaseShortcut = app.buttons["Покупка"]
        XCTAssertTrue(purchaseShortcut.waitForExistence(timeout: 10), "Обзор должен давать доступ к проверке покупки")
        purchaseShortcut.tap()

        XCTAssertTrue(app.navigationBars["Проверка покупки"].waitForExistence(timeout: 8))
        let amount = app.textFields["Сумма в рублях"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText("500")
        app.buttons["Проверить"].tap()

        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Добавь баланс счёта")).firstMatch
            .waitForExistence(timeout: 8), "Без подтверждённого баланса и плана оценка должна быть осторожной")
    }

    @MainActor
    func testGoalBudgetAndDebtCreationPersistAfterRelaunch() throws {
        let app = XCUIApplication()
        app.launch()
        let planTab = app.tabBars.buttons["План"]
        XCTAssertTrue(planTab.waitForExistence(timeout: 10))
        planTab.tap()

        let goalTitle = "Тестовая цель"
        let addGoal = app.buttons["Добавить цель"]
        for _ in 0..<8 where !addGoal.isHittable { app.swipeUp() }
        XCTAssertTrue(addGoal.waitForExistence(timeout: 5))
        addGoal.tap()
        XCTAssertTrue(app.navigationBars["Новая цель"].waitForExistence(timeout: 5))
        let goalName = app.textFields["Например: новый телефон"]
        goalName.tap()
        goalName.typeText(goalTitle)
        let goalTarget = app.textFields["Сколько нужно, ₽"]
        goalTarget.tap()
        goalTarget.typeText("12000")
        let goalMonthly = app.textFields["Откладывать в месяц, ₽"]
        goalMonthly.tap()
        goalMonthly.typeText("1500")
        app.buttons["Сохранить"].tap()
        XCTAssertTrue(app.staticTexts[goalTitle].waitForExistence(timeout: 8), "Цель должна появиться в плане")

        let addBudget = app.buttons["Добавить бюджет"]
        for _ in 0..<8 where !addBudget.isHittable { app.swipeUp() }
        XCTAssertTrue(addBudget.waitForExistence(timeout: 5))
        addBudget.tap()
        XCTAssertTrue(app.navigationBars["Новый бюджет"].waitForExistence(timeout: 5))
        let budgetAmount = app.textFields["Лимит на месяц, ₽"]
        budgetAmount.tap()
        budgetAmount.typeText("5000")
        app.buttons["Сохранить"].tap()
        XCTAssertTrue(app.staticTexts["Продукты"].waitForExistence(timeout: 8), "Бюджет должен появиться в плане")

        let addDebt = app.buttons["Добавить долг"]
        for _ in 0..<8 where !addDebt.isHittable { app.swipeUp() }
        XCTAssertTrue(addDebt.waitForExistence(timeout: 5))
        addDebt.tap()
        XCTAssertTrue(app.navigationBars["Добавить долг"].waitForExistence(timeout: 5))
        let creditor = "Тестовый долг"
        let creditorField = app.textFields["Кому должен"]
        creditorField.tap()
        creditorField.typeText(creditor)
        let debtBalance = app.textFields["Остаток долга, ₽"]
        debtBalance.tap()
        debtBalance.typeText("3000")
        let payment = app.textFields["Платёж в месяц, ₽"]
        payment.tap()
        payment.typeText("500")
        app.buttons["Сохранить"].tap()
        XCTAssertTrue(app.staticTexts[creditor].waitForExistence(timeout: 8), "Долг должен появиться в плане")

        app.terminate()
        app.launch()
        planTab.tap()
        for _ in 0..<8 where !app.staticTexts[goalTitle].isHittable { app.swipeUp() }
        XCTAssertTrue(app.staticTexts[goalTitle].waitForExistence(timeout: 10), "Цель должна пережить перезапуск")
        for _ in 0..<8 where !app.staticTexts["Продукты"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["Продукты"].waitForExistence(timeout: 8), "Бюджет должен пережить перезапуск")
        for _ in 0..<8 where !app.staticTexts[creditor].isHittable { app.swipeUp() }
        XCTAssertTrue(app.staticTexts[creditor].waitForExistence(timeout: 8), "Долг должен пережить перезапуск")
    }

    @MainActor
    func testFinancialHorizonKeepsRangePickerUsableWithoutReliableHistory() throws {
        let app = XCUIApplication()
        app.launch()

        let horizonLink = app.buttons["Горизонт"]
        XCTAssertTrue(horizonLink.waitForExistence(timeout: 10), "Обзор должен показать вход в горизонт")
        horizonLink.tap()

        XCTAssertTrue(app.navigationBars["Финансовый горизонт"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Точного графика пока нет"].waitForExistence(timeout: 5),
                      "Без свежего баланса и достаточной истории нельзя показывать точечный прогноз")

        let sevenDayRange = app.buttons["7 дн."]
        XCTAssertTrue(sevenDayRange.waitForExistence(timeout: 5))
        sevenDayRange.tap()
        XCTAssertTrue(sevenDayRange.isSelected, "Выбранный диапазон должен объявляться доступности")

        let fourteenDayRange = app.buttons["14 дн."]
        XCTAssertTrue(fourteenDayRange.waitForExistence(timeout: 5))
        fourteenDayRange.tap()
        XCTAssertTrue(fourteenDayRange.isSelected)
        XCTAssertFalse(app.buttons["Значения прогноза по дням"].exists,
                       "Список дневных сумм не показывается без достоверных точек прогноза")
    }

    @MainActor
    func testDeleteAllDataRequiresTwoConfirmationsAndRemovesFinancialRecords() throws {
        let app = XCUIApplication()
        app.launch()

        let accountsLink = app.buttons.matching(NSPredicate(
            format: "label CONTAINS %@", "Счета и источники баланса"
        )).firstMatch
        XCTAssertTrue(accountsLink.waitForExistence(timeout: 15))
        accountsLink.tap()
        let addAccount = app.buttons["Добавить счёт"]
        XCTAssertTrue(addAccount.waitForExistence(timeout: 5))
        addAccount.tap()
        let suffix = String(UUID().uuidString.prefix(8))
        let accountName = "Удаляемый счёт \(suffix)"
        let name = app.textFields["Название счёта"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText(accountName)
        let balance = app.textFields["Баланс, ₽"]
        balance.tap()
        balance.typeText("2500")
        app.buttons["Сохранить"].tap()
        XCTAssertTrue(app.staticTexts[accountName].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()

        let configureButton = app.buttons["Настроить расчёт"]
        XCTAssertTrue(configureButton.waitForExistence(timeout: 5))
        configureButton.tap()

        let deleteButton = app.buttons["Удалить все данные на этом iPhone"]
        for _ in 0..<5 where !deleteButton.exists { app.swipeUp() }
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 8))
        deleteButton.tap()
        XCTAssertTrue(app.alerts["Подготовить удаление?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Продолжить"].tap()
        XCTAssertTrue(app.alerts["Удалить данные?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Отмена"].tap()
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "Отмена второго шага должна оставить экран настроек и данные")

        deleteButton.tap()
        app.alerts.buttons["Продолжить"].tap()
        XCTAssertTrue(app.alerts["Удалить данные?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Удалить всё"].tap()
        XCTAssertTrue(app.buttons["Горизонт"].waitForExistence(timeout: 10), "После очистки приложение должно вернуться на обзор")
        XCTAssertFalse(app.staticTexts[accountName].exists)
    }
}
