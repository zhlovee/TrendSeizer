//
//  TSDataSource.swift
//  TrendSeizer
//
//  Created by lizhenghao on 2020/4/22.
//  Copyright © 2020 lizhenghao. All rights reserved.
//

import Foundation

enum TSChartInterval : String, Codable,CaseIterable {
//    case i1min
    case i5min = "5分钟"
    case i15min = "15分钟"
    case i30min = "半小时"
    case i1hour = "时"
    case i1day = "日"
    case i1week = "周"
    case i1month = "月"
    case i3month = "一季度"
    case i6month = "半年"
    case i1year = "1年"
    case i2year = "2年"
    case i5year = "5年"
    
    func timeValue() -> TimeInterval {
        switch self {
        case .i5min:
            return 5*60
        case .i15min:
            return 5*60*3
        case .i30min:
            return 5*60*6
        case .i1hour:
            return 5*60*12
        case .i1day:
            return 5*60*12*24
        case .i1week:
            return 5*60*12*24*5
        case .i1month:
            return 5*60*12*24*30
        case .i3month:
            return 5*60*12*24*30*3
        case .i6month:
            return 5*60*12*24*30*6
        case .i1year:
            return 5*60*12*24*30*12
        case .i2year:
            return 5*60*12*24*30*12*2
        case .i5year:
            return 5*60*12*24*30*12*5
        }
        
    }
}

protocol TSViewDataSource {
    func fetchCandles(symbol:String, interval:TSChartInterval, from:TimeInterval, to:TimeInterval, callback: @escaping (TSViewModelKLine?, TSNetworkError?) -> Void) -> Void
}

extension TSViewDataSource {
    func fetchCandles(symbol:String, interval:TSChartInterval, from:TimeInterval, to:TimeInterval, callback: @escaping (TSViewModelKLine?, TSNetworkError?) -> Void) -> Void {
        callback(nil,.eInfo("not support fetch candles"))
    }
}


enum TSParseOption : Int {
    case oMerge30min
}

class TSDataSource : NSObject, URLSessionDelegate,TSViewDataSource
{
//    static let shared2 :TSDataSource = TSDataSource();
    private static let _instance = TSDataSource();
    public class var shared : TSDataSource {
        get {
            return _instance;
        }
    }
    
    private let curServer : TSViewDataSource = TSApiServerFinnhub()
//    private let curServer : TSViewDataSource = TSApiServerYahoo()

