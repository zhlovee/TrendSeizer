//
//  ESQuotePage.swift
//  EasyEase
//
//  Created by lizhenghao on 2020/3/30.
//  Copyright © 2020 lizhenghao. All rights reserved.
//

import UIKit

import Toast


class TSIntervalPickerView : UIPickerView,UIPickerViewDataSource,UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return intervals.count
    }
//    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
//    }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return intervals[row].rawValue
    }
    
    var intervals : [TSChartInterval] = [] {
        didSet{
            self.reloadAllComponents()
        }
    }
    var curInterval : TSChartInterval {
        intervals[self.selectedRow(inComponent: 0)]
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.dataSource = self
        self.delegate = self
    }
}

private class ESLineMALayer : CAShapeLayer {
    let maType : ESMAType
    var movePath : UIBezierPath?
    
    init(maType:ESMAType) {
        self.maType = maType
        super.init()
        self.lineWidth = 1
        self.fillColor = UIColor.clear.cgColor
        self.strokeColor = maType.maColor().cgColor
        self.lineJoin = CAShapeLayerLineJoin.round
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) do not call this to init")
    }
}

private class TSCandleLayer : CAShapeLayer {
    var data : TSDrawCandle?
    var focusPos : CGPoint = CGPoint.zero
    func isInCandleArea(point : CGPoint) -> Bool {
        let rect = self.frame.inset(by: UIEdgeInsets(top: -2, left: -5, bottom: -2, right: -5))
        return rect.contains(point)
    }
    func isInXArea(posX : CGFloat) -> Bool {
        return self.frame.minX <= posX && self.frame.maxX >= posX
    }
}

class TSTimeLineView : UIView {
    
    var scaleLayer : CALayer? = nil
    var midLayer : CAShapeLayer? = nil
    var scaleRangeLayer : CALayer? = nil
    var rangeLayer : CALayer? = nil
    
    var times : [TimeInterval]? = nil
    var interval : TSChartInterval? = nil
    var curRange : NSRange? = nil
    
    var isScaling : Bool = false
    
    var rangeChangeCallback : ((_ newRange:NSRange)->Void)? = nil
    
    struct TimeIndicatorBuilder {
        let baseSize : CGSize
        let baseColor : UIColor
        let level : Int
    }

