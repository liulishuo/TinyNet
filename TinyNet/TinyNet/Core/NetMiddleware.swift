//
//  NetMiddleware.swift
//  TinyNet
//
//  Created by liulishuo on 2021/7/23.
//

import Foundation
import RxSwift
import Alamofire

typealias F<I, O> = (I) -> O
typealias FM<I, O, C> = (I, C) -> O

/// 中间件
class Middleware<I, O> {
    let input: FM<I, I, Middleware>?
    let output: FM<O, O, Middleware>?
    
    init(input: FM<I, I, Middleware>? = nil, output: FM<O, O, Middleware>? = nil) {
        self.input = input
        self.output = output
    }
}

/// 网络插件
class NetMiddleware {
    let input: FM<DataRequest, DataRequest, NetMiddleware>?
    let output: FM<Observable<TinyNet.Response>, Observable<TinyNet.Response>, NetMiddleware>?

    init(input: FM<DataRequest, DataRequest, NetMiddleware>? = nil,
         output: FM<Observable<TinyNet.Response>, Observable<TinyNet.Response>, NetMiddleware>? = nil) {
        self.input = input
        self.output = output
    }
}

infix operator ^: MultiplicationPrecedence

/// 中间件的组合运算符
func ^<I, O>(left: @escaping F<I, O>, right: Middleware<I, O>) -> F<I, O>  {

    { i in

        let input = right.input?(i, right) ?? i

        let output = left(input)

        return right.output?(output, right) ?? output
    }
}

/// 网络插件的组合运算符
func ^ (left: @escaping F<DataRequest, Observable<TinyNet.Response>>,
        right: NetMiddleware) -> F<DataRequest, Observable<TinyNet.Response>>  {

    { i in

        let input = right.input?(i, right) ?? i

        let output = left(input)

        return right.output?(output, right) ?? output
    }
}

/// 网络插件的组合运算符
func ^ (left: @escaping F<DataRequest, Observable<TinyNet.Response>>,
        right: DataRequest?) -> Observable<TinyNet.Response>? {
    guard let right = right else {
        return nil
    }
    return left(right)
}

/// 网络插件的组合运算符
func ^ (left: @escaping F<DataRequest, Observable<TinyNet.Response>>,
        right: RawRequest?) -> Observable<TinyNet.Response>? {
    guard let right = right, let request = TinyNet.pack(right) else {
        return nil
    }
    return left(request)
}


//MARK: - 插件 用于解析
/// 按照给定的因子， 解析返回值
class ReMapM: NetMiddleware {
    
    var dataRequest: DataRequest?
    public var destFactor: DestructuringFactor!
    
    init(destFactor: DestructuringFactor? = defaultDestructuringFactor,
         input: FM<DataRequest, DataRequest, NetMiddleware>? = nil,
         output: FM<Observable<TinyNet.Response>, Observable<TinyNet.Response>, NetMiddleware>? = reMapOut) {
        self.destFactor = destFactor
        super.init(input: input, output: output)
    }
}

func reMapOut(b: Observable<TinyNet.Response>, c: NetMiddleware) -> Observable<TinyNet.Response> {

    guard let c = c as? ReMapM else {
        return b
    }

    return b.map { res in
        res.destFactor = c.destFactor
        return res
    }
}

//MARK: - 插件 用于打印日志
class LogM: NetMiddleware {
    var dataRequest: DataRequest?
    static let dateFormatter = {
        let dateFormatter =  DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        return dateFormatter
    }()
    
    override init(input: FM<DataRequest, DataRequest, NetMiddleware>? = logIn,
                  output: FM<Observable<TinyNet.Response>, Observable<TinyNet.Response>, NetMiddleware>? = logOut) {
        super.init(input: input, output: output)
    }
}

func logIn(a: DataRequest, c: NetMiddleware) -> DataRequest {
    guard let c = c as? LogM else {
        return a
    }

    c.dataRequest = a

    if let urlRequest = try? a.convertible.asURLRequest() {
        
        var bodyDes: String?
        if let body = urlRequest.httpBody {
            let json = JSON(data: body)
            bodyDes = json.description
        }
        
        let output = """
                🔵 ====== Request ====== [\(LogM.dateFormatter.string(from: Date()))]
                \t\(urlRequest.httpMethod ?? "null")\t\t\(urlRequest.description)
                \t-------------------
                \t\(urlRequest.allHTTPHeaderFields as AnyObject)
                \t-------------------
                \t\(bodyDes ?? "null")
                ========================
                """
        print(output)
    } else {
        print("🟡 Invalid request for \(a).")
    }
    return a
}

