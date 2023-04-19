
import Foundation

public typealias JSON = TinyJSON

public enum Number {
    case double(Double)
    case int(Int64)
}

public enum TinyJSON {
    indirect case object([String: TinyJSON])
    indirect case array([TinyJSON])
    case string(String)
    case number(Number)
    case bool(Bool)
    case null

    public init(jsonObject: Any) {
        self = wrap(jsonObject)
    }

    public init(data: Data?, options opt: JSONSerialization.ReadingOptions = []) {
        guard let data = data,
              let jsonObject = try? JSONSerialization.jsonObject(with: data, options: opt) else {
                  // assertionFailure(TinyJSONError.invalidJSON.rawValue)
                  self = .null
                  return
              }

        self.init(jsonObject: jsonObject)
    }

    public init(parseJSON jsonString: String) {
        let data = jsonString.data(using: .utf8)
        self.init(data: data)
    }

    public init(_ object: Any?) {

        guard let object = object else {
            // assertionFailure(TinyJSONError.invalidJSON.rawValue)
            self = .null
            return
        }

        if let object = object as? Data {
            self.init(data: object)
            return
        }

        self.init(jsonObject: object)
    }

}

/// Wrap JSON node
func wrap(_ object: Any) -> TinyJSON {

    switch object {

    case let string as String:
        return .string(string)
    case let number as NSNumber:
        if strcmp(number.objCType, "f") == 0 ||
            strcmp(number.objCType, "d") == 0 {
            return .number(.double(Double(truncating: number)))
        } else if strcmp(number.objCType, "B") == 0 ||
                    strcmp(number.objCType, "C") == 0 ||
                    strcmp(number.objCType, "c") == 0 {
            return .bool(number.boolValue)
        }
        return .number(.int(Int64(truncating: number)))

    case let dictionary as [String: Any]:
        return .object(dictionary.mapValues(wrap))
    case let json as TinyJSON:
        return json
    case let array as [Any]:
        return .array(array.map(wrap))

    default:
        return .null
    }
}

/// Unwrap JSON node
func unwrap(_ json: TinyJSON) -> Any? {
    switch json {
    case let .string(string):
        return string
    case let .number(.double(double)):
        return double
    case let .number(.int(int)):
        return int
    case let .bool(bool):
        return bool
    case let .array(array):
        return array.compactMap(unwrap)
    case let .object(object):
        return object.mapValues(unwrap)
    default:
        return nil
    }
}

extension TinyJSON: Comparable {
    public static func < (lhs: TinyJSON, rhs: TinyJSON) -> Bool {
        switch (lhs, rhs) {
        case let (.string(l), .string(r)):
            return l < r
        case let (.number(.double(l)), .number(.double(r))):
            return l < r
        case let (.number(.int(l)), .number(.int(r))):
            return l < r
        default:
            return false
        }
    }

    public static func > (lhs: TinyJSON, rhs: TinyJSON) -> Bool {
        switch (lhs, rhs) {
        case let (.string(l), .string(r)):
            return l > r
        case let (.number(.double(l)), .number(.double(r))):
            return l > r
        case let (.number(.int(l)), .number(.int(r))):
            return l > r
        default:
            return false
        }
    }

    public static func >= (lhs: TinyJSON, rhs: TinyJSON) -> Bool {
        switch (lhs, rhs) {
        case let (.string(l), .string(r)):
            return l >= r
        case let (.number(.double(l)), .number(.double(r))):
            return l >= r
        case let (.number(.int(l)), .number(.int(r))):
            return l >= r
        case let (.array(l), .array(r)):
            return l == r
        case let (.object(l), .object(r)):
            return l == r
        case (.null, .null):
            return true
        case let (.bool(l), .bool(r)):
            return l == r
        default:
            return false
        }
    }

    public static func <= (lhs: TinyJSON, rhs: TinyJSON) -> Bool {
        switch (lhs, rhs) {
        case let (.string(l), .string(r)):
            return l <= r
        case let (.number(.double(l)), .number(.double(r))):
            return l <= r
        case let (.number(.int(l)), .number(.int(r))):
            return l <= r
        case let (.array(l), .array(r)):
            return l == r
        case let (.object(l), .object(r)):
            return l == r
        case (.null, .null):
            return true
        case let (.bool(l), .bool(r)):
            return l == r
        default:
            return false
        }
    }

