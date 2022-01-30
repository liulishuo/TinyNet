//
//  demo.swift
//  TinyNet
//
//  Created by liulishuo on 2021/7/22.
//

import Foundation
import Alamofire
import RxSwift

extension TinyNet {
    static func startCLL(on viewController: UIViewController) -> F<DataRequest, Observable<TinyNet.Response>> {
        let logM = LogM()
        let loadingM = LoadingM(.viewController(viewController))
        let cacheM = CacheM()
        let reMapM = ReMapM(destFactor: DestructuringFactor(successCode: 100))

        return TinyNet.start^cacheM^reMapM^loadingM^logM
    }
}

func demo(on viewController: UIViewController) {

//    let s =  TinyNet.startCLL(on: viewController)(TinyNet.pack(TestAPI.blogs)!)

    let s = TinyNet.start ^
        ReMapM(destFactor: DF(successCode: 200, statusCodeKey: "code", messageKey: "message", modelKey: "")) ^
        LoadingM(.viewController(viewController), loadingDelay: 1) ^
        LogM() ^
        TestAPI.blogs

    s?.mapArrayResult(RModel.Blog.self)
        .subscribe { result in
        /// HTTP Code == 200
        /// code 是业务状态码
         let ((suc, (code, message)), model) = result
            print("===>", suc, code, message, model)
    } onError: { error in
        /// HTTP Code != 200
        print("===> E: ", error)
    }

//    let s = TinyNet.start ^
//        ReMapM(destFactor: DF(successCode: 200, statusCodeKey: "code", messageKey: "message", modelKey: "")) ^
//        LoadingM(.viewController(viewController), loadingDelay: 1) ^
//        LogM() ^
//        TestAPI.blog(`id`: "1")
//
//    s?.mapObjResult(RModel.Blog.self)
//        .subscribe { result in
//        /// HTTP Code == 200
//        /// code 是业务状态码
//         let ((suc, (code, message)), model) = result
//            print("===>", suc, code, message, model)
//    } onError: { error in
//        /// HTTP Code != 200
//        print("===> E: ", error)
//    }

    return
}


