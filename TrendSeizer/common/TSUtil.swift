//
//  TSUtil.swift
//  TrendSeizer
//
//  Created by lizhenghao on 2020/4/16.
//  Copyright © 2020 lizhenghao. All rights reserved.
//

import UIKit

extension UIView{
    
    class func defaultNibView() -> Self {
        let name = String(describing: self)
        let ary = Bundle.main.loadNibNamed(name, owner: self, options: nil)
        
        return ary?.first as! Self
    }
}

extension UISegmentedControl {
    func removeBorders() {
        setBackgroundImage(imageWithColor(color: backgroundColor ?? .clear), for: .normal, barMetrics: .default)
        setBackgroundImage(imageWithColor(color: tintColor!), for: .selected, barMetrics: .default)
        setDividerImage(imageWithColor(color: UIColor.clear), forLeftSegmentState: .normal, rightSegmentState: .normal, barMetrics: .default)
    }

    // create a 1x1 image with this color
    private func imageWithColor(color: UIColor) -> UIImage {
        let rect = CGRect(x: 0.0, y: 0.0, width:  1.0, height: 1.0)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()
        context!.setFillColor(color.cgColor);
        context!.fill(rect);
        let image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return image!
    }
}
