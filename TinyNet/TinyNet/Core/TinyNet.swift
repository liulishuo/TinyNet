//
//  Net.swift
//
//  Created by liulishuo on 2021/7/19.
//

import Foundation
import RxSwift
import Alamofire

public typealias DestructuringFactorBlock = () -> DestructuringFactor

/// （A, (B, C)）
/// A: Bool     根据业务状态码判断请求是否成功
/// B: Int      业务状态码
/// C: String   业务状态对应的message
public typealias TinyNetResult = (Bool, (code: Int, message: String))

public struct TinyNet {
    static let seasion: Session = {
        let configuration = URLSessionConfiguration.default
        configuration.headers = .default
        return Session(configuration: configuration, startRequestsImmediately: false)
    }()

    static func pack(_ rawRequest: RawRequest) -> DataRequest? {

        var request: URLRequest = URLRequest(url: rawRequest.url)
        request.httpMethod = rawRequest.method.rawValue
        request.allHTTPHeaderFields = rawRequest.headers

        switch rawRequest.body {
        case .none:
            break
        case .data(let data):
            request.httpBody = data
        case let .JSON(encodable):
            request.httpBody = encodable.toJSONData(encoder: JSONEncoder())
        case let .parameters(parameters, parameterEncoding):
            if let r = try? parameterEncoding.encode(request, with: parameters) {
                request = r
            }
        }

        let dataRequest = seasion.request(request)
        dataRequest.validate(statusCode: rawRequest.acceptableStatusCodes)
        return dataRequest
    }

    static func start(_ dataRequest: DataRequest) -> Observable<TinyNet.Response> {

        return Single.create { [weak dataRequest] single in

            dataRequest?.response { res in

                let result = TinyNet.result(from: res)

                switch result {
                case let .success(response):
                    single(.success(response))
                case let .failure(error):
                    single(.failure(error))
                }
            }

            dataRequest?.resume()

            return Disposables.create {
                dataRequest?.cancel()
            }
        }.asObservable()
    }

    private static func result(from res: AFDataResponse<Data?>) -> Result<TinyNet.Response, TinyNetError> {

        switch (res.response, res.error) {
        case let (r?, nil):
            let response = TinyNet.Response(statusCode: r.statusCode, data: res.data, request: res.request, response: r)
            return .success(response)
        case let (r?, e?):
            let response = TinyNet.Response(statusCode: r.statusCode, data: res.data, request: res.request, response: r)
            let error = TinyNetError.underlying(e, response)
            return .failure(error)
        case let (_, e?):
            let error = TinyNetError.underlying(e, nil)
            return .failure(error)
        default:
            let error = TinyNetError.underlying(NSError(domain: NSURLErrorDomain, code: NSURLErrorUnknown, userInfo: nil), nil)
            return .failure(error)
        }
    }
}

// MARK: - TinyNet.Response

extension TinyNet {
    public final class Response: CustomStringConvertible {

        public let statusCode: Int
        public let data: Data?
        public let request: URLRequest?
        public let response: HTTPURLResponse?
        public var destFactor: DestructuringFactor = defaultDestructuringFactor

        public init(statusCode: Int, data: Data?, request: URLRequest? = nil, response: HTTPURLResponse? = nil) {
            self.statusCode = statusCode
            self.data = data
            self.request = request
            self.response = response
        }

        public var description: String {
            return "HTTP Status Code: \(statusCode), Data Length: \(data?.count ?? 0)"
        }
    }

    public enum RequestBodyType {
        case none
        case data(Data)
        case JSON(Encodable)
        case parameters(parameters: [String: Any], encoding: ParameterEncoding)
    }
}

extension TinyNet.Response {

    public func toJSON() -> JSON {
        let result = JSON(data)
        return result.json(at: destFactor.modelKey)
    }

    public func mapResult() -> TinyNetResult {
        let result = JSON(data)

        let code = result.json(at: destFactor.statusCodeKey).intValue
        let msg = result.json(at: destFactor.messageKey).stringValue
        return (code == destFactor.successCode, (code, msg))
    }

    public func mapObject<T: Modelable>(_ type: T.Type) -> T {
        return toJSON().modelValue(type)
    }

    public func mapObjResult<T: Modelable>(_ type: T.Type) -> (TinyNetResult, T) {
        let json = JSON(data)
        let result = json.responseResult(with: destFactor)
        let model = json.json(at: destFactor.modelKey).modelValue(type)
        return (result, model)
    }

    public func mapArray<T: Modelable>(_ type: T.Type) -> [T] {
        return toJSON().modelsValue(type)
    }

