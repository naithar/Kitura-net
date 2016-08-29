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

public struct QueryParameters {

    public typealias AnyType = QueryParameter.AnyType

#if os(Linux)
    typealias RegularExpressionType = RegularExpression
#else
    typealias RegularExpressionType = NSRegularExpression
#endif

    private var root = QueryParameter([:])

    lazy var keyedParameterRegex: RegularExpressionType? = {
        return try? RegularExpressionType(pattern: "([^\\[\\]\\,\\.\\s]*)\\[([^\\[\\]\\,\\.\\s]*)\\]", options: .caseInsensitive)
    }()

    public subscript(key: QueryKeyProtocol) -> QueryParameter {
        get {
            return self.root[key]
        }
    }

    public subscript(keys: [QueryKeyProtocol]) -> QueryParameter {
        get {
            return self.root[keys]
        }
    }

    public subscript(keys: QueryKeyProtocol...) -> QueryParameter {
        get {
            return self[keys]
        }
    }

    public init() { }

    public init(from query: String?) {
        guard let query = query else {
            return
        }

        self.parse(fromText: query)
    }

    public mutating func parse(fromText query: String) {
        let pairs = query.components(separatedBy: "&")

        for pair in pairs {
            let pairArray = pair.components(separatedBy: "=")

            guard pairArray.count == 2,
                let parameterValueString = pairArray[1].parameter,
                let key = pairArray[0].parameter else {
                    return
            }

            let parameterValue = QueryParameter(parameterValueString)
            if case .null = parameterValue.type { return }
            self.parse(container: &self.root, key: key, value: parameterValue)
        }
    }

    private mutating func parse(container: inout QueryParameter, key: String, parameterKey: String, defaultValue: AnyType, value: QueryParameter, raw rawClosure: (QueryParameter) -> AnyType?) {
        var newParameter: QueryParameter

        if let raw = rawClosure(container[parameterKey]) {
            newParameter = QueryParameter(raw)
        } else if let raw = container.array?.first {
            newParameter = QueryParameter(raw)
        } else {
            newParameter = QueryParameter(defaultValue)
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

            container = QueryParameter(containerArray)
        }
    }

    private mutating func parse(container: inout QueryParameter, key: String?, value: QueryParameter) {
        if let key = key,
            let regex = self.keyedParameterRegex,
            let match = regex.firstMatch(in: key, options: [], range: NSMakeRange(0, key.characters.count)) { //checks for dictionary and array
                let nsKey = NSString(string: key)
                let matchRange = match.rangeAt(0)

                let keyRange = match.rangeAt(1)
                let parameterKey = nsKey.substring(with: keyRange)

                let nextKeyRange = match.rangeAt(2)
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
            !key.isEmpty { //only dictionary
            container[key] = value
        } else { //array or simple value
            if case .array(var existingArray) = container.type {
                existingArray.append(value.object)
                container = QueryParameter(existingArray)
            } else {
                container = value
            }
        }
    }
}