    private func __refreshIndicators(rangeTimes:[TimeInterval], drawLayer:CALayer) -> Void {
        let baseCps = [Calendar.Component.year,.month,.weekOfMonth,.day,.hour,.minute]
        let timeLength = rangeTimes.last! - rangeTimes.first!
        
        let firstComp = Calendar.current.dateComponents(Set(baseCps), from: Date(timeIntervalSince1970: rangeTimes.first!))
        let lastComp = Calendar.current.dateComponents(Set(baseCps), from: Date(timeIntervalSince1970: rangeTimes.last!))
        
        var timeCpts : [Calendar.Component] = []
        let intervals = [TSChartInterval.i1year,.i1month,.i1week,.i1day,.i1hour,.i5min]
        let maxCount = Double(drawLayer.frame.size.width/1.8)
        for (idx,interval) in intervals.enumerated() {
            let ct = timeLength/(interval.timeValue())
            if ct <= maxCount {
                let comp = baseCps[idx]
                var needApd = true
                if ct < 1 {
                    switch comp {
                    case .year:
                        needApd = firstComp.year != lastComp.year
                        break
                    case .month:
                        needApd = firstComp.month != lastComp.month
                        break
                    case .weekOfMonth:
                        needApd = firstComp.weekOfMonth != lastComp.weekOfMonth
                        break
                    case .day:
                        needApd = firstComp.day != lastComp.day
                        break
                    case .hour:
                        needApd = firstComp.hour != lastComp.hour
                        break
                    case .minute:
                        needApd = firstComp.minute != lastComp.minute
                        break
                    default:
                        needApd = false
                    }
                }
                
                if needApd {
                    timeCpts.append(comp)
                }
            }
        }
        
        let baseH = drawLayer.bounds.height
        var builders : [Calendar.Component : TimeIndicatorBuilder] = [:]
        for (num, compType) in timeCpts.enumerated() {
            switch num {
            case 0:
                builders[compType] = TimeIndicatorBuilder(baseSize: CGSize(width: 1, height: baseH), baseColor: UIColor.secondaryLabel, level: num)
                break
            case 1:
                builders[compType] = TimeIndicatorBuilder(baseSize: CGSize(width: 1, height: baseH*0.75), baseColor: UIColor.tertiaryLabel, level: num)
                break
            case 2:
                builders[compType] = TimeIndicatorBuilder(baseSize: CGSize(width: 1, height: baseH*0.5), baseColor: UIColor.tertiaryLabel, level: num)
                break
            case 3:
                builders[compType] = TimeIndicatorBuilder(baseSize: CGSize(width: 0.5, height: baseH*0.25), baseColor: UIColor.tertiaryLabel, level: num)
                break
            default:
                builders[compType] = TimeIndicatorBuilder(baseSize: CGSize(width: 0.333333, height: baseH*0.25), baseColor: UIColor.tertiaryLabel, level: num)
            }
        }
        
        var preComp : DateComponents? = nil
        let intervalWidth = drawLayer.frame.width/CGFloat(rangeTimes.count)
        let midY = drawLayer.frame.midY
        for (idx,time) in rangeTimes.enumerated() {
            let comp = Calendar.current.dateComponents(Set(timeCpts), from: Date(timeIntervalSince1970: time))
            
            var baseBuilder : TimeIndicatorBuilder? = nil
            if let pre = preComp, pre != comp {
                if comp.year != pre.year {
                    baseBuilder = builders[.year]
                }else if comp.month != pre.month {
                    baseBuilder = builders[.month]
                }else if comp.weekOfMonth != pre.weekOfMonth {
                    baseBuilder = builders[.weekOfMonth]
                }else if comp.day != pre.day {
                    baseBuilder = builders[.day]
                }else if comp.hour != pre.hour {
                    baseBuilder = builders[.hour]
                }else if comp.minute != pre.minute {
                    baseBuilder = builders[.minute]
                }
            }
            
            if let builder = baseBuilder {
                let layer = CALayer()
                layer.bounds = CGRect(origin: CGPoint.zero, size: builder.baseSize)
                layer.backgroundColor = builder.baseColor.cgColor
                layer.position = CGPoint(x: CGFloat(idx)*intervalWidth, y: midY)
                drawLayer.addSublayer(layer)
            }

            preComp = comp
        }
    }
    
    func refreshRange(newRange:NSRange) -> Void {
        guard let times = times,
            !isScaling,
            times.count > 0
        else {
            return
        }
        guard newRange.location + newRange.length <= times.count else {
            return
        }
        curRange = newRange
        
        if let oldLayer = rangeLayer {
            oldLayer.removeFromSuperlayer()
        }
        let newLayer = CALayer()
        self.rangeLayer = newLayer
        newLayer.frame = self.bounds
        self.layer.addSublayer(newLayer)
        
        self.scaleLayer?.isHidden = true
        
        let rangeTimes = Array(times[Range(curRange!)!])
        self.__refreshIndicators(rangeTimes: rangeTimes, drawLayer: newLayer)
    }

    func showScale() -> Void {
        guard let times = times,
            times.count > 0
        else {
            return
        }
        
        if let oldLayer = scaleLayer {
            oldLayer.removeFromSuperlayer()
        }
        let newLayer = CALayer()
        self.scaleLayer = newLayer
        newLayer.frame = self.bounds
        self.layer.addSublayer(newLayer)
        
        self.rangeLayer?.isHidden = true
        self.__refreshScaleRange()
        self.__refreshIndicators(rangeTimes: times, drawLayer: newLayer)
    }
    
