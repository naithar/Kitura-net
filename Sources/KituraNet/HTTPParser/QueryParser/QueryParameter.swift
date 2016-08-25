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

extension Bool {

    init?(_ string: String) {
        guard string == "true" || string == "false" else { return nil }
        self.init(string == "true")
    }
}

public struct QueryParameter {

    public typealias AnyType = AnyObject

    public enum ParameterType {
        case null(object: AnyType)
        case array(value: [AnyType])
        case dictionary(value: [String : AnyType])
        case int(value: Int)
        case string(value: String)
        case double(value: Double)
        case bool(value: Bool)
    }

    private(set) public var type: ParameterType = .null(object: NSNull())

    public var object: AnyType {
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
            case let array as [AnyType]:
                self.type = .array(value: array)
            case let dictionary as [String : AnyType]:
                self.type = .dictionary(value: dictionary)
            default:
                self.type = .null(object: newValue)
            }
        }
    }

    private init() { }

    public init(_ object: AnyType) {
        self.object = object
    }
}

extension QueryParameter {

    internal(set) public subscript(key: QueryKeyProtocol) -> QueryParameter {
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
                    return QueryParameter.null
                }
                return QueryParameter(value)
            case (.index(let index), .array(let array)):
                guard array.count > index,
                    index >= 0 else {
                        return QueryParameter.null
                }
                return QueryParameter(array[index])
            default:
                break
            }

            return QueryParameter.null
        }
    }

    subscript(keys: [QueryKeyProtocol]) -> QueryParameter {
        get {
            return keys.reduce(self) { $0[$1] }
        }
    }

    public subscript(keys: QueryKeyProtocol...) -> QueryParameter {
        get {
            return self[keys]
        }
    }
}

extension QueryParameter {

    static let null = QueryParameter()
}

extension QueryParameter {

    var string: String? {
        switch self.type {
        case .string(let value):
            return value
        case .int(let value):
            return String(value)
        case .double(let value):
            return String(value)
        case .bool(let value):
            return String(value)
        default:
            return nil
        }
    }

    var int: Int? {
        switch self.type {
        case .string(let value):
            return Int(value)
        case .int(let value):
            return value
        case .double(let value):
            return Int(value)
        case .bool(let value):
            return Int(value)
        default:
            return nil
        }
    }

    var double: Double? {
        switch self.type {
        case .string(let value):
            return Double(value)
        case .int(let value):
            return Double(value)
        case .double(let value):
            return value
        default:
            return nil
        }
    }

    var bool: Bool? {
        switch self.type {
        case .bool(let value):
            return value
        case .string(let value):
            return Bool(value)
        case .int(let value):
            return Bool(value)
        default:
            return nil
        }
    }

    var array: [AnyType]? {
        switch self.type {
        case .array(let value):
            return value
        default:
            return nil
        }
    }

    var dictionary: [String : AnyType]? {
        switch self.type {
        case .dictionary(let value):
            return value
        default:
            return nil
        }
    }
}
