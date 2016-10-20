/*
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
 */

import Socket
import LoggerAPI

class ServerLifecycleListener {

    typealias ErrorClosure = (Swift.Error) -> Void
    private var startCallbacks = [() -> Void]()
    private var stopCallbacks = [() -> Void]()
    private var failCallbacks = [ErrorClosure]()

    @discardableResult
    func performStartCallbacks() -> Bool {
        guard self.startCallbacks.count > 0 else {
            return false
        }

        for callback in self.startCallbacks {
            callback()
        }

        return true
    }

    @discardableResult
    func performStopCallbacks() -> Bool {
        guard self.stopCallbacks.count > 0 else {
            return false
        }

        for callback in self.stopCallbacks {
            callback()
        }

        return true
    }

    @discardableResult
    func performFailCallbacks(with error: Swift.Error) -> Bool {
        guard self.failCallbacks.count > 0 else {
            return false
        }

        for callback in self.failCallbacks {
            callback(error)
        }

        return true
    }

    func addStartCallback(_ callback: @escaping () -> Void) {
        self.startCallbacks.append(callback)
    }

    func addStopCallback(_ callback: @escaping () -> Void) {
        self.stopCallbacks.append(callback)
    }

    func addFailCallback(_ callback: @escaping (Swift.Error) -> Void) {
        self.failCallbacks.append(callback)
    }
}