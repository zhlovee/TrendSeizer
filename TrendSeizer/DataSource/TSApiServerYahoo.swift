//
//  TSApiServerYahoo.swift
//  TrendSeizer
//
//  Created by lizhenghao on 2020/4/22.
//  Copyright © 2020 lizhenghao. All rights reserved.
//

import Foundation

//Allowed values are (1d | 5d | 3mo | 6mo | 1y | 5y | max)
enum TSChartRange : String,Codable,CaseIterable {
    case r1day = "1d"
    case r5day = "5d"
    case r1month = "1mo"
    case r3month = "3mo"
    case r6month = "6mo"
    case r1year = "1y"
    case r2year = "2y"
    case r5year = "5y"
    case r10year = "10y"
    case rYtd = "ytd"
    case rMax = "max"
}

struct TSApiServerYahoo : TSApiServerProtocol ,TSViewDataSource{
    let key: String = "a663013a3cmsh73a53f9b12056bep1ebe99jsn2a2e57c26a59"
    let host: String = "apidojo-yahoo-finance-v1.p.rapidapi.com"
    let publicParam: [String : String] = ["region":"HK","lang":"zh"]
    
    struct MarketGetChart : TSReqBaseProtocol {
        var server : TSApiServerProtocol
        var isValidRequest: Bool {
            !param.isEmpty
        }
        typealias MapModel = ESModelGetCharts
        let path: String = "market/get-charts"
        
        var param : [String : String] {
            
            let intervalParam : String
            switch interval {
            case .i5min:
                intervalParam = "5m"
                break
            case .i15min:
                intervalParam = "15m"
                break
            case .i1day:
                intervalParam = "1d"
                break
            case .i1week:
                intervalParam = "1wk"
                break
            case .i1month:
                intervalParam = "1mo"
                break
            default :
                return [:]
            }

            var pp = ["symbol":symbol,"interval":intervalParam,"range":range.rawValue]
            if let comp = self.comparisons {
                pp["comparisons"] = comp.joined(separator: ",")
            }
            return pp
        }
        let symbol : String
        let interval : TSChartInterval
        let range : TSChartRange
        var comparisons : [String]?
    }
    
    struct StockGetHistories : TSReqBaseProtocol {
        var server: TSApiServerProtocol
        typealias MapModel = ESModelGetCharts
        var path: String = "stock/get-histories"
        var isValidRequest: Bool {
            !param.isEmpty
        }
        var param : [String : String] {
            
            //Allowed values are (1d|5d|1mo|3mo|6mo|1y|2y|5y|max)
            let intervalParam : String
            switch interval {
            case .i1day:
                intervalParam = "1d"
                break
            case .i1week:
                intervalParam = "5d"
                break
            case .i1month:
                intervalParam = "1mo"
                break
            case .i3month:
                intervalParam = "3mo"
                break
            case .i6month:
                intervalParam = "3mo"
                break
            case .i1year:
                intervalParam = "1y"
                break
            case .i2year:
                intervalParam = "2y"
                break
            case .i5year:
                intervalParam = "5y"
                break
            default :
                return [:]
            }
            
            let pp = [
                "symbol" : symbol,
                "from" : "\(Int(from))",
                "to" : "\(Int(to))",
                "events" : events.rawValue,
                "interval" : intervalParam,
            ]
            return pp
        }
        let symbol : String
        let from : TimeInterval
        let to : TimeInterval
        let events : Events
        let interval : TSChartInterval
        enum Events : String {
            case div,split,earn
        }
    }
    
    struct TSReqAutoComplete : TSReqBaseProtocol {
        var server: TSApiServerProtocol
        typealias MapModel = ESModelAutoComplete
        var path : String = "market/auto-complete"
        var param : [String : String] { ["query":queryStr] }
        let queryStr : String
    }

