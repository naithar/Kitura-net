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

import XCTest

@testable import KituraNet

import Foundation
import Dispatch

protocol KituraNetTest {
    func expectation(_ index: Int) -> XCTestExpectation
    func waitExpectation(timeout t: TimeInterval, handler: XCWaitCompletionHandler?)
}

extension KituraNetTest {

    func doSetUp() {
        PrintLogger.use()
    }

    func doTearDown() {
        //       sleep(10)
    }
    
    func performServerTest(_ delegate: ServerDelegate, asyncTasks: @escaping (XCTestExpectation) -> Void...) {
        let server = setupServer(port: 8090, delegate: delegate)
        let requestQueue = DispatchQueue(label: "Request queue")
        
        for (index, asyncTask) in asyncTasks.enumerated() {
            let expectation = self.expectation(index)
            requestQueue.async {
                asyncTask(expectation)
            }
        }
        
        waitExpectation(timeout: 10) { error in
            // blocks test until request completes
            server.stop()
            XCTAssertNil(error);
        }
    }
    
    func performRequest(_ method: String, path: String, callback: @escaping ClientRequest.Callback, headers: [String: String]? = nil, requestModifier: ((ClientRequest) -> Void)? = nil) {
        var allHeaders = [String: String]()
        if  let headers = headers  {
            for  (headerName, headerValue) in headers  {
                allHeaders[headerName] = headerValue
            }
        }
        allHeaders["Content-Type"] = "text/plain"
        let options: [ClientRequest.Options] = [.method(method), .hostname("localhost"), .port(8090), .path(path), .headers(allHeaders)]
        let req = HTTP.request(options, callback: callback)
        if let requestModifier = requestModifier {
            requestModifier(req)
        }
        req.end()
    }
    
    private func setupServer(port: Int, delegate: ServerDelegate) -> HTTPServer {
        return HTTPServer.listen(port: port, delegate: delegate, errorHandler: {(error: Swift.Error) -> Void in
            print("Handling error in KituraNetTest.setupServer \(error)")
        })
    }
}

extension XCTestCase: KituraNetTest {
    func expectation(_ index: Int) -> XCTestExpectation {
        let expectationDescription = "\(type(of: self))-\(index)"
        return self.expectation(description: expectationDescription)
    }

    func waitExpectation(timeout t: TimeInterval, handler: XCWaitCompletionHandler?) {
        self.waitForExpectations(timeout: t, handler: handler)
    }
}
