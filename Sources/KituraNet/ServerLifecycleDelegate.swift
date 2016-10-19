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

public protocol ServerLifecycleDelegate: class {

    func started(server: Server, on port: Int, using socket: Socket)
    func failed(server: Server, on port: Int, with error: Error)
    func stopped(server: Server, on port: Int)
}

///Default implementation for making all delegate methods optional
extension ServerLifecycleDelegate {

    func started(server: Server, on port: Int, using socket: Socket) {
        Log.info("Server: \(server) has started listening on port: \(port) using socket: \(socket)")
    }

    func failed(server: Server, on port: Int, with error: Error) {
        Log.error("Server: \(server) failed on port: \(port) with error: \(error)")
    }

    func stopped(server: Server, on port: Int) {
        Log.info("Server: \(server) stopped listening on port: \(port)")
    }
}
