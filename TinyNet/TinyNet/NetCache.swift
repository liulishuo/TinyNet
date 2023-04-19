//
//  NetCache.swift
//  TinyNet
//
//  Created by liulishuo on 2021/8/17.
//

import Foundation
import Cache

public class NetCache {
    static let share = NetCache()

    private let responseStorage = try? Storage<String, TinyNet.Response>(
        diskConfig: DiskConfig(name: "NetworkCache"),
        memoryConfig: MemoryConfig(),
        transformer: TransformerFactory.forResponse(TinyNet.Response.self)
    )

    func put(_ response: TinyNet.Response, for key: String) throws {
        try responseStorage?.setObject(response, forKey: key)
    }

    func get(_ key: String) throws -> TinyNet.Response? {
        try responseStorage?.object(forKey: key)
    }
}

extension TransformerFactory {

    struct DestructuringFactorSeed: Codable {
        var successValue: Int
        var statusCodeKey: String
        var messageKey: String
        var modelKey: String
    }

    struct NetResponseSeed: Codable {
        /// The status code of the response.
        public let statusCode: Int
        /// The response data.
        public let data: Data?

        public let destFactorSeed: DestructuringFactorSeed
    }

    static func forResponse(_ type: TinyNet.Response.Type) -> Transformer<TinyNet.Response> {

        let toData: (TinyNet.Response) throws -> Data = { response in
            let p = response.destFactor
            let destFactorSeed = DestructuringFactorSeed(successValue: p.successCode, statusCodeKey: p.statusCodeKey, messageKey: p.messageKey, modelKey: p.modelKey)
            let seed = NetResponseSeed(statusCode: response.statusCode, data: response.data, destFactorSeed: destFactorSeed)
            let encoder = JSONEncoder()
            return try encoder.encode(seed)
        }

        let fromData: (Data) throws -> TinyNet.Response = { data in
            let decoder = JSONDecoder()
            let seed = try decoder.decode(NetResponseSeed.self, from: data)
            let response = TinyNet.Response(statusCode: seed.statusCode, data: seed.data)
            let destFactorSeed = seed.destFactorSeed
            response.destFactor = DestructuringFactor(successCode: destFactorSeed.successValue, statusCodeKey: destFactorSeed.statusCodeKey,
                                                      messageKey: destFactorSeed.messageKey,
                                                      modelKey: destFactorSeed.modelKey)
            return response
        }

        return Transformer<TinyNet.Response>(toData: toData, fromData: fromData)
    }
}