    public static func == (lhs: TinyJSON, rhs: TinyJSON) -> Bool {
        switch (lhs, rhs) {
        case let (.array(l), .array(r)):
            return l == r
        case let (.object(l), .object(r)):
            return l == r
        case (.null, .null):
            return true
        case let (.bool(l), .bool(r)):
            return l == r
        case let (.string(l), .string(r)):
            return l == r
        case let (.number(.double(l)), .number(.double(r))):
            return l == r
        case let (.number(.int(l)), .number(.int(r))):
            return l == r
        default:
            return false
        }
    }
}

extension TinyJSON: Sequence {

    public func makeIterator() -> AnyIterator<(TinyJSON)> {
        switch self {
        case let .array(array):
            var iterator = array.makeIterator()
            return AnyIterator {
                return iterator.next()
            }
        case let .object(object):
            var iterator = object.makeIterator()
            return AnyIterator {
                guard let (key, value) = iterator.next() else {
                    return nil
                }
                return .object([key: value])
            }
        default:
            var value: TinyJSON? = self

            return AnyIterator {
                defer { value = nil }
                if case .null? = value { return nil }
                return value
            }
        }
    }
}

extension TinyJSON: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        switch self {
        case .array:
            return rawString()
        case .object:
            return rawString()
        case let .bool(bool):
            return bool.description
        case let .string(string):
            return string.description
        case let .number(.double(double)):
            return double.description
        case let .number(.int(int)):
            return int.description
        case .null:
            return ""
        }
    }

    public var debugDescription: String {
        description
    }
}

// MARK: - Subscript

public enum TinyJSONKey {
    case index(Int)
    case key(String)
}

public protocol TinyJSONSubscriptType {
    var jsonKey: TinyJSONKey { get }
}

extension Int: TinyJSONSubscriptType {
    public var jsonKey: TinyJSONKey {
        return TinyJSONKey.index(self)
    }
}

extension String: TinyJSONSubscriptType {
    public var jsonKey: TinyJSONKey {
        return TinyJSONKey.key(self)
    }
}

extension TinyJSON {

    fileprivate subscript(index index: Int) -> TinyJSON {
        get {

            if case let .array(array) = self {
                if array.indices.contains(index) {
                    return array[index]
                }

                // assertionFailure(TinyJSONError.indexOutOfBounds.rawValue)
                return .null

            } else {
                // assertionFailure(TinyJSONError.wrongType.rawValue)
                return .null
            }
        }

        set {
            if case var .array(array) = self {
                if array.indices.contains(index) {
                    array[index] = newValue
                    self = .array(array)
                } else {
                    // assertionFailure(TinyJSONError.indexOutOfBounds.rawValue)
                }
            } else {
                // assertionFailure(TinyJSONError.indexOutOfBounds.rawValue)
            }
        }
    }

    fileprivate subscript(key key: String) -> TinyJSON {
        get {
            if case let .object(object) = self {
                if let value = object[key] {
                    return value
                }
                // assertionFailure(TinyJSONError.notExist.rawValue)
                return .null
            } else {
                // assertionFailure(TinyJSONError.wrongType.rawValue)
                return .null
            }
        }

        set {
            if case var .object(object) = self {
                object[key] = newValue
                self = .object(object)
            } else {
                // assertionFailure(TinyJSONError.wrongType.rawValue)
            }
        }
    }

    fileprivate subscript(sub sub: TinyJSONSubscriptType) -> TinyJSON {
        get {
            switch sub.jsonKey {
            case .index(let index): return self[index: index]
            case .key(let key):     return self[key: key]
            }
        }

        set {
            switch sub.jsonKey {
            case .index(let index): self[index: index] = newValue
            case .key(let key):     self[key: key] = newValue
            }
        }
    }

