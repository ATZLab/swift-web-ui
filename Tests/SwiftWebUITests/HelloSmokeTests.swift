// Tests/SwiftWebUITests/HelloSmokeTests.swift
//
// Host-build smoke test. Proves the package compiles on the host
// triple, the test target resolves its dependency on `SwiftWebUI`,
// and the single public symbol (`SwiftWebUIHello.text`) matches the
// v0.1.0 release tagline. The test is intentionally trivial; the
// real test surface (View protocol, ViewBuilder, snapshot harness,
// WebDriver smoke) lands via swiftwebui-tester in 0.1.0. See
// `.harness/docs/tdd.md` for the test framework contract
// (swift-testing, `@Suite`, `@Test`, `#expect`).

import Testing
@testable import SwiftWebUI

@Suite("Hello smoke")
struct HelloSmokeTests {
    @Test("SwiftWebUIHello.text matches the v0.1.0 release tagline")
    func helloTextMatchesReleaseTagline() {
        #expect(SwiftWebUIHello.text == "Hello, web in Swift")
    }
}