    private func __refreshScaleRange() -> Void {
        guard let range = curRange,
            let times = times,
            let superLayer = self.scaleLayer
        else {
            return
        }
        
        var layer : CALayer
        if let ly = self.scaleRangeLayer {
            layer = ly
        }else {
            layer = CALayer()
            self.scaleRangeLayer = layer
            layer.backgroundColor = UIColor.systemYellow.cgColor
            layer.opacity = 0.618
        }
        superLayer.addSublayer(layer)

        var rect = superLayer.bounds
        rect.origin.x = CGFloat(range.location)/CGFloat(times.count) * rect.width
        rect.size.width = CGFloat(range.length)/CGFloat(times.count) * rect.width
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.frame = rect
//        print(rect)
        CATransaction.commit()
    }
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        guard UIApplication.shared.applicationState == .inactive else {
            return
        }
        midLayer?.strokeColor = UIColor.label.cgColor
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.backgroundColor = UIColor.tertiarySystemFill
        let midLine = CAShapeLayer()
        midLayer = midLine
        midLine.frame = self.bounds
        midLine.strokeColor = UIColor.label.cgColor
        midLine.lineWidth = 0.5
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: self.bounds.midY))
        path.addLine(to: CGPoint(x: self.bounds.maxX, y: self.bounds.midY))
        midLine.path = path.cgPath
        self.layer.addSublayer(midLine)
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(gzr:)))
        pan.maximumNumberOfTouches = 1
        self.addGestureRecognizer(pan)
    }
    
    private var lastPanPosX : CGFloat = 0
    @objc private func handlePanGesture(gzr:UIPanGestureRecognizer) -> Void {
        guard let total = times?.count,
            let range = curRange
        else {
            return
        }
        
        let point = gzr.location(in: self)
        let posX = point.x
        switch gzr.state {
        case .began:
            isScaling = true
            self.showScale()
            self.lastPanPosX = posX
            break
        case .changed:
            let ofsX = posX - lastPanPosX
            let layer = self.scaleRangeLayer!
            let layerWidth = layer.frame.size.width
            let width = self.scaleLayer!.frame.size.width
            
            var pos = layer.position
            pos.x = max(layerWidth/2, min(width-layerWidth/2, pos.x + ofsX))
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.position = pos
            CATransaction.commit()
            
            let rect = layer.frame
            var newRange = range
            
            newRange.location = Int(rect.origin.x/width * CGFloat(total))
            if curRange != newRange {
                curRange = newRange
                if let callback = self.rangeChangeCallback {
                    callback(newRange)
                }
            }
            self.lastPanPosX = posX
            break
        default:
            isScaling = false
            self.refreshRange(newRange: self.curRange!)
        }
    }
}

private class TSIndicatorLayer : CAShapeLayer {
//    var focus : CGPoint = CGPoint.zero
    var trackLayer : TSCandleLayer? = nil {
        didSet {
            guard let layer = trackLayer else {
                return
            }
            self.strokeColor = UIColor.label.cgColor
            self.lineWidth = 1/UIScreen.main.scale
            let path = UIBezierPath()
            let pos = layer.focusPos
            path.move(to: CGPoint(x: 0, y: pos.y))
            path.addLine(to: CGPoint(x: self.frame.maxX, y: pos.y))
            path.move(to: CGPoint(x: pos.x, y: 0))
            path.addLine(to: CGPoint(x: pos.x, y: self.frame.maxY))
            self.path = path.cgPath
        }
    }
}

class TSSkillView: UIView {
    private var layerMACD : TSSkillMACD? = nil
    func showMACD(data:[TSDrawMACD]) -> Void {
        if let layer = layerMACD {
            layer.refresh(macds: data)
        }else{
            layerMACD = TSSkillMACD()
            layerMACD?.frame = self.bounds
            self.layer.addSublayer(layerMACD!)
            layerMACD?.refresh(macds: data)
        }
    }
}

private class TSSkillMACD : CALayer {
    var difLayer : CAShapeLayer? = nil
    var deaLayer : CAShapeLayer? = nil
    var upBarLayer : CAShapeLayer? = nil
    var downBarLayer : CAShapeLayer? = nil
    
    var pathUp : UIBezierPath? = nil
    var pathDown : UIBezierPath? = nil
    
//    override func draw(in ctx: CGContext) {
//        UIGraphicsPushContext(ctx)
//
//        defer {
//            UIGraphicsPopContext()
//        }
//        pathUp?.lineWidth = 1
//        TSUpplerColor.setStroke()
//        pathUp?.stroke()
//
//
//        pathDown?.lineWidth = 1
//        TSDownerColor.setStroke()
//        pathDown?.stroke()
//    }
    