    public func mapArrayResult<T: Modelable>(_ type: T.Type) -> (TinyNetResult, [T]) {
        let json = JSON(data)
        let result = json.responseResult(with: destFactor)
        let models = json.json(at: destFactor.modelKey).modelsValue(type)

        return (result, models)
    }
}

// MARK: - RawRequest
protocol RawRequest {
    var baseURL: URL { get }
    var path: String { get }
    var url: URL { get }
    var method: HTTPMethod { get }
    var parameters: Parameters? { get }
    var body: TinyNet.RequestBodyType { get }
    var headers: [String: String]? { get }
    var acceptableStatusCodes: [Int] { get }
}

extension RawRequest {
    var url: URL {
        baseURL.appendingPathComponent(path)
    }

    var headers: [String: String]? {
        //TODO: default header
        return ["Content-Type": "application/json; charset=UTF-8"]
    }

    var method: HTTPMethod {
        .get
    }

    var body: TinyNet.RequestBodyType {

        guard let parameters = self.parameters else {
            return .none
        }

        if method == .post || method == .put {
          return .parameters(parameters: parameters.values, encoding: parameters.encoding ?? JSONEncoding())
        }

        return .parameters(parameters: parameters.values, encoding: parameters.encoding ?? URLEncoding())
    }

    var baseURL: URL {
        //TODO: base url
        return URL(string: "")!
    }

    var acceptableStatusCodes: [Int] {
        Array(200..<400)
    }

}

// MARK: - Parameters

public struct Parameters {
    public var encoding: Alamofire.ParameterEncoding?
    public var values: [String: Any]

    public init(encoding: Alamofire.ParameterEncoding?, values: [String: Any?]) {
        self.encoding = encoding
        self.values = values.compactMapValues { $0 }
    }
}

extension Parameters: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, Any?)...) {

        let values = Dictionary(uniqueKeysWithValues: elements)

        self.init(encoding: nil, values: values)
    }
}

// MARK: - TinyNetError

public enum TinyNetError: Swift.Error {
    case statusCode(TinyNet.Response)
    case underlying(Swift.Error, TinyNet.Response?)
}


//MARK: - TinyJSON for TinyNet

extension TinyJSON {

    func json(at path: String) -> TinyJSON {
        guard !path.isEmpty else {
            return self
        }

        let pathArray = path.split(separator: "|").map {String($0)}
        for path in pathArray {
            let pathArray = path.split(separator: ".").map {String($0)}
            let result = self[pathArray]
            if result != .null {
                return result
            }
        }

        return .null
    }

    func responseResult(with df: DestructuringFactor) -> TinyNetResult {

        let msg = json(at: df.messageKey).stringValue

        if let code = json(at: df.statusCodeKey).int {
            return (code == df.successCode, (code, msg))
        }

        return (true, (df.successCode, msg))
    }

    public func modelValue<T: Modelable>(_ type: T.Type) -> T {
        var model = T()

        guard let data = try? JSONSerialization.data(withJSONObject: self.dictionaryObject ?? [:], options: .prettyPrinted) else {
            return model
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = model.keyDecodingStrategy()
        if let _model = try? decoder.decode(T.self, from: data) {
            model = _model
            model.mapping(self)
        }

        return model
    }

    public func modelsValue<T: Modelable>(_ type: T.Type) -> [T] {
        return arrayValue.compactMap { $0.modelValue(type) }
    }
}

// MARK: - Helper

extension DataRequest {
    func cacheKey() -> String {
        guard let urlRequest = try? convertible.asURLRequest(),
              let urlString = urlRequest.url?.absoluteString else {
                  return ""
              }
        return urlString
    }
}

fileprivate extension Encodable {
    func toJSONData(encoder: JSONEncoder) -> Data? { try? encoder.encode(self) }
}

extension ObservableType where Element == TinyNet.Response {
    public func toJSON() -> Observable<JSON> {
        return flatMap { Observable.just($0.toJSON()) }
    }

    public func mapObject<T: Modelable>(_ type: T.Type) -> Observable<T> {
        return flatMap { Observable.just($0.mapObject(type)) }
    }

    public func mapResult() -> Observable<TinyNetResult> {
        return flatMap { Observable.just($0.mapResult()) }
    }

    public func mapObjResult<T: Modelable>(_ type: T.Type) -> Observable<(TinyNetResult, T)> {
        return flatMap { Observable.just($0.mapObjResult(type)) }
    }

    public func mapArray<T: Modelable>(_ type: T.Type) -> Observable<[T]> {
        return flatMap { Observable.just($0.mapArray(type)) }
    }

    public func mapArrayResult<T: Modelable>(_ type: T.Type) -> Observable<(TinyNetResult, [T])> {
        return flatMap { Observable.just($0.mapArrayResult(type)) }
    }
}
