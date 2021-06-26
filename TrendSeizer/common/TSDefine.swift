//
//  TSDefine.swift
//  TrendSeizer
//
//  Created by lizhenghao on 2020/5/7.
//  Copyright © 2020 lizhenghao. All rights reserved.
//

import UIKit


let TSUpplerColor = UIColor.systemRed
let TSDownerColor = UIColor.systemGreen
let TSDefaultColor = UIColor.systemGray

enum ESMAType : Int, CaseIterable {
    case ma5 = 5
    case ma10 = 10
    case ma20 = 20
    case ma30 = 30
    case ma60 = 60
    
    static func valueMap() -> [ESMAType : Double] {
        return [
            .ma5 : 0,
            .ma10 : 0,
            .ma20 : 0,
            .ma30 : 0,
            .ma60 : 0
        ]
    }
    
    func maColor() -> UIColor {
        switch self {
        case .ma5:
            return UIColor { (tc) -> UIColor in
                return tc.userInterfaceStyle == .dark ? UIColor.white : UIColor.gray
            }
        case .ma10:
            return UIColor.systemTeal
        case .ma20:
            return UIColor.systemYellow
        case .ma30:
            return UIColor.systemIndigo
        case .ma60:
            return UIColor.systemPurple
        }
    }
}