    func refresh(macds:[TSDrawMACD]) {
        guard macds.count > 0 else {
            return
        }
        
        var maxv : Double = 0
        var minv : Double = 0
        for macd in macds {
            maxv = max(maxv, macd.BAR, macd.DIF)
            minv = min(minv, macd.BAR, macd.DIF)
        }
        
        let len = maxv - minv
        
        let interval = self.bounds.width/CGFloat(macds.count)
        
        var layerUp : CAShapeLayer
        var layerDown : CAShapeLayer
        if let ly1 = upBarLayer,
            let ly2 = downBarLayer {
                layerUp = ly1
                layerDown = ly2
        }else{
            layerUp = CAShapeLayer()
            layerUp.frame = self.bounds
            layerUp.lineWidth = 1
            self.addSublayer(layerUp)
            self.upBarLayer = layerUp
            
            layerDown = CAShapeLayer()
            layerDown.frame = self.bounds
            layerDown.lineWidth = 1
            self.addSublayer(layerDown)
            self.downBarLayer = layerDown
        }
        layerUp.strokeColor = TSUpplerColor.cgColor
        layerDown.strokeColor = TSDownerColor.cgColor

        var layerDIF : CAShapeLayer
        if let ly = self.difLayer {
            layerDIF = ly
        }else{
            layerDIF = CAShapeLayer()
            layerDIF.frame = self.bounds
            layerDIF.lineWidth = 1
            layerDIF.fillColor = UIColor.clear.cgColor
            self.difLayer = layerDIF
            self.addSublayer(layerDIF)
        }
        layerDIF.strokeColor = UIColor.label.cgColor

        var layerDEA : CAShapeLayer
        if let ly = self.deaLayer {
            layerDEA = ly
        }else{
            layerDEA = CAShapeLayer()
            layerDEA.frame = self.bounds
            layerDEA.lineWidth = 1
            layerDEA.fillColor = UIColor.clear.cgColor
            self.deaLayer = layerDEA
            self.addSublayer(layerDEA)
        }
        layerDEA.strokeColor = UIColor.systemOrange.cgColor

        let pos0 = self.bounds.height * CGFloat(maxv/len)
        var dif_path : UIBezierPath? = nil
        var dea_path : UIBezierPath? = nil
        
        let barUp_path = UIBezierPath()
        let barDw_path = UIBezierPath()
        for (idx, macd) in macds.enumerated() {
            let posX = interval/2 + CGFloat(idx)*interval
            let difPoint = CGPoint(x: posX, y: self.bounds.height*CGFloat(1 - (macd.DIF - minv)/len))
            let deaPoint = CGPoint(x: posX, y: self.bounds.height*CGFloat(1 - (macd.DEA - minv)/len))
            if let difPath = dif_path {
                difPath.addLine(to: difPoint)
            }else{
                dif_path = UIBezierPath()
                dif_path?.move(to: difPoint)
            }
            if let deaPath = dea_path {
                deaPath.addLine(to: deaPoint)
            }else{
                dea_path = UIBezierPath()
                dea_path?.move(to: deaPoint)
            }
            
            let barLen = self.bounds.height * CGFloat(macd.BAR/len)
            if macd.BAR > 0 {
                barUp_path.move(to: CGPoint(x: posX, y: pos0))
                barUp_path.addLine(to: CGPoint(x: posX, y: pos0 - barLen))
            }else{
                barDw_path.move(to: CGPoint(x: posX, y: pos0))
                barDw_path.addLine(to: CGPoint(x: posX, y: pos0 - barLen))
            }
        }
        layerDIF.path = dif_path?.cgPath
        layerDEA.path = dea_path?.cgPath
        layerUp.path = barUp_path.cgPath
        layerDown.path = barDw_path.cgPath
    }
}

private enum TSTrackState {
    case Moving
    case Indiactor
}

private func TSIndexColor(price : Double, refrence : Double) -> UIColor
{
    if price == refrence {
        return TSDefaultColor
    }else {
        return price > refrence ? TSUpplerColor : TSDownerColor
    }
}

