//
//  Blog.swift
//  TinyNet
//
//  Created by liulishuo on 2021/8/18.
//

import Foundation

extension ResponseModel {

    struct Blog: TinyDecodable {
        var `id`: Int?
        var title: String?
        var url: String?
        var launches: [Launche]?
    }

    struct Launche: TinyDecodable {
        var id: String?
        var provider: String?
    }
}
