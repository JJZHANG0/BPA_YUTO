import XCTest

@MainActor
final class TravelJourneyTests: XCTestCase {
    func testSearchFavoriteAndSaveTrip() {
        let app = launchFresh(captureWelcome: true)
        capture(app, name: "01-Home")
        app.tabBars.buttons["发现"].tap()
        XCTAssertTrue(app.staticTexts["discover-title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["收藏鼓浪屿"].exists)
        capture(app, name: "02-Discover")
        app.tabBars.buttons["首页"].tap()

        let explore = app.buttons["explore-provinces"]
        reveal(explore, in: app)
        explore.tap()
        let province = app.buttons["province-上海"]
        XCTAssertTrue(province.waitForExistence(timeout: 8))
        capture(app, name: "03-ProvinceGrid")
        province.tap()
        XCTAssertTrue(app.staticTexts["上海景区"].waitForExistence(timeout: 5))
        app.tabBars.buttons["首页"].tap()

        let field = app.textFields["destination-search"]
        reveal(field, in: app, swipingUp: false)
        field.tap()
        field.typeText("西湖")
        app.buttons["搜索"].firstMatch.tap()
        let result = app.buttons["discover-place-西湖风景名胜区"]
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        capture(app, name: "04-SearchResults")
        result.tap()

        let favorite = app.buttons["收藏景区"]
        XCTAssertTrue(favorite.waitForExistence(timeout: 5))
        favorite.tap()
        XCTAssertTrue(app.buttons["已收藏"].exists)
        capture(app, name: "05-Destination")

        app.buttons["打开景区相册"].tap()
        XCTAssertTrue(app.buttons["关闭"].waitForExistence(timeout: 5))
        capture(app, name: "06-Album")
        app.buttons["关闭"].tap()

        let write = app.buttons["写评价"]
        reveal(write, in: app)
        write.tap()
        let review = app.textViews["review-text"]
        XCTAssertTrue(review.waitForExistence(timeout: 5))
        review.tap()
        let reviewText = "湖边走走，很舒服。"
        review.typeText(reviewText)
        app.buttons["保存评价"].tap()
        XCTAssertTrue(app.staticTexts[reviewText].waitForExistence(timeout: 5))
        reveal(app.staticTexts[reviewText], in: app)
        capture(app, name: "07-Review")

        let addTrip = app.buttons["加入行程"]
        reveal(addTrip, in: app, swipingUp: false)
        addTrip.tap()
        XCTAssertTrue(app.buttons["保存计划"].waitForExistence(timeout: 5))
        capture(app, name: "08-TripEditor")
        app.buttons["保存计划"].tap()
        app.tabBars.buttons["行程"].tap()
        XCTAssertTrue(app.staticTexts["已保存的行程"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["西湖风景名胜区"].exists)
        capture(app, name: "09-Trips")

        app.terminate()
        app.launch()
        app.tabBars.buttons["我的"].tap()
        XCTAssertTrue(app.staticTexts["旅行画像"].waitForExistence(timeout: 5))
        capture(app, name: "10-Profile")
        let prefs = app.buttons["profile-preferences"]
        reveal(prefs, in: app)
        prefs.tap()
        XCTAssertTrue(app.switches["偏好短距离步行"].waitForExistence(timeout: 5))
        capture(app, name: "11-Preferences")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let saved = app.buttons["profile-saved"]
        reveal(saved, in: app)
        saved.tap()
        XCTAssertTrue(app.staticTexts["西湖风景名胜区"].waitForExistence(timeout: 5))

        app.tabBars.buttons["行程"].tap()
        XCTAssertTrue(app.staticTexts["西湖风景名胜区"].waitForExistence(timeout: 5))
        let edit = app.buttons["修改行程"]
        reveal(edit, in: app)
        edit.tap()
        XCTAssertTrue(app.buttons["保存计划"].waitForExistence(timeout: 5))
        app.buttons["取消"].tap()
        XCTAssertTrue(app.staticTexts["西湖风景名胜区"].waitForExistence(timeout: 5))
    }

    func testPlannerAndFamilyNotesPersist() {
        let app = launchFresh()
        app.buttons["home-planner"].tap()
        let prompt = app.buttons["带父母去杭州，玩3天"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        capture(app, name: "12-Planner")
        prompt.tap()
        let draft = app.buttons["查看并保存计划"]
        reveal(draft, in: app)
        capture(app, name: "13-PlannerDraft")
        draft.tap()
        XCTAssertTrue(app.buttons["保存计划"].waitForExistence(timeout: 5))
        app.buttons["保存计划"].tap()

        app.tabBars.buttons["家人"].tap()
        XCTAssertTrue(app.staticTexts["杭州西湖家庭游"].waitForExistence(timeout: 5))
        let add = app.buttons["添加同行人"]
        reveal(add, in: app)
        add.tap()
        let name = app.textFields["姓名或称呼"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("阿岚")
        app.buttons["保存"].tap()
        XCTAssertTrue(app.staticTexts["阿岚"].waitForExistence(timeout: 5))
        capture(app, name: "14-Family")

        let notes = app.buttons["family-notes"]
        reveal(notes, in: app)
        notes.tap()
        let input = app.descendants(matching: .any)["family-note-input"].firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        let memo = "午饭后留一小时休息。"
        input.typeText(memo)
        app.buttons["保存到本机"].tap()
        XCTAssertTrue(app.staticTexts[memo].waitForExistence(timeout: 5))
        capture(app, name: "15-FamilyNotes")

        app.terminate()
        app.launch()
        app.tabBars.buttons["家人"].tap()
        XCTAssertTrue(app.staticTexts["阿岚"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["杭州西湖家庭游"].exists)
        reveal(notes, in: app)
        notes.tap()
        XCTAssertTrue(app.staticTexts[memo].waitForExistence(timeout: 5))
    }

    func testOptimizingTripKeepsExpensesAndTravelDetails() {
        let app = launchFresh()
        app.tabBars.buttons["行程"].tap()
        let create = app.buttons["创建旅行计划"]
        reveal(create, in: app)
        create.tap()
        let save = app.buttons["保存计划"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()

        let days = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "第1天 ·")).firstMatch
        let party = app.staticTexts.matching(NSPredicate(format: "label ENDSWITH %@", "人同行")).firstMatch
        XCTAssertTrue(days.waitForExistence(timeout: 5))
        XCTAssertTrue(party.exists)
        let firstDayLabel = days.label
        let people = party.label.components(separatedBy: "·").last?.trimmingCharacters(in: .whitespaces)
        XCTAssertEqual(people, "2人同行")
        app.buttons["费用清单"].tap()
        app.buttons["记一笔"].tap()
        let label = app.textFields["expense-name"]
        let amount = app.textFields["expense-amount"]
        XCTAssertTrue(label.waitForExistence(timeout: 5))
        label.tap()
        label.typeText("游船票")
        amount.tap()
        amount.typeText("36.50")
        app.buttons["保存费用"].tap()
        XCTAssertTrue(app.staticTexts["游船票"].waitForExistence(timeout: 5))
        capture(app, name: "16-Expenses")

        app.buttons["行程安排"].tap()
        let optimize = app.buttons["AI 优化行程"]
        reveal(optimize, in: app)
        optimize.tap()
        let extend = app.buttons["调整为3天"]
        XCTAssertTrue(extend.waitForExistence(timeout: 5))
        extend.tap()
        let apply = app.buttons["保存到原行程"]
        reveal(apply, in: app)
        apply.tap()
        app.terminate()
        app.launch()
        app.tabBars.buttons["行程"].tap()
        XCTAssertTrue(app.staticTexts["杭州市 · 3日游"].waitForExistence(timeout: 5))
        XCTAssertEqual(days.label, firstDayLabel)
        XCTAssertEqual(party.label.components(separatedBy: "·").last?.trimmingCharacters(in: .whitespaces), people)
        XCTAssertFalse(app.buttons["切换行程"].exists)
        app.buttons["费用清单"].tap()
        XCTAssertTrue(app.staticTexts["游船票"].exists)
        let price = app.staticTexts.matching(NSPredicate(format: "label ENDSWITH %@", "36.50"))
        XCTAssertEqual(price.count, 2, "清单金额与合计都应保留。")
    }

    func testAccessibleTextAndLandscapeWelcome() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["YUTO_UI_TEST_SUITE"] = "yuto.ui-test.\(UUID())"
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"]
        app.launch()
        let device = XCUIDevice.shared
        defer { device.orientation = .portrait }
        device.orientation = .landscapeLeft
        let start = app.buttons["start-journey"]
        XCTAssertTrue(start.waitForExistence(timeout: 8))
        XCTAssertGreaterThan(app.frame.width, app.frame.height, "欢迎页应适配横屏。")
        XCTAssertTrue(app.staticTexts["和家人一起，轻松去旅行"].exists)
        XCTAssertTrue(start.isHittable)
        capture(app, name: "17-LandscapeWelcome-LargeText")
        start.tap()
        XCTAssertTrue(app.staticTexts["今天想去哪里旅行？"].waitForExistence(timeout: 5))
        device.orientation = .portrait
        capture(app, name: "18-Home-LargeText")
        let planner = app.buttons["home-planner"]
        reveal(planner, in: app)
        planner.tap()
        XCTAssertTrue(app.navigationBars["AI 旅行规划师"].waitForExistence(timeout: 5))
        app.tabBars.buttons["发现"].tap()
        XCTAssertTrue(app.staticTexts["discover-title"].waitForExistence(timeout: 5))
        capture(app, name: "19-Discover-LargeText")
    }

    private func launchFresh(captureWelcome: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["YUTO_UI_TEST_SUITE"] = "yuto.ui-test.\(UUID())"
        app.launch()
        let start = app.buttons["start-journey"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        if captureWelcome { capture(app, name: "00-Welcome") }
        start.tap()
        XCTAssertTrue(app.staticTexts["今天想去哪里旅行？"].waitForExistence(timeout: 5))
        return app
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication, swipingUp: Bool = true,
                        file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<5 where !element.isHittable {
            if swipingUp { app.swipeUp() } else { app.swipeDown() }
        }
        XCTAssertTrue(element.isHittable, file: file, line: line)
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