class ESQuotePage: UIView {
//MARK: - private properties
    private var viewModel : TSViewModelKLine = TSViewModelKLine(nil) {
        didSet {
            self.curCandle = viewModel.today
        }
    }
    private var curCandle : TSDrawCandle? = nil
    {
        didSet {
            if let candle = curCandle {
                labelClose.text = String(format: "%.2f", candle.close)
                labelClose.textColor = TSIndexColor(price: candle.close, refrence: candle.open)
                labelOffset.text = String(format: "%.2f", (candle.close - candle.open))
                labelOffset.textColor = labelClose.textColor
                labelChange.text = String(format: "%.2f%%", (candle.close - candle.open)*100/candle.close)
                labelChange.textColor = labelClose.textColor
                
                labelOpen.text = String(format: "O : %.2f", candle.open)
                labelOpen.textColor = TSIndexColor(price: candle.close, refrence: candle.open)

                labelHigh.text = String(format: "H : %.2f", candle.high)
                labelHigh.textColor = TSIndexColor(price: candle.high, refrence: candle.open)
                
                labelLow.text = String(format: "L : %.2f", candle.low)
                labelLow.textColor = TSIndexColor(price: candle.low, refrence: candle.open)
                
                //2.539亿 2 5390 0.000
                labelVolume.text = String(format: "V : %.2f亿", Double(candle.volume)/100000.0) //
                let dt = Date(timeIntervalSince1970: candle.timestamp)
                let time = self.dataFormater.string(from: dt)
                labelTime.text = time
            }
        }
    }
    private var candleLayerMap = NSCache<NSNumber,TSCandleLayer>()
    private var lastPanPosX : CGFloat = 0
    private var lastScaleWidth : CGFloat = 0
    private var candleWidth : CGFloat = 0
    private var currentRange : NSRange?
    private var curMaxPrice : Double = 0 {
        didSet {
            labelValueMax.text = "\(Int(curMaxPrice))"
        }
    }
    private var curMinPrice : Double = Double(INT_MAX) {
        didSet {
            labelValueMin.text = "\(Int(curMinPrice))"
        }
    }
    private var startTime : TimeInterval? {
        return self.viewModel.candles.first?.timestamp
    }
    private var lastTime : TimeInterval? {
        let ct = self.viewModel.candles.count
        if ct > 0 {
            return self.viewModel.candles[ct - 1].timestamp
        }else{
            return nil
        }
    }
    
    //MARK - State
    private var trackState : TSTrackState? = nil
    private lazy var indicator : TSIndicatorLayer = TSIndicatorLayer()
    
    @IBOutlet weak private var viewKLine: UIView!
    @IBOutlet weak private var viewTimeLine: TSTimeLineView!
    @IBOutlet weak private var viewSkill: TSSkillView!
    @IBOutlet weak private var labelTimeStart: UILabel!
    @IBOutlet weak private var labelTimeEnd: UILabel!
    @IBOutlet weak private var segInterval: UISegmentedControl!
    @IBOutlet weak var overlayerPicker: UIView!
    @IBOutlet weak var pickerIntervals: TSIntervalPickerView!
    @IBOutlet weak var viewIndex: UIView!
    @IBOutlet weak var labelValueMax: UILabel!
    @IBOutlet weak var labelValueMin: UILabel!
    @IBOutlet weak var viewHeader: UIView!
    @IBOutlet weak var labelOpen: UILabel!
    @IBOutlet weak var labelHigh: UILabel!
    @IBOutlet weak var labelLow: UILabel!
    @IBOutlet weak var labelVolume: UILabel!
    @IBOutlet weak var labelClose: UILabel!
    @IBOutlet weak var labelOffset: UILabel!
    @IBOutlet weak var labelChange: UILabel!
    @IBOutlet weak var labelTime: UILabel!
    
    public var symbol : String?
    
    //    MARK: - Configuration
    private var chartInterval : TSChartInterval = .i1day
    private let MinCandleCount : Int = 10
    private let DefaultCandleCount : Int = 66
    private var MaxCandleCount : Int {
        Int(viewKLine.frame.size.width)
    }
    private var enabledMALine : [ESMAType] = ESMAType.allCases
    private var enabledIntervals : [TSChartInterval] = [.i1month, .i1week, .i1day, .i1hour]
    private var _df : DateFormatter = DateFormatter()
    private var dataFormater : DateFormatter {
        if self.chartInterval.timeValue() >= TSChartInterval.i1day.timeValue() {
            _df.dateFormat = "yyyy-MM-dd EEEE"
        }else{
            _df.dateFormat = "yyyy-MM-dd EEEE HH:mm"
        }
        return _df
    }
    