    func doGetRequest<T:TSJSONModel>(server: TSApiServerProtocol, path:String, param:[String:String], parseT:T.Type, callback:@escaping (T?, TSNetworkError?) -> Void) -> Void {

        let headers = [
            "x-rapidapi-host": server.host,
            "x-rapidapi-key": server.key
        ]
        
        //
        var allParam : [String:String] = server.publicParam
        if !param.isEmpty {
            allParam.merge(param) { (key1, _) -> String in key1}
        }
        
//        var ary = ["fdsf","fdsgb"].compp
        
        let basePath = "https://\(server.host)/\(path)?"
        var urlStr = ""
        for (index,item) in allParam.enumerated() {
            urlStr += "\(item.key)=\(item.value)"
            if index != allParam.count-1 {
                urlStr += "&"
            }
        }
        urlStr = basePath + (urlStr.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? urlStr)
        
        print("TS#DO Request : \(urlStr)")
        let request = NSMutableURLRequest(url: NSURL(string:urlStr)! as URL,
                                                cachePolicy: .useProtocolCachePolicy,
                                            timeoutInterval: 60.0)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers

        let session = URLSession.init(configuration: .default, delegate: self, delegateQueue: nil)
        
        let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
            if let err = error {
                callback(nil,TSNetworkError.eWrapError(err))
            } else {
                let resposeCode = (response as? HTTPURLResponse)?.statusCode
                if resposeCode != 200 {
                    callback(nil,TSNetworkError.eInfo("NetResponsError code:\(String(describing: resposeCode))"))
                }else{
                    if let dd = data {
                        let ss = String(data: dd, encoding: .utf8) ?? "UnKown JSON"
                        print("TS#Net Response:\(ss)")
                        do {
                            let json = try JSONDecoder().decode(parseT, from: dd)
                            callback(json,nil)
                        } catch {
                            callback(nil,.eWrapError(error))
                        }
                    }else{
                        callback(nil,.eWrapError(error!))
                    }
                }
            }
        })

        dataTask.resume()
    }
    
    func urlSession(_ session: URLSession,
         didReceive challenge: URLAuthenticationChallenge,
            completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
    
    
    func fetchCandles(symbol: String, interval: TSChartInterval, from: TimeInterval, to: TimeInterval, callback: @escaping (TSViewModelKLine?, TSNetworkError?) -> Void) {
        if interval == .i1hour {
            curServer.fetchCandles(symbol: symbol, interval: .i30min, from: from, to: to) { (model, error) in
                if let km = model {
                    let cdHours = self.__mergeCandles30To60(model: km)
                    callback(cdHours,nil)
                }else{
                    callback(model,error)
                }
            }
        }else{
            curServer.fetchCandles(symbol: symbol, interval: interval, from: from, to: to, callback: callback)
        }
    }
    

    /**
     
     d1
     20/03/12 09:30 - 10:00
     20/03/12 10:00 - 10:30
     
     d2
     20/03/12 10:30 - 11:00
     20/03/12 11:00 - 11:30
     
     dNull
     20/03/12 11:30

     d3
     20/03/12 13:00 - 13:30
     20/03/12 13:30 - 14:00
     
     d4
     20/03/12 14:00 - 14:30
     20/03/12 14:30 - 15:00
        
     */
    private func __mergeCandles30To60(model : TSViewModelKLine) -> TSViewModelKLine {
        var map : [String : TSDrawCandle] = [:]
        let cmps : Set<Calendar.Component> = [.year,.month,.day,.hour,.minute]
        for candle in model.candles {
            
            let dc = Calendar.current.dateComponents(cmps, from: Date(timeIntervalSince1970: candle.timestamp))
            guard let year = dc.year, let month = dc.month, let day = dc.day, let hour = dc.hour, let minute = dc.minute else {
                continue
            }
            
            var visual = TSVisualIndex(section: "\(year)/\(month)/\(day)", column: 0)
            if (hour == 9 && minute == 30) || (hour == 10 && minute == 0) {
                visual.column = 1
            }else if (hour == 10 && minute == 30) || (hour == 11 && minute == 0) {
                visual.column = 2
            }else if hour == 13 {
                visual.column = 3
            }else if hour == 14 {
                visual.column = 4
            }
            guard visual.column != 0 else {
                continue
            }
            var newCandle = candle
            let timeKey = visual.path
            if let existCd = map[timeKey] {
                let new = candle.timestamp > existCd.timestamp
                newCandle = TSDrawCandle(close: (new ? candle.close : existCd.close), high: max(candle.high, existCd.high), low: min(candle.low, existCd.low), open: (new ? existCd.open : candle.open), volume: existCd.volume+candle.volume, timestamp: (new ? existCd.timestamp : candle.timestamp))
            }
            map[timeKey] = newCandle
        }
        let ma_ary = map.values.sorted { (cd1, cd2) -> Bool in
            cd1.timestamp < cd2.timestamp
        }

        
        return TSViewModelKLine(ma_ary)
    }
    
    func testCodeSnippet(){
//        let headers = [
//            "x-rapidapi-host": "finnhub-realtime-stock-price.p.rapidapi.com",
//            "x-rapidapi-key": "b45d37b733msh0b7c0f70e4bf35dp1680e2jsn39168d85f938"
//        ]
//
//        let request = NSMutableURLRequest(url: NSURL(string: "https://finnhub-realtime-stock-price.p.rapidapi.com/stock/candle?to=1586880000&symbol=000001.SS&from=1586793600&resolution=30")! as URL,
//                                                cachePolicy: .useProtocolCachePolicy,
//                                            timeoutInterval: 10.0)
//
//        print("TS#DO Request : \(request.url?.absoluteString)")
//
//
//        request.httpMethod = "GET"
//        request.allHTTPHeaderFields = headers
//
//        let session = URLSession.init(configuration: .default, delegate: self, delegateQueue: nil)
//        let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
//            if (error != nil) {
//                print(error)
//            } else {
//                let resposeCode = (response as? HTTPURLResponse)?.statusCode
//                if resposeCode != 200 {
//
//                }else{
//                    if let dd = data {
//                        let sss = String(data: dd, encoding: .utf8)
//                        print(sss)
//                    }else{
//
//                    }
//                }
//            }
//        })
//
//        dataTask.resume()
    }
}

public enum TSNetworkError : Error{
    case eInfo(String)
    case eWrapError(Error)
    
    func reason() -> String {
        switch self {
        case .eInfo(let reasonStr):
            return reasonStr;
        case .eWrapError(let error):
            print(error)
            return "net work error occured";
        }
    }
}