func logOut(b: Observable<TinyNet.Response>, c: NetMiddleware) -> Observable<TinyNet.Response> {

    guard let c = c as? LogM else {
        return b
    }

    return b.do { res in

        if let urlRequest = try? c.dataRequest?.convertible.asURLRequest() {

            var dataSource = "[Remote]"

            if res.request == nil {
                dataSource = "[Cache]"
            }

            let data = urlRequest.httpBody
            let json = JSON(data: data)
            let body = json.description

            let output = """
                     ====== Response ====== [\(LogM.dateFormatter.string(from: Date()))]
                     \t\(dataSource)
                     \t-------------------
                     \t\(res.statusCode)\t\t\(urlRequest.description)
                     \t-------------------
                     \t\(body)
                     =========================
                     """
            if res.statusCode == 200 {
                print("🟢", output)
            } else {
                print("🔴", output)
            }
        } else {
            print("🟡 Received empty network response for \(res).")
        }

    } onError: { error in
        print("🔴", error)
    }
}

enum TargetViewType {
    case view(UIView)
    case viewController(UIViewController)
    case none // 与loading逻辑无关，只监控请求的状态
}

//MARK: - 插件 用于显示Loading状态
class LoadingM: NetMiddleware {
    let loadingType: TargetViewType
    let loadingDelay: TimeInterval
    var isDone = false
    
    init(_ loadingType: TargetViewType, loadingDelay: TimeInterval = 0,
         input: FM<DataRequest, DataRequest, NetMiddleware>? = loadingIn,
         output: FM<Observable<TinyNet.Response>, Observable<TinyNet.Response>, NetMiddleware>? = loadingOut) {
        self.loadingType = loadingType
        self.loadingDelay = loadingDelay
        super.init(input: input, output: output)
    }
}

func loadingIn(a: DataRequest, c: NetMiddleware) -> DataRequest {
    guard let c = c as? LoadingM else {
        return a
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + c.loadingDelay) {
        if !c.isDone {
            switch c.loadingType {
            case .view(let value):
                // TODO: 状态页设计
                DispatchQueue.main.async {
                }
            case .viewController:
                print("show loading HUD")
                TinyHUD(.plainText, "loading...").show()
            case .none: break

            }
        }
    }

    return a
}

func loadingOut (b: Observable<TinyNet.Response>, c: NetMiddleware) -> Observable<TinyNet.Response> {
    guard let c = c as? LoadingM else {
        return b
    }

    c.isDone = true

    return b.do { res in

        let json = JSON(data: res.data)
        let result = json.responseResult(with: res.destFactor)
        let (suc, (code, message)) = result
        if suc {
            success(res, loadingType: c.loadingType)
        } else {
            let error = TinyNetError.statusCode(res)
            failure(loadingType: c.loadingType, result: result)
        }

    } onError: { error in

        failure(loadingType: c.loadingType, error: error)
    }
}

func success(_ response: TinyNet.Response, loadingType: TargetViewType) {
    switch loadingType {
    case .view(let value):
        // TODO: 状态页设计
        DispatchQueue.main.async {
        }
    case .viewController:
        print("show success HUD")
    case .none: break
    }
}

func failure(loadingType: TargetViewType, result: TinyNetResult? = nil, error: Error? = nil) {

    switch loadingType {
    case .view(let value):
        // TODO: 状态页设计
        DispatchQueue.main.async {
        }
    case .viewController:

        print("show failure HUD")

    case .none: break
    }

}

//MARK: - 插件 用于缓存
class CacheM: NetMiddleware {
    var dataRequest: DataRequest?
    
    override init(input: FM<DataRequest, DataRequest, NetMiddleware>? = cacheIn,
                  output: FM<Observable<TinyNet.Response>, Observable<TinyNet.Response>, NetMiddleware>? = cacheOut) {
        super.init(input: input, output: output)
    }
}

func cacheIn(a: DataRequest, c: NetMiddleware) -> DataRequest {
    guard let c = c as? CacheM else {
        return a
    }

    c.dataRequest = a

    return a
}

func cacheOut (b: Observable<TinyNet.Response>, c: NetMiddleware) -> Observable<TinyNet.Response> {

    guard let c = c as? CacheM,
          let dataRequest = c.dataRequest else {
              return b
          }

    if let result = try? NetCache.share.get(dataRequest.cacheKey()) {
        return Observable.just(result).concat(b)
    }

    return b.do { res in
        try? NetCache.share.put(res, for: dataRequest.cacheKey())
    }
}


