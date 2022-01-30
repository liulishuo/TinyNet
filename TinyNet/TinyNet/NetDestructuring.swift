//
//  NetDestructuring.swift
//  TinyNet
//
//  Created by liulishuo on 2021/7/23.
//

import Foundation

typealias DF = DestructuringFactor
public struct DestructuringFactor: Codable {
    /// 请求成功时状态码对应的值
    var successCode: Int = 200
    /// 状态码对应的键
    var statusCodeKey: String = "code"
    /// 请求后的提示语对应的键
    var messageKey: String = "message|error|msg"
    /// 请求后的主要模型数据的键
    var modelKey: String = "result"
}

let defaultDestructuringFactor = DestructuringFactor()
