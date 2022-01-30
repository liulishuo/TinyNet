//
//  Request.swift
//  TinyNet
//
//  Created by liulishuo on 2021/7/19.
//

import Foundation
import Alamofire

enum TestAPI {
    case blogs
    case blog(`id`: String)
}

extension TestAPI: RawRequest {

    var parameters: Parameters? {
        nil
    }

    var path: String {
        switch self {
        case .blogs:
            return "/blogs"
        case let .blog(id):
            return "blogs/\(id)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .blogs, .blog:
            return .get
        }
    }

    var baseURL: URL {
        return URL(string: "https://api.spaceflightnewsapi.net/v3")!
    }

}