    //    MARK: - Life Cycle
    override init(frame: CGRect) {
        fatalError("init(coder:) has not been implemented")
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private func setupView() {
        self.backgroundColor = UIColor.systemBackground
        
        //picker intervals
        self.pickerIntervals.intervals = [.i5min, .i15min, .i30min, .i1year]
        
        //segment interval
        segInterval.removeAllSegments()
        var selectIdx = 0
        for (idx,interval) in enabledIntervals.enumerated() {
            if interval == self.chartInterval {
                selectIdx = idx
            }
            segInterval.insertSegment(withTitle: interval.rawValue, at: idx, animated: false)
        }
        segInterval.selectedSegmentIndex = selectIdx
        segInterval.backgroundColor = .clear
        segInterval.tintColor = .clear
        segInterval.selectedSegmentTintColor = .clear
        segInterval.setTitleTextAttributes([
            NSAttributedString.Key.foregroundColor: UIColor.secondaryLabel
            ], for: .normal)
        segInterval.setTitleTextAttributes([
            NSAttributedString.Key.foregroundColor: UIColor.label
            ], for: .selected)
        segInterval.removeBorders()
        
        ///setup k line
        viewKLine.clipsToBounds = true
        self.candleLayerMap.countLimit = 100
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(gzr:)))
        pan.maximumNumberOfTouches = 1
        viewKLine.addGestureRecognizer(pan)
        
        let panSkill = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(gzr:)))
        pan.maximumNumberOfTouches = 1
        viewSkill.addGestureRecognizer(panSkill)
        
        let pin = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(gzr:)))
        viewKLine.addGestureRecognizer(pin)
        
        //setup time line
        weak var weakSelf = self
        self.viewTimeLine.rangeChangeCallback = { (range) -> Void in
            weakSelf?.drawCandles(range)
        }
        //toast
        ToastManager.shared.style.activityBackgroundColor = UIColor.systemFill
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.setupView()
    }
    
    //MARK: - Fetch Data
    func refreshData() {
        guard let symbol = self.symbol else {
            self.makeToast("no symbol setted")
            return
        }
        self.makeToastActivity(.center)
        
        //"YYYY#MM#dd/HH:mm"
        let timeFrom : TimeInterval = Date().timeIntervalSince1970 - chartInterval.timeValue()*1000//self.dataFormater.date(from: "2020#4#10/00:00")!.timeIntervalSince1970
        let timeTo : TimeInterval = Date().timeIntervalSince1970//self.dataFormater.date(from: "2020#4#15/00:00")!.timeIntervalSince1970
        TSDataSource.shared.fetchCandles(symbol: symbol, interval: chartInterval, from: timeFrom, to: timeTo) { (klineModel, error) in
            self.hideToastActivity()
            
            if let model = klineModel {
                self.viewModel = model
                let showCount = min(self.DefaultCandleCount, model.candles.count)
                self.viewTimeLine.interval = self.chartInterval
                self.viewTimeLine.times = model.times
                self.drawCandles(NSMakeRange(model.candles.count - showCount, showCount))
            }else{
                self.makeToast(error?.reason())
            }
        }
    }
    