    /**
     Find a json in the complex data structures by using array of Int and/or String as path.

     Example:

     ```
     let json = JSON[data]
     let path = [9,"list","person","name"]
     let name = json[path]
     ```

     The same as: let name = json[9]["list"]["person"]["name"]

     - parameter path: The target json's path.

     - returns: Return a json found by the path or a null json with error
     */
    public subscript(path: [TinyJSONSubscriptType]) -> TinyJSON {
        get {
            return path.reduce(self) { $0[sub: $1] }
        }
        set {
            switch path.count {
            case 0: return
            case 1: self[sub:path[0]] = newValue
            default:
                var aPath = path
                aPath.remove(at: 0)
                var nextJSON = self[sub: path[0]]
                nextJSON[aPath] = newValue
                self[sub: path[0]] = nextJSON
            }
        }
    }

    /**
     Find a json in the complex data structures by using array of Int and/or String as path.

     - parameter path: The target json's path. Example:

     let name = json[9,"list","person","name"]

     The same as: let name = json[9]["list"]["person"]["name"]

     - returns: Return a json found by the path or a null json with error
     */
    public subscript(path: TinyJSONSubscriptType...) -> TinyJSON {
        get {
            return self[path]
        }
        set {
            self[path] = newValue
        }
    }
}

// MARK: - Array
extension TinyJSON {
    public var array: [TinyJSON]? {
        get {
            if case let .array(array) = self {
                return array
            }
            // assertionFailure(TinyJSONError.wrongType.rawValue)
            return nil
        }
    }

    public var arrayValue: [TinyJSON] {
        return self.array ?? []
    }

    public var arrayObject: [Any]? {
        get {
            if case .array = self,
               let array = unwrap(self) as? [Any] {
                return array
            }
            // assertionFailure(TinyJSONError.wrongType.rawValue)
            return nil
        }

        set {
            self = TinyJSON(newValue ?? NSNull())
        }
    }
}

// MARK: - Dictionary
extension TinyJSON {
    public var dictionary: [String: TinyJSON]? {
        get {
            if case let .object(object) = self {
                return object
            }
            // assertionFailure(TinyJSONError.wrongType.rawValue)
            return nil
        }
    }

    public var dictionaryValue: [String: TinyJSON] {
        return dictionary ?? [:]
    }

    public var dictionaryObject: [String: Any]? {
        get {
            if case .object = self,
               let dictionary = unwrap(self) as? [String: Any] {
                return dictionary
            }
            // assertionFailure(TinyJSONError.wrongType.rawValue)
            return nil
        }

        set {
            self = TinyJSON(newValue ?? NSNull())
        }
    }
}

// MARK: - String

extension TinyJSON {
    public var string: String? {
        get {
            if case let .string(string) = self {
                return string
            }
            // assertionFailure(TinyJSONError.wrongType.rawValue)
            return nil
        }

        set {
            self = TinyJSON(newValue ?? NSNull())
        }
    }

    public var stringValue: String {
        get {

            switch self {
            case let .string(string):
                return string
            default:
                return self.description
            }

        }

        set {
            self = TinyJSON(newValue)
        }
    }
}

// MARK: - Bool

extension TinyJSON {
    public var bool: Bool? {
        get {
            if case let .bool(bool) = self {
                return bool
            }
            // assertionFailure(TinyJSONError.wrongType.rawValue)
            return nil
        }

        set {
            self = TinyJSON(newValue ?? NSNull())
        }
    }

    public var boolValue: Bool {
        get {
            switch self {
            case let .bool(bool):
                return bool
            case let .string(string):
                return ["true", "yes", "1"].contains { string.caseInsensitiveCompare($0) == .orderedSame }
            case let .number(.int(int)):
                return int == 1
            default:
                return false
            }
        }

        set {
            self = TinyJSON(newValue)
        }
    }
}

// MARK: - Int

extension TinyJSON {
    public var int64: Int64? {
        get {
            if case let .number(.int(int)) = self {
                return int
            }
            // assertionFailure(TinyJSONError.wrongType.rawValue)
            return nil
        }

        set {
            self = TinyJSON(newValue ?? NSNull())
        }
    }

    public var int64Value: Int64 {
        get {

            switch self {
            case let .number(.int(int)):
                return int
            case let .number(.double(double)):
                return Int64(double)
            case let .bool(bool):
                return bool ? 1 : 0
            case let .string(string):
                return Int64(string) ?? 0
            default:
                return 0
            }
        }

        set {
            self = TinyJSON(newValue)
        }
    }

    public var int: Int? {
        get {
            if let value = int64 {
                return Int(truncatingIfNeeded: value)
            }

            return nil
        }
    }

