//
//  TSApiServerFinnhub.swift
//  TrendSeizer
//
//  Created by lizhenghao on 2020/4/22.
//  Copyright © 2020 lizhenghao. All rights reserved.
//

import Foundation

struct TSApiServerFinnhub : TSApiServerProtocol,TSViewDataSource{
    let key: String = "b45d37b733msh0b7c0f70e4bf35dp1680e2jsn39168d85f938"
    let host: String = "finnhub-realtime-stock-price.p.rapidapi.com"
    let publicParam: [String : String] = [:]
    
    struct StockCandles : TSReqBaseProtocol {
        var server: TSApiServerProtocol
        typealias MapModel = TSModelFinnhubCandles
        let path: String = "stock/candle"
        var isValidRequest: Bool{
            !param.isEmpty
        }
        var param: [String : String] {
            
            var intervalParam : String
            //Supported resolution includes 1, 5, 15, 30, 60, D, W, M
            switch interval {
            case .i5min:
                intervalParam = "5"
                break
            case .i15min:
                intervalParam = "15"
                break
            case .i30min:
                intervalParam = "30"
                break
            case .i1hour:
                intervalParam = "60"
                break
            case .i1day:
                intervalParam = "D"
                break
            case .i1week:
                intervalParam = "W"
                break
            case .i1month:
                intervalParam = "M"
                break
            default :
                return [:]
            }
            
            return [
                        "to": "\(Int(to))",
                    "symbol": symbol,
                      "from": "\(Int(from))",
                "resolution": intervalParam
            ]
        }
        
        var symbol : String
        var interval : TSChartInterval
        var from : TimeInterval
        var to : TimeInterval
    }
    func fetchCandles(symbol: String, interval: TSChartInterval, from: TimeInterval, to: TimeInterval, callback: @escaping (TSViewModelKLine?, TSNetworkError?) -> Void) -> Void {
        StockCandles(server: self, symbol: symbol, interval: interval, from: from, to: to).query(callback: callback)
    }
}

//MARK - Finnhub realtime stock
struct TSModelFinnhubCandles : TSJSONModel {
    typealias ViewModel = TSViewModelKLine
    var viewModel: TSViewModelKLine?{
        guard self.status == "ok",
            let times = self.timestamp,
            times.count > 0,
            let closes = self.close,
            let highs = self.high,
            let opens = self.open,
            let lows = self.low,
            let volumes = self.volume
        else {
            return nil
        }
        var candles : [TSDrawCandle] = []
        
//        let df = DateFormatter()
//        df.dateFormat = "YY/MM/dd HH:mm"
        
        for (idx,timestamp) in times.enumerated() {
            guard
            let close = closes.count > idx ? closes[idx]:0,
            let high = highs.count > idx ? highs[idx]:0,
            let low = lows.count > idx ? lows[idx]:0,
            let open = opens.count > idx ? opens[idx]:0,
            let volume = volumes.count > idx ? volumes[idx]:0
            else {
                let cd = TSDrawCandle(close: closes[idx] ?? 0, high: highs[idx] ?? 0, low: lows[idx] ?? 0, open: opens[idx] ?? 0, volume: volumes[idx] ?? 0, timestamp: timestamp)
                candles.append(cd)
                continue
            }
            
            
//            print(df.string(from: Date(timeIntervalSince1970: timestamp)))
            
            let cd = TSDrawCandle(close: close, high: high, low: low, open: open, volume: volume, timestamp: timestamp)
            
            candles.append(cd)
        }
        
        return TSViewModelKLine(candles)
    }
    
    let close : [Double?]?
    let high : [Double?]?
    let low : [Double?]?
    let open : [Double?]?
    let status : String??
    let timestamp : [TimeInterval]?
    let volume : [Int?]?
    enum CodingKeys : String, CodingKey {
        case close = "c"
        case high = "h"
        case low = "l"
        case open = "o"
        case status = "s"
        case timestamp = "t"
        case volume = "v"
    }
}
