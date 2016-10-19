/**
 * Copyright IBM Corporation 2016
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

import Foundation

import XCTest

@testable import KituraNet

class LifecycleDelegateTests: XCTestCase {

    static var allTests : [(String, (LifecycleDelegateTests) -> () throws -> Void)] {
        return [
            ("testLifecycle", testLifecycle)
        ]
    }

    let delegate = TestServerDelegate()
    var started: Bool = false
    var finished: Bool = false

    func testLifecycle() {
        performServerTest(delegate, asyncTasks: { expectation in
            self.performRequest("get", path: "/any", callback: { _ in
                XCTAssertEqual(response!.statusCode, HTTPStatusCode.OK, "Status code wasn't .Ok was \(response!.statusCode)")
                XCTAssertTrue(self.started, "server delegate serverStarted:on:using: wasn't called")
                expectation.fulfill()
            })
        })

        XCTAssertTrue(self.finished, "server delegate serverStopped:on: wasn't called")
    }

    class TestServerDelegate : ServerDelegate {

        func handle(request: ServerRequest, response: ServerResponse) {
            try response.end()
        }
    }
}

extension LifecycleDelegateTests {

    func serverStarted(_ server: Server, on port: Int, using socket: Socket) {
        self.started = true
    }

    func serverStopped(_ server: Server, on port: Int) {
        self.finished = true
    }
}