    public var intValue: Int {
        get {
            Int(truncatingIfNeeded: int64Value)
        }
    }

    public var int8Value: Int8 {
        get {
            Int8(truncatingIfNeeded: int64Value)
        }
    }

    public var int16Value: Int16 {
        get {
            Int16(truncatingIfNeeded: int64Value)
        }
    }

    public var int32Value: Int32 {
        get {
            Int32(truncatingIfNeeded: int64Value)
        }
    }

    public var uIntValue: UInt {
        get {
            UInt(truncatingIfNeeded: int64Value)
        }
    }

    public var uInt8Value: UInt8 {
        get {
            UInt8(truncatingIfNeeded: int64Value)
        }
    }

    public var uInt16Value: UInt16 {
        get {
            UInt16(truncatingIfNeeded: int64Value)
        }
    }

    public var uInt32Value: UInt32 {
        get {
            UInt32(truncatingIfNeeded: int64Value)
        }
    }

    public var uInt64Value: UInt64 {
        get {
            UInt64(truncatingIfNeeded: int64Value)
        }
    }
}

// MARK: - Double

extension TinyJSON {
    public var double: Double? {
        get {
            if case let .number(.double(double)) = self {
                return double
            }
            // assertionFailure(TinyJSONError.wrongType.rawValue)
            return nil
        }

        set {
            self = TinyJSON(newValue ?? NSNull())
        }
    }

    public var doubleValue: Double {
        get {

            switch self {
            case let .number(.double(double)):
                return double
            case let .number(.int(int)):
                return Double(int)
            case let .bool(bool):
                return bool ? 1.0 : 0.0
            case let .string(string):
                return Double(string) ?? 0.0
            default:
                return 0.0
            }
        }

        set {
            self = TinyJSON(newValue)
        }
    }

    public var floatValue: Float {
        get {
            Float(doubleValue)
        }
    }
}

// MARK: - URL

extension TinyJSON {
    public var url: URL? {
        get {
            if case let .string(string) = self {
                return string.url
            }
            return nil
        }

        set {
            self = wrap(newValue?.absoluteURL ?? "")
        }
    }
}

// MARK: - ExpressibleByStringLiteral

extension TinyJSON: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self = .string(value)
    }

    public init(extendedGraphemeClusterLiteral value: StringLiteralType) {
        self = .string(value)
    }

    public init(unicodeScalarLiteral value: StringLiteralType) {
        self = .string(value)
    }
}

extension TinyJSON: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension TinyJSON: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}

extension TinyJSON: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Any...) {
        let array = elements
        self = TinyJSON(array)
    }
}

extension TinyJSON: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .number(.double(value))
    }
}

extension TinyJSON: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, Any)...) {
        self = TinyJSON(Dictionary(elements, uniquingKeysWith: {$1}))
    }
}

extension TinyJSON: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int64) {
        self = .number(.int(value))
    }
}

// MARK: - JSON: Codable
extension TinyJSON: Codable {
    private static var codableTypes: [Codable.Type] {
        return [
            Bool.self,
            Int.self,
            Int8.self,
            Int16.self,
            Int32.self,
            Int64.self,
            UInt.self,
            UInt8.self,
            UInt16.self,
            UInt32.self,
            UInt64.self,
            Double.self,
            String.self,
            [TinyJSON].self,
            [String: TinyJSON].self
        ]
    }
    public init(from decoder: Decoder) throws {
        var object: Any?

        if let container = try? decoder.singleValueContainer(), !container.decodeNil() {
            for type in TinyJSON.codableTypes {
                if object != nil {
                    break
                }
                // try to decode value
                switch type {
                case let boolType as Bool.Type:
                    object = try? container.decode(boolType)
                case let intType as Int.Type:
                    object = try? container.decode(intType)
                case let int8Type as Int8.Type:
                    object = try? container.decode(int8Type)
                case let int32Type as Int32.Type:
                    object = try? container.decode(int32Type)
                case let int64Type as Int64.Type:
                    object = try? container.decode(int64Type)
                case let uintType as UInt.Type:
                    object = try? container.decode(uintType)
                case let uint8Type as UInt8.Type:
                    object = try? container.decode(uint8Type)
                case let uint16Type as UInt16.Type:
                    object = try? container.decode(uint16Type)
                case let uint32Type as UInt32.Type:
                    object = try? container.decode(uint32Type)
                case let uint64Type as UInt64.Type:
                    object = try? container.decode(uint64Type)
                case let doubleType as Double.Type:
                    object = try? container.decode(doubleType)
                case let stringType as String.Type:
                    object = try? container.decode(stringType)
                case let jsonValueArrayType as [TinyJSON].Type:
                    object = try? container.decode(jsonValueArrayType)
                case let jsonValueDictType as [String: TinyJSON].Type:
                    object = try? container.decode(jsonValueDictType)
                default:
                    break
                }
            }
        }
        self.init(object)
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .null:
            try container.encodeNil()
        case let .number(.double(doubleValue)):
            try container.encode(doubleValue)
        case let .number(.int(intValue)):
            try container.encode(intValue)
        case let .bool(boolValue):
            try container.encode(boolValue)
        case let .string(stringValue):
            try container.encode(stringValue)
        case let .array(arrayValue):
            try container.encode(arrayValue)
        case let .object(objectValue):
            try container.encode(objectValue)
        }
    }
}

