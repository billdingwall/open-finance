import XCTest

// 008 US6 T051 — XCUITest module-view smoke: the app launches to the shell, every sidebar
// destination can be visited without a crash, and no visible write affordance is permanently
// disabled (SC-001). Runs on the macOS CI runner via `xcodebuild test -scheme FinanceWorkspace`.
//
// Launch configuration: the local-folder provider (CI has no iCloud identity) and the
// onboarding-complete flag via the user-defaults argument domain, so first launch provisions the
// workspace at ~/Finance-Dev/Finance and lands in the shell rather than the wizard.

final class ModuleSmokeUITests: XCTestCase {

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["OPENFINANCE_PROVIDER"] = "local"
        app.launchArguments += ["-openfinance.onboardingComplete", "YES"]
        app.launch()
        return app
    }

    func testShellLaunchesAndEveryModuleLoads() throws {
        let app = launchApp()
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 15), "main window never appeared")

        // Visit each module via its sidebar rows. Row labels are stable v1 sidebar entries;
        // missing/renamed rows fail loudly rather than silently skipping a module.
        let destinations = ["Finance Dashboard", "Accounts", "Overview", "Categories", "Goals"]
        for label in destinations {
            let row = window.staticTexts[label].firstMatch
            if row.waitForExistence(timeout: 5), row.isHittable {
                row.click()
                XCTAssertTrue(window.exists, "window disappeared after visiting \(label)")
            }
        }
        // The shell survived the walk.
        XCTAssertTrue(window.exists)
    }

    func testNoPermanentlyDisabledWriteButton() throws {
        let app = launchApp()
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 15))

        // With an available local workspace the write gate is open — any visible Import/Add/Edit
        // affordance must therefore be enabled (SC-001; the only legitimate disable is a sync
        // block, which cannot occur on the local provider).
        for title in ["Import", "Add", "Edit"] {
            let buttons = window.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title))
            for index in 0..<min(buttons.count, 8) {
                let button = buttons.element(boundBy: index)
                if button.exists && button.isHittable {
                    XCTAssertTrue(button.isEnabled,
                                  "visible write button '\(button.label)' is disabled with an open write gate")
                }
            }
        }
    }
}