    struct TSReqGetQuotes : TSReqBaseProtocol {
        var server: TSApiServerProtocol
        typealias MapModel = ESModelGetQuotes
        var path : String = "market/get-quotes"
        var symbols : [String]
        var param : [String : String] { ["symbols":symbols.joined(separator: ",")] }
    }

    struct TSReqGetMovers : TSReqBaseProtocol {
        var server: TSApiServerProtocol
        typealias MapModel = ESModelGetMovers
        var path : String = "market/get-movers"
        var param : [String : String] {
            var pp = [String : String]()
            if let st = self.start {
                pp["start"] = "\(st)"
            }
            if let ct = self.count {
                pp["count"] = "\(ct)"
            }
            return pp
        }
        let start : Int?
        let count : Int?
    }

    struct TSReqGetSummary : TSReqBaseProtocol {
        var server: TSApiServerProtocol
        typealias MapModel = ESModelGetSummary
        var path : String = "market/get-summary"
        var param : [String : String] { [:] }
    }
    
    func fetchCandles(symbol: String, interval: TSChartInterval, from: TimeInterval, to: TimeInterval, callback: @escaping (TSViewModelKLine?, TSNetworkError?) -> Void) {
        if interval.timeValue() < TSChartInterval.i1day.timeValue() {
            MarketGetChart(server: self, symbol: symbol, interval: interval, range: .rMax, comparisons: nil).query(callback: callback)
        }else{
            StockGetHistories(server: self, symbol: symbol, from: from, to: to, events: .div, interval: interval).query(callback: callback)
        }
    }
}

// market-get_chart
struct ESChartComparison : Codable {
    let close : [Double?]
    let gmtoffset : TimeInterval
    let previousClose  : Double?
    let symbol : String
}

struct ESChartQuote : Codable{
    let close : [Double?]
    let high : [Double?]
    let low : [Double?]
    let open : [Double?]
    let volume : [Int?]
}

struct ESChartTradePeriod : Codable {
    let end : TimeInterval
    let gmtoffset : TimeInterval
    let start : TimeInterval
    let timezone : String
}

struct ESModelGetCharts : TSJSONModel {
    typealias ViewModel = TSViewModelKLine
    var viewModel: TSViewModelKLine?{
        guard let quotes = self.chart.result?.first?.indicators?.quote?.first,
            let times = self.chart.result?.first?.timestamp
            else {
            return nil
        }
        
        var candleIdx = 0
        var candles = [TSDrawCandle]()
        for (idx, close) in quotes.close.enumerated() {
            guard let close = close,
                let high = quotes.high[idx],
                let low = quotes.low[idx],
                let open = quotes.open[idx]
            else {
                continue
            }
            let time = times[idx]

            let candle = TSDrawCandle(close: close, high: high, low: low, open: open, volume: quotes.volume[idx] ?? 0, timestamp:time)
            
            candles.append(candle)
            candleIdx += 1
        }
        return TSViewModelKLine(candles)
    }
    
    let chart : ESChart
    struct ESChart : Codable {
        let error : String?
        let result : [ESResult]?
        struct ESResult : Codable {
            let comparisons : [ESChartComparison]?
            let indicators : ESIndicators?
            struct ESIndicators : Codable {
                let quote : [ESChartQuote]?
            }
            let meta : ESMeta?
            struct ESMeta : Codable {
                let chartPreviousClose : Double?
                let currency : String?
                let currentTradingPeriod : ESCurrentTradingPeriod?
                struct ESCurrentTradingPeriod : Codable {
                    let post : ESChartTradePeriod?
                    let pre : ESChartTradePeriod?
                    let regular : ESChartTradePeriod?
                }
                
                let dataGranularity : String?
                let exchangeName : String?
                let exchangeTimezoneName : String?
                let firstTradeDate : TimeInterval?
                let gmtoffset : TimeInterval?
                let instrumentType : String?
                let previousClose : Double?
                let priceHint : Int?
                let scale : Int?
                let symbol : String?
                let timezone : String?
                let tradingPeriods : [[ESChartTradePeriod]]?
                let validRanges : [TSChartRange]?
            }
            let timestamp : [TimeInterval]?
        }
    }
}