//    MARK: - Draw Chart
    private func drawCandles(_ newRange:NSRange) -> Void {
        guard let candleRange = Range(newRange),
            self.currentRange != newRange
        else {
            return
        }
        self.viewTimeLine.refreshRange(newRange: newRange)
//        print("cur range : \(candleRange)")
        self.currentRange = newRange

        let candleAry = viewModel.candles[candleRange]
        let macdAry = viewModel.skillMACD[candleRange]
        let maAry = Array(viewModel.skillMA[candleRange])
        self.viewSkill.showMACD(data: Array(macdAry))
        let COUNT = candleAry.count
        let SIZE = viewKLine.bounds.size
        self.candleWidth = SIZE.width/CGFloat(COUNT)
        
        var maxPrice : Double = 0
        var minPrice : Double = Double(INT_MAX)
        for candle in candleAry {
            maxPrice = max(maxPrice, candle.high)
            minPrice = min(minPrice, candle.low)
        }
        curMaxPrice = maxPrice
        curMinPrice = minPrice

        func GetYAxisPos(price:Double) -> CGFloat {
            return SIZE.height * (1.0 - CGFloat((price - minPrice) / (maxPrice - minPrice)))
        }
        
        if let sublayers = viewKLine.layer.sublayers {
            for layer:CALayer in sublayers {
                layer.removeFromSuperlayer()
            }
        }
        
        var maLayers = [ESMAType : ESLineMALayer]()
        for maType in self.enabledMALine {
            let ly = ESLineMALayer(maType: maType)
            maLayers[maType] = ly
        }
        
        for (index,candle) in candleAry.enumerated() {
            let ma = maAry[index]
            if index == 0 {
                labelTimeStart.text = self.dataFormater.string(from: Date(timeIntervalSince1970: candle.timestamp))
            }else if index == candleAry.count - 1 {
                labelTimeEnd.text = self.dataFormater.string(from: Date(timeIntervalSince1970: candle.timestamp))
            }

            let posX = SIZE.width * CGFloat(index) / CGFloat(COUNT)
            
            for maType in self.enabledMALine {
                if let maPrice = ma.quote[maType],
                    let maLayer = maLayers[maType] {
                    let pricePoint = CGPoint(x: posX + candleWidth/2, y: GetYAxisPos(price:maPrice))
                    
                    if let linePath = maLayers[maType]?.movePath {
                        linePath.addLine(to: pricePoint)
                    }else{
                        let linePath = UIBezierPath()
                        maLayer.movePath = linePath
//                        linePath.miterLimit = -10
                        linePath.move(to: pricePoint)
                    }
                }
            }
            
            //draw candles
            let CandleHeight = SIZE.height * CGFloat(candle.length / (maxPrice - minPrice))

            let candleRect = CGRect(x: posX, y: GetYAxisPos(price: candle.high), width: self.candleWidth, height: CandleHeight)
            
            var candleLayer : TSCandleLayer
            let candleIdx = candleRange.lowerBound + index
            if let oldLayer = candleLayerMap.object(forKey: NSNumber(value: candleIdx)) {
                candleLayer = oldLayer
            } else {
                let newLayer = TSCandleLayer()
                candleLayer = newLayer

                newLayer.strokeColor = candle.stokeColor.cgColor
                newLayer.lineWidth = 1
                newLayer.fillColor = candle.fillColor.cgColor
                candleLayerMap.setObject(newLayer, forKey: NSNumber(value: candleIdx))
            }
            candleLayer.focusPos = CGPoint(x: candleRect.midX, y: GetYAxisPos(price: candle.close))
            candleLayer.data = candle
            viewKLine.layer.addSublayer(candleLayer)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            candleLayer.frame = candleRect
            //DO Candle SCALE
            //draw candle body
            let inset = UIEdgeInsets(top: 0, left: 2, bottom: 0, right: 2)
            let BodyHeight = SIZE.height * CGFloat(candle.bodyLength / (maxPrice - minPrice))
            let uppperHeight = SIZE.height * CGFloat(candle.upperLength / (maxPrice - minPrice))
            
            let insw = self.candleWidth - inset.left - inset.right
            if insw >= 0 {
                let bodyRect = CGRect(x: inset.left, y: uppperHeight, width: insw, height: BodyHeight)
                let path = UIBezierPath(rect:bodyRect)
                //draw candle lower line
                var pos = CGPoint(x: candleRect.size.width/2, y: candleRect.size.height)
                path.move(to: pos)
                pos.y = bodyRect.maxY
                path.addLine(to: pos)
                //draw uppper line
                pos.y = bodyRect.origin.y
                path.move(to: pos)
                pos.y = 0
                path.addLine(to: pos)
                candleLayer.path = path.cgPath
            }else {
                let path = UIBezierPath()
                //draw candle single line
                var pos = CGPoint(x: candleRect.size.width/2, y: candleRect.size.height)
                path.move(to: pos)
                pos = CGPoint(x: candleRect.size.width/2, y: 0)
                path.addLine(to: pos)
                candleLayer.path = path.cgPath
            }
            CATransaction.commit()
        }
        
        //draw MA line
        for lineLayer in maLayers.values {
            lineLayer.path = lineLayer.movePath?.cgPath
            viewKLine.layer.addSublayer(lineLayer)
        }
    }
    