public enum TinyJSONError: String, Swift.Error {
    case unsupportedType = "It is an unsupported type."
    case indexOutOfBounds = "Array Index is out of bounds."
    case wrongType = "Type is wrong"
    case notExist = "Dictionary key does not exist."
    case invalidJSON = "JSON is invalid."
}

/// from SwiftJSON
fileprivate extension String {
    var url: URL? {
        get {
            // Check for existing percent escapes first to prevent double-escaping of % character
            if self.range(of: "%[0-9A-Fa-f]{2}", options: .regularExpression, range: nil, locale: nil) != nil {
                return Foundation.URL(string: self)
            } else if let encodedString_ = self.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) {
                return Foundation.URL(string: encodedString_)
            } else {
                return nil
            }
        }
    }
}

//MARK: - Compatible with SwiftJSON

extension TinyJSON {

    public func rawData(options opt: JSONSerialization.WritingOptions = JSONSerialization.WritingOptions(rawValue: 0)) throws -> Data {

        guard let object = unwrap(self),
              JSONSerialization.isValidJSONObject(object) else {
                  throw TinyJSONError.invalidJSON
              }

        return try JSONSerialization.data(withJSONObject: object, options: opt)
    }

    /// 33.3 -> 33.299999999999997
    public func rawString(_ encoding: String.Encoding = .utf8, options opt: JSONSerialization.WritingOptions = .prettyPrinted) -> String {

        switch self {
        case .object, .array:
            return _rawString(encoding, options: opt)
        default:
            return self.description
        }

    }

    private func _rawString(_ encoding: String.Encoding = .utf8, options opt: JSONSerialization.WritingOptions = .prettyPrinted) -> String {
        if let data = try? rawData(options: opt) {
            return String(data: data, encoding: encoding) ?? TinyJSON.null.description
        }

        return TinyJSON.null.description
    }
}

extension TinyJSON {
    public mutating func merge(with other: TinyJSON) throws {
        try self.merge(with: other, typecheck: true)
    }

    public func merged(with other: TinyJSON) throws -> TinyJSON {
        var merged = self
        try merged.merge(with: other, typecheck: true)
        return merged
    }

    /**
     Private woker function which does the actual merging
     Typecheck is set to true for the first recursion level to prevent total override of the source JSON
     */
    fileprivate mutating func merge(with other: TinyJSON, typecheck: Bool = false) throws {

        switch other {
        case .array:
            self = TinyJSON(arrayValue + other.arrayValue)
        case .object:
            self = TinyJSON(dictionaryValue.merging(other.dictionaryValue, uniquingKeysWith: { _, new in
                new
            }))

        default:
            if typecheck {
                switch (other, self) {
                case (.string, .string),
                    (.bool, .bool),
                    (.number(.int), .number(.int)),
                    (.number(.double), .number(.double)),
                    (.null, _):
                    self = other
                default:
                    // assertionFailure(TinyJSONError.wrongType.rawValue)

                    throw TinyJSONError.wrongType
                }
            } else {
                self = other
            }
        }
    }

}


