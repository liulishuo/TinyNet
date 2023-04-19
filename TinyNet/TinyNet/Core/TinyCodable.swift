//
//  TinyDecodable.swift
//  TinyNet
//
//  Created by liulishuo on 2021/8/17.
//

import Foundation

public typealias Modelable = TinyDecodable

public protocol TinyDecodable: Decodable {

    init()

    mutating func mapping(_ json: JSON)

    /// 自定义解析策略
    func keyDecodingStrategy() -> JSONDecoder.KeyDecodingStrategy
}

public extension Modelable {

    mutating func mapping(_ json: JSON) {}

    func keyDecodingStrategy() -> JSONDecoder.KeyDecodingStrategy {
        return .useDefaultKeys
    }
}

