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
        let explore = app.buttons["discover-provinces"]
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

    func testExploreModelAndPersistFootprints() {
        let app = launchFresh()
        let entry = app.buttons["home-footprints"]
        reveal(entry, in: app)
        entry.tap()
        XCTAssertTrue(app.staticTexts["footprints-title"].waitForExistence(timeout: 12))
        let map = app.descendants(matching: .any)["province-scene"].firstMatch
        XCTAssertTrue(map.waitForExistence(timeout: 8))
        capture(app, name: "Footprints-FullMap")
        let memory = app.buttons["footprint-memory"]
        let startingPlace = memory.label
        for offset in [CGVector(dx: 0.25, dy: 0.45), CGVector(dx: 0.4, dy: 0.53), CGVector(dx: 0.53, dy: 0.55)] where memory.label == startingPlace {
            map.coordinate(withNormalizedOffset: offset).tap()
        }
        XCTAssertNotEqual(memory.label, startingPlace, "点按立体省块应切换记忆卡")
        map.pinch(withScale: 1.6, velocity: 1)
        let center = map.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.50))
        center.press(forDuration: 0.1, thenDragTo: map.coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.56)))
        app.buttons["缩小地图"].tap()
        app.buttons["放大地图"].tap()
        app.buttons["回到全图"].tap()
        app.buttons["footprint-provinces"].tap()
        let sichuan = app.buttons["footprint-select-四川"]
        reveal(sichuan, in: app)
        sichuan.tap()
        for _ in 0..<3 { app.buttons["放大地图"].tap() }
        XCTAssertTrue(memory.label.contains("四川"))
        capture(app, name: "Footprints-SichuanDetail")
        app.buttons["回到全图"].tap()
        app.buttons["footprint-provinces"].tap()
        let xinjiang = app.buttons["footprint-select-新疆"]
        if !xinjiang.isHittable {
            let search = app.searchFields.firstMatch
            if search.exists { search.tap(); search.typeText("新疆") }
            else { reveal(xinjiang, in: app) }
        }
        xinjiang.tap()
        let mark = app.buttons["footprint-mark"]
        reveal(mark, in: app)
        mark.tap()
        let progress = app.descendants(matching: .any)["footprint-progress"].firstMatch
        XCTAssertTrue((progress.value as? String)?.contains("已点亮 1 个") == true)
        capture(app, name: "Footprints-Lit")
        app.buttons["footprint-memory"].tap()
        XCTAssertTrue(app.navigationBars["旅行记忆"].waitForExistence(timeout: 5))
        capture(app, name: "Footprints-Memories")
        app.terminate()
        app.launch()
        reveal(entry, in: app)
        entry.tap()
        XCTAssertTrue(progress.waitForExistence(timeout: 8))
        XCTAssertTrue((progress.value as? String)?.contains("已点亮 1 个") == true)
        app.buttons["footprint-memory"].tap()
        let remove = app.buttons["footprint-unmark"]
        reveal(remove, in: app)
        remove.tap()
        app.buttons["撤销点亮"].tap()
        app.buttons["关闭"].tap()
        XCTAssertTrue((progress.value as? String)?.contains("已点亮 0 个") == true)
    }

    func testContactAndReadingPreferences() {
        let app = launchFresh()
        app.buttons["出行求助"].tap()
        app.buttons["添加求助联系人"].tap()
        let name = app.textFields["姓名或称呼"]
        name.tap()
        name.typeText("家人")
        let phone = app.textFields["电话号码"]
        phone.tap()
        phone.typeText("5550100")
        app.buttons["保存"].tap()
        XCTAssertTrue(app.buttons["拨打家人"].waitForExistence(timeout: 5))
        app.tabBars.buttons["我的"].tap()
        app.buttons["显示与隐私设置"].tap()
        let contrast = app.switches["高对比度"]
        XCTAssertTrue(contrast.waitForExistence(timeout: 5))
        contrast.coordinate(withNormalizedOffset: CGVector(dx: 0.90, dy: 0.5)).tap()
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "1"), object: contrast)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 4), .completed)
        app.switches["显示朗读按钮"].coordinate(withNormalizedOffset: CGVector(dx: 0.90, dy: 0.5)).tap()
        XCTAssertFalse(app.buttons["朗读"].exists)
        app.terminate()
        app.launch()
        app.buttons["出行求助"].tap()
        XCTAssertTrue(app.buttons["拨打家人"].exists)
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

extension TravelJourneyTests {
    func testTripToolsBookmarkAlbumAndScheduledReminder() throws {
        let app = launchFresh()
        app.tabBars.buttons["行程"].tap()
        let create = app.buttons["创建旅行计划"]
        reveal(create, in: app)
        create.tap()
        app.buttons["保存计划"].tap()

        let bookmark = app.buttons["收藏这条路线"]
        XCTAssertTrue(bookmark.waitForExistence(timeout: 6))
        bookmark.tap()
        app.buttons["查看收藏路线"].tap()
        XCTAssertTrue(app.staticTexts["杭州西湖"].waitForExistence(timeout: 5))
        app.staticTexts["杭州西湖"].tap()

        let album = app.buttons["trip-album"]
        reveal(album, in: app)
        album.tap()
        XCTAssertTrue(app.buttons["添加旅行照片"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let reminders = app.buttons["trip-reminders"]
        reveal(reminders, in: app)
        reminders.tap()
        app.buttons["add-trip-reminder"].tap()
        // Use point-in-time system sound delivery; voice generation depends on the selected iOS voice.
        let voice = app.switches["使用语音提醒"]
        XCTAssertTrue(voice.waitForExistence(timeout: 5))
        if voice.value as? String == "1" { voice.tap() }
        app.buttons["保存提醒"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.alerts.buttons.matching(NSPredicate(format: "label IN %@", ["允许", "Allow"])).firstMatch
        if allow.waitForExistence(timeout: 4) { allow.tap() }
        let row = app.buttons["trip-reminder-row"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        let scheduled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "已安排"), object: row)
        XCTAssertEqual(XCTWaiter.wait(for: [scheduled], timeout: 8), .completed)
        row.tap()
        app.buttons["删除这条提醒"].tap()
        XCTAssertFalse(row.exists)
    }
}
