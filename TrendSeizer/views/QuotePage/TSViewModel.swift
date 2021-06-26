//
//  TSViewModelKLine.swift
//  TrendSeizer
//
//  Created by lizhenghao on 2020/4/30.
//  Copyright © 2020 lizhenghao. All rights reserved.
//

import UIKit

struct TSDrawMACD {
    let ema12 : Double
    let ema26 : Double
    let DIF : Double
    let DEA : Double
    let BAR : Double
}
struct TSDrawMA {
    var quote : [ESMAType : Double] = [:]
}

struct TSViewModelKLine {
    var candles : [TSDrawCandle] {
        didSet{
            self.calcSkills()
        }
    }
    
    var today : TSDrawCandle? {
        return candles.last
    }
    
    var times : [TimeInterval] = []
    var skillMA : [TSDrawMA] = []
    var skillMACD : [TSDrawMACD] = []
    
    mutating func calcSkills() -> Void {
        guard candles.count > 0 else {
            return
        }
        
        self.times.removeAll()
        //ma
        self.skillMA.removeAll()
        var valueMap = ESMAType.valueMap()
        //macd
        var aryEma12 : [Double] = []
        var aryEma26 : [Double] = []
        var aryDIF : [Double] = []
        var aryDEA : [Double] = []
        var aryBAR : [Double] = []
        self.skillMACD.removeAll()
        //loop
        for (idx, cd) in candles.enumerated() {
            //calc skill MA //
            var ma = TSDrawMA()
            for maTp in ESMAType.allCases {
                if var maVal = valueMap[maTp] {
                    if idx < maTp.rawValue {
                        maVal += cd.close
                        if idx == maTp.rawValue - 1 {
                            ma.quote[maTp] = maVal/Double(maTp.rawValue)
                        }
                    }else {
                        maVal = maVal + cd.close - candles[idx - maTp.rawValue].close
                        ma.quote[maTp] = maVal/Double(maTp.rawValue)
                    }
                    valueMap[maTp] = maVal
                }
            }
            skillMA.append(ma)
            times.append(cd.timestamp)
            
            //calc skil macd //
            var ema12 = cd.close
            var ema26 = cd.close
            if idx != 0 {
                ema12 = aryEma12[idx-1]*11.0/13.0 + ema12*2.0/13.0
                ema26 = aryEma26[idx-1]*25.0/27.0 + ema26*2.0/27.0
            }
            aryEma12.append(ema12)
            aryEma26.append(ema26)
            let dif = ema12 - ema26
            aryDIF.append(dif)
            var dea = dif
            if idx != 0 {
                dea = aryDEA[idx-1]*8.0/10.0 + dea*2.0/10.0
            }
            aryDEA.append(dea)
            
            let bar = 2*(dif - dea)
            aryBAR.append(bar)
            if idx < 26 {
                self.skillMACD.append(TSDrawMACD(ema12: 0, ema26: 0, DIF: 0, DEA: 0, BAR: 0))
            }else{
                let macd = TSDrawMACD(ema12: ema12, ema26: ema26, DIF: dif, DEA: dea, BAR: bar)
                self.skillMACD.append(macd)
            }
        }
    }
    
    init(_ cds : [TSDrawCandle]?) {
        guard let cds_ary = cds,
            cds_ary.count > 0
        else {
            candles = [];times = []
            return
        }
        candles = cds_ary
        self.calcSkills()
    }
}



struct TSDrawCandle {
    let close : Double
    let high : Double
    let low : Double
    let open : Double
    let volume : Int
    let timestamp : TimeInterval

    var stokeColor : UIColor {
        return close > open ? TSUpplerColor : TSDownerColor
    }
    var fillColor : UIColor {
        return close > open ? UIColor.clear : TSDownerColor
    }
    var bodyLow : Double{
        return min(close, open)
    }
    var bodyHigh : Double{
        return max(close, open)
    }
    var bodyLength : Double {
        return abs((close - open))
    }
    var upperLength : Double {
        return abs(high - bodyHigh)
    }

    var length : Double {
        return abs(high - low)
    }
    var hasBody : Bool {
        return close == open
    }
}

struct TSVisualIndex {
    var section : String
    var column : Int
    var path : String {
        return section + "#\(column)"
    }
}
