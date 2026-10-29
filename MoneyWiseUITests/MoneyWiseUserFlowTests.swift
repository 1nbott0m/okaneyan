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
}


extension MoneyWiseUserFlowTests {
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
}