//MARK: - Event Handle
    @IBAction private func handleChangeInterval(_ sender: UISegmentedControl) {
        self.chartInterval = self.enabledIntervals[sender.selectedSegmentIndex]
        self.refreshData()
    }
    @IBAction func showMoreIntervals(_ sender: Any) {
        let alert = UIAlertController(title: "More Intervals", message: nil, preferredStyle: .actionSheet)
        for interval : TSChartInterval in [.i30min,.i15min,.i5min] {
            alert.addAction(UIAlertAction(title: interval.rawValue, style: .default, handler: { (action) in
                self.chartInterval = interval
                self.refreshData()
            }))
        }
        self.overlayerPicker.isHidden = false
    }
    @objc private func handlePanGesture(gzr:UIPanGestureRecognizer) -> Void {
        guard var range = self.currentRange
            else {
            return
        }
        
        let point = gzr.location(in: gzr.view)
        let posX = point.x
        let isTrackSkill = gzr.view == viewSkill

        switch gzr.state {
            case .began:
                var trackState : TSTrackState = .Moving
                if let subLayers = viewKLine.layer.sublayers {
                    for ly in subLayers {
                        if let candleLayer : TSCandleLayer = ly as? TSCandleLayer {
                            if isTrackSkill || candleLayer.isInCandleArea(point: point) {
                                trackState = .Indiactor
                                self.indicator.isHidden = false
                                var rect = self.bounds
                                let overKLine = viewKLine.convert(viewKLine.frame, to: self)
                                let overSkill = viewSkill.convert(viewSkill.frame, to: self)
                                rect.origin.y = overKLine.minY
                                rect.size.height = overSkill.maxY - rect.origin.y
                                self.indicator.frame = rect
                                self.indicator.trackLayer = candleLayer
                                self.layer.addSublayer(self.indicator)
                            }
                        }
                    }
                }
                self.trackState = trackState
                self.lastPanPosX = posX
                break
            case .changed:
                switch trackState {
                case .Moving:
                    let edgeOfs = posX - self.lastPanPosX
                    let minLocation = viewModel.candles.count - range.length
                    if abs(edgeOfs) > self.candleWidth {
                        let directionLeft = edgeOfs > 0
                        let num = Int( abs(edgeOfs)/self.candleWidth)
                        if directionLeft {
                            range.location = max(0, range.location - num)
                        }else{
                            range.location = min(minLocation, range.location + num)
                        }
                        self.lastPanPosX = posX
                    }
                    
                    self.drawCandles(range)
                    break
                case .Indiactor:
                    self.lastPanPosX = posX
                    if let subLayers = viewKLine.layer.sublayers {
                        for ly in subLayers {
                            if let candleLayer : TSCandleLayer = ly as? TSCandleLayer {
                                if candleLayer.isInXArea(posX: point.x),
                                    let data = candleLayer.data{
                                    self.curCandle = data
                                    self.indicator.trackLayer = candleLayer
                                }
                            }
                        }
                    }
                    break
                case .none:
                    break
                }
                break
            default:
                if let state = trackState,
                state == .Indiactor {
                    self.indicator.isHidden = true
                    self.curCandle = self.viewModel.today
                }

                self.trackState = nil
                self.lastPanPosX = 0
        }
    }
    @objc private func handlePinchGesture(gzr:UIPinchGestureRecognizer) -> Void {
        guard var range = self.currentRange else {
            return
        }
        
        let scale = gzr.scale
        let scaleWidth = viewKLine.frame.size.width*(scale - 1)
        switch gzr.state {
        case .began:
            self.lastScaleWidth = scaleWidth
            break
        case .changed:
            let ofsWidth = scaleWidth - lastScaleWidth
            let scaleCount = Int(abs(ofsWidth)/self.candleWidth)
//            print("scale count :\(scaleCount)")
            if ofsWidth != 0 && scaleCount > 0 {
                let curPos = range.location + range.length
                if ofsWidth > 0 {
                    //变大
                    range.length = max(range.length - scaleCount, MinCandleCount)
                    range.location = curPos - range.length
                }else{
                    //变小//
                    if range.location == 0 && range.length == curPos {
                        range.length = min(min(range.length + scaleCount, viewModel.candles.count), MaxCandleCount)
                    }else{
                        range.length = min(min(range.length + scaleCount, curPos), MaxCandleCount)
                        range.location = curPos - range.length
                    }
                }
                self.drawCandles(range)
                lastScaleWidth = scaleWidth
            }
            break
        default :
            self.lastScaleWidth = 0
        }
    }
    @IBAction func handleHidePicker(_ sender: Any) {
        self.overlayerPicker.isHidden = true
    }
    @IBAction func handleCommitPicker(_ sender: Any) {
        self.chartInterval = self.pickerIntervals.curInterval
        self.refreshData()
        self.overlayerPicker.isHidden = true
    }
    
}
