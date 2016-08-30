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

extension String {

    fileprivate var parameter: String? {
        let urlCharacterSet = CharacterSet(charactersIn: " \"\n")
        return self.removingPercentEncoding?.trimmingCharacters(in: urlCharacterSet)
    }
}

//MARK: query parsing
extension Query {

    public init(fromText query: String?) {
        self.init([:])

        guard let query = query else {
            return
        }
        Query.parse(fromText: query, into: &self)
    }

    static fileprivate func parse(fromText query: String, into parameter: inout Query) {
        let pairs = query.components(separatedBy: "&")

        for pair in pairs {
            let pairArray = pair.components(separatedBy: "=")

            guard pairArray.count == 2,
                let parameterValueString = pairArray[1].parameter,
                let key = pairArray[0].parameter else {
                    return
            }

            let parameterValue = Query(parameterValueString)
            if case .null = parameterValue.type { continue }
            parse(container: &parameter, key: key, value: parameterValue)
        }
    }

    static private func parse(container: inout Query,
        key: String,
        parameterKey: String,
        defaultValue: Any,
        value: Query,
        raw rawClosure: (Query) -> Any?) {
            var newParameter: Query

            if let raw = rawClosure(container[parameterKey]) {
                newParameter = Query(raw)
            } else if let raw = container.array?.first {
                newParameter = Query(raw)
            } else {
                newParameter = Query(defaultValue)
            }
            self.parse(container: &newParameter, key: key, value: value)

            if !parameterKey.isEmpty {
                container[parameterKey] = newParameter
            } else if case .array(var containerArray) = container.type {
                if containerArray.count > 0 {
                    containerArray[0] = newParameter.object
                } else {
                    containerArray.append(newParameter.object)
                }

                container = Query(containerArray)
            }
    }

    static private func parse(container: inout Query, key: String?, value: Query) {
        if let key = key,
            let regex = Query.keyedParameterRegex,
            let match = regex.firstMatch(in: key, options: [], range: NSMakeRange(0, key.characters.count)) {
                let nsKey = NSString(string: key)

            #if os(Linux)
                let matchRange = match.range(at: 0)
                let keyRange = match.range(at: 1)
            #else
                let matchRange = match.rangeAt(0)
                let keyRange = match.rangeAt(1)
            #endif

                let parameterKey = nsKey.substring(with: keyRange)
            #if os(Linux)
                let nextKeyRange = match.range(at: 2)
            #else
                let nextKeyRange = match.rangeAt(2)
            #endif
                var nextKeyPart = nsKey.substring(with: nextKeyRange)

                if nextKeyPart.characters.count > 0 {
                    if let escaped = nextKeyPart.parameter {
                        nextKeyPart = escaped
                    }
                    let nextKey = nsKey.replacingCharacters(in: matchRange, with: nextKeyPart)
                    self.parse(container: &container, key: nextKey, parameterKey: parameterKey, defaultValue: [:], value: value) { $0.dictionary }
                } else {
                    let nextKey = nsKey.replacingCharacters(in: matchRange, with: "")
                    self.parse(container: &container, key: nextKey, parameterKey: parameterKey, defaultValue: [], value: value) { $0.array }
                }
        } else if let key = key,
            !key.isEmpty {
            container[key] = value
        } else {
            if case .array(var existingArray) = container.type {
                existingArray.append(value.object)
                container = Query(existingArray)
            } else {
                container = value
            }
        }
    }
}
