//
//  TSApiServer.swift
//  TrendSeizer
//
//  Created by lizhenghao on 2020/4/22.
//  Copyright © 2020 lizhenghao. All rights reserved.
//

import Foundation


protocol TSApiServerProtocol {
    var key:String { get }
    var host:String { get }
    var publicParam:[String:String] { get }
}

protocol TSReqBaseProtocol {
    associatedtype MapModel : TSJSONModel
    var server : TSApiServerProtocol { get }
    var path : String { get }
    var param : [String : String] { get }
    var isValidRequest : Bool { get }
}

extension TSReqBaseProtocol {
    var isValidRequest : Bool { true }
    func query(callback:@escaping (MapModel.ViewModel?, TSNetworkError?) -> Void) -> Void {
        if isValidRequest {
            TSDataSource.shared.doGetRequest(server: server, path: path, param: param, parseT: MapModel.self) { (model, error) in
                if let err = error {
                    DispatchQueue.main.async {
                        callback(nil,err)
                    }
                }else{
                    if let parsedModel = model?.viewModel {
                        DispatchQueue.main.async {
                            callback(parsedModel,nil)
                        }
                    }else {
                        DispatchQueue.main.async {
                            callback(nil,.eInfo("parsed error"))
                        }
                    }
                }
            }
        }else{
            callback(nil,.eInfo("invalid request"))
        }
    }
}

protocol TSJSONModel : Codable {
    associatedtype ViewModel = Self
    var viewModel : ViewModel? { get }
}

extension TSJSONModel {
    var viewModel : ViewModel? {
        return self as? Self.ViewModel
    }
}