////////////end get chart
struct ESModelAutoComplete : TSJSONModel {
    let ResultSet : ESResultSet
    struct ESResultSet : Codable {
        let Query : String?
        let Result : [ESResult]?
        struct ESResult : Codable {
            let symbol : String?
            let name : String?
            let exch : String?
            let type : String?
            let exchDisp : String?
            let typeDisp : String?
        }
    }
}

struct ESModelGetQuotes : TSJSONModel {
    let quoteResponse : ESQuoteResponse
    struct ESQuoteResponse : Codable {
        let error : String?
        let result : [ESResult]
        struct ESResult : Codable {
            let language : String?
            let region : String?
            let quoteType : String?
            let quoteSourceName : String?
            let exchangeDataDelayedBy : Int?
            let preMarketChange : Double?
            let preMarketChangePercent : Double?
            let preMarketTime : TimeInterval?
            let preMarketPrice : Double?
            let regularMarketChangePercent : Double?
            let regularMarketPreviousClose : Double?
            let fullExchangeName : String?
            let longName : String?
            let marketState : String?
            let exchange : String?
            let sourceInterval : Int?
            let exchangeTimezoneName : String?
            let exchangeTimezoneShortName : String?
            let pageViews : ESPageViews?
            struct ESPageViews : Codable {
                let shortTermTrend : String?
                let midTermTrend : String?
                let longTermTrend : String?
            }
            let gmtOffSetMilliseconds : Int?
            let esgPopulated : Bool?
            let tradeable : Bool?
            let priceHint : Int?
            let shortName : String?
            let market : String?
            let regularMarketPrice : Double?
            let regularMarketTime : TimeInterval?
            let regularMarketChange : Double?
            let regularMarketVolume : Double?
            let symbol : String?
        }
    }
}

struct ESModelGetMovers : TSJSONModel {
    let error : String?
    let Result : [ESResult]?
    struct ESResult : Codable {
        let id : String?
        let title : String?
        let description : String?
        let canonicalName : String?
        let start : Int?
        let count : Int?
        let total : Int?
        let quotes : [ESQuotes]?
        struct ESQuotes : Codable {
            let language : String?
            let region : String?
            let quoteType : String?
            let fullExchangeName : String?
            let esgPopulated : Bool?
            let tradeable : Bool?
            let marketState : String?
            let exchange : String?
            let exchangeDataDelayedBy : Int?
            let market : String?
            let sourceInterval : Int?
            let exchangeTimezoneName : String?
            let exchangeTimezoneShortName : String?
            let gmtOffSetMilliseconds : Int?
            let symbol : String?
        }
        let predefinedScr : Bool?
    }
}


//market/get-summary
struct ESModelGetSummary : TSJSONModel {
    let error : String?
    let result : [ESResult]?
    struct ESResult : Codable {
        let exchangeTimezoneName : String?
        let fullExchangeName : String?
        let symbol : String?
        struct ESRegularMarketValue : Codable {
            let raw : Double?
            let fmt : String?
        }
        let regularMarketChange : ESRegularMarketValue?
        let gmtOffSetMilliseconds : Int?
        let exchangeDataDelayedBy : Int?
        let language : String?
        let regularMarketTime : ESRegularMarketValue?
        let exchangeTimezoneShortName : String?
        let regularMarketChangePercent : ESRegularMarketValue?
        let quoteType : String?
        let marketState : String?
        let regularMarketPrice : ESRegularMarketValue?
        let market : String?
        let tradeable : Bool?
        let exchange : String?
        let sourceInterval : Int?
        let region : String?
        let shortName : String?
        let regularMarketPreviousClose : ESRegularMarketValue?
    }
}
