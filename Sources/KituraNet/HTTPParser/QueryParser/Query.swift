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

public struct Query {

#if os(Linux)
    typealias RegularExpressionType = RegularExpression
#else
    typealias RegularExpressionType = NSRegularExpression
#endif

    static var keyedParameterRegex: RegularExpressionType? = {
        return try? RegularExpressionType(pattern: "([^\\[\\]\\,\\.\\s]*)\\[([^\\[\\]\\,\\.\\s]*)\\]", options: .caseInsensitive)
    }()

    public static let null = Query()

    public enum ParameterType {
        case null(object: Any)
        case array(value: [Any])
        case dictionary(value: [String : Any])
        case int(value: Int)
        case string(value: String)
        case double(value: Double)
        case bool(value: Bool)
    }

    fileprivate(set) public var type: ParameterType = .null(object: NSNull())

    private init() { }

    public init(_ object: Any) {
        self.object = object
    }
}

extension Query {

    fileprivate(set) public var object: Any {
        get {
            switch self.type {
            case .string(let value):
                return value
            case .int(let value):
                return value
            case .double(let value):
                return value
            case .bool(let value):
                return value
            case .array(let value):
                return value
            case .dictionary(let value):
                return value
            case .null(let object):
                return object
            }
        }
        set {
            switch newValue {
            case let string as String:
                if let int = Int(string) {
                    self.type = .int(value: int)
                } else if let double = Double(string) {
                    self.type = .double(value: double)
                } else if let bool = Bool(string) {
                    self.type = .bool(value: bool)
                } else {
                    self.type = .string(value: string)
                }
            case let int as Int:
                self.type = .int(value: int)
            case let double as Double:
                self.type = .double(value: double)
            case let bool as Bool:
                self.type = .bool(value: bool)
            case let array as [Any]:
                self.type = .array(value: array)
            case let dictionary as [String : Any]:
                self.type = .dictionary(value: dictionary)
            default:
                self.type = .null(object: newValue)
            }
        }
    }

    internal(set) public subscript(key: QueryKeyProtocol) -> Query {
        set {
            let realKey = key.queryKey
            switch (realKey, self.type) {
            case (.key(let key), .dictionary(var dictionary)):
                dictionary[key] = newValue.object
                self.type = .dictionary(value: dictionary)
            default:
                break
            }
        }
        get {
            let realKey = key.queryKey

            switch (realKey, self.type) {
            case (.key(let key), .dictionary(let dictionary)):
                guard let value = dictionary[key] else {
                    return Query.null
                }
                return Query(value)
            case (.index(let index), .array(let array)):
                guard array.count > index,
                    index >= 0 else {
                        return Query.null
                }
                return Query(array[index])
            default:
                break
            }

            return Query.null
        }
    }

    public subscript(keys: [QueryKeyProtocol]) -> Query {
        get {
            return keys.reduce(self) { $0[$1] }
        }
    }

    public subscript(keys: QueryKeyProtocol...) -> Query {
        get {
            return self[keys]
        }
    }
}
