import XCTest

final class TravelJourneyTests: XCTestCase {
    @MainActor
    func testSearchFavoriteAndSaveTrip() {
        let app = XCUIApplication()
        app.launchEnvironment["YUTO_UI_TEST_SUITE"] = "yuto.ui-test.\(UUID())"
        app.launch()
        XCTAssertTrue(app.staticTexts["今天，想去哪里走走？"].waitForExistence(timeout: 10))
        capture(app, name: "01-Home")

        let explore = app.buttons["explore-provinces"]
        if !explore.isHittable { app.swipeUp() }
        explore.tap()
        let province = app.descendants(matching: .any)["province-上海"].firstMatch
        XCTAssertTrue(province.waitForExistence(timeout: 8))
        capture(app, name: "00-ProvinceGrid")
        province.tap()
        XCTAssertTrue(app.staticTexts["上海景区"].waitForExistence(timeout: 5))
        app.tabBars.buttons["首页"].tap()

        let field = app.textFields["destination-search"]
        if !field.isHittable { app.swipeUp() }
        field.tap()
        field.typeText("西湖")
        app.buttons["搜索"].tap()
        XCTAssertTrue(app.staticTexts["发现目的地"].waitForExistence(timeout: 8))
        capture(app, name: "02-Discover")

        let result = app.staticTexts["西湖风景名胜区"].firstMatch
        if !result.isHittable { app.swipeUp() }
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()
        let favorite = app.buttons["收藏景区"]
        if !favorite.isHittable { app.swipeUp() }
        XCTAssertTrue(favorite.waitForExistence(timeout: 5))
        app.buttons["收藏景区"].tap()
        XCTAssertTrue(app.buttons["已收藏"].exists)
        capture(app, name: "03-Destination")

        let album = app.buttons["打开景区相册"]
        if !album.isHittable { app.swipeDown() }
        album.tap()
        XCTAssertTrue(app.buttons["关闭"].waitForExistence(timeout: 5))
        app.buttons["关闭"].tap()

        let write = app.buttons["写评价"]
        for _ in 0..<4 where !write.isHittable { app.swipeUp() }
        write.tap()
        let review = app.textViews["review-text"]
        XCTAssertTrue(review.waitForExistence(timeout: 5))
        review.tap()
        review.typeText("湖边走走，很舒服。")
        app.buttons["保存评价"].tap()
        XCTAssertTrue(app.staticTexts["湖边走走，很舒服。"].waitForExistence(timeout: 5))
        capture(app, name: "07-VisitTagsAndReview")
        for _ in 0..<4 where !app.buttons["加入行程"].isHittable { app.swipeDown() }

        app.buttons["加入行程"].tap()
        let save = app.buttons["保存计划"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        capture(app, name: "04-TripEditor")
        save.tap()

        app.tabBars.buttons["行程"].tap()
        XCTAssertTrue(app.staticTexts["已保存的行程"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["西湖风景名胜区"].exists)
        capture(app, name: "05-Trips")

        app.terminate()
        app.launch()
        app.tabBars.buttons["我的"].tap()
        XCTAssertTrue(app.staticTexts["旅行画像"].waitForExistence(timeout: 5))
        capture(app, name: "06-Profile")
        let saved = app.staticTexts["西湖风景名胜区"].firstMatch
        for _ in 0..<3 where !saved.isHittable { app.swipeUp() }
        XCTAssertTrue(saved.exists)

        app.tabBars.buttons["行程"].tap()
        XCTAssertTrue(app.staticTexts["西湖风景名胜区"].waitForExistence(timeout: 5))
        let edit = app.buttons["修改行程"]
        if !edit.isHittable { app.swipeUp() }
        edit.tap()
        XCTAssertTrue(app.buttons["保存计划"].waitForExistence(timeout: 5))
        app.buttons["取消"].tap()
        XCTAssertTrue(app.staticTexts["西湖风景名胜区"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
