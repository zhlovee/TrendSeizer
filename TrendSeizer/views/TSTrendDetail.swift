//
//  TSTrendDetail.swift
//  TrendSeizer
//
//  Created by lizhenghao on 2020/4/15.
//  Copyright © 2020 lizhenghao. All rights reserved.
//

import SwiftUI

struct TSDetailContent: UIViewRepresentable {
    typealias UIViewType = ESQuotePage
    public var realKLine : ESQuotePage
    
    init(_ symbol : String) {
        self.realKLine = ESQuotePage.defaultNibView()
        realKLine.symbol = symbol
        realKLine.refreshData()
    }
    
    func makeUIView(context: Context) -> ESQuotePage {
        return self.realKLine
    }
    func updateUIView(_ uiView: ESQuotePage, context: Context) {
//        print(context)
    }
}

struct TSTrendDetail: View {
    var symbol : String
    
    var body: some View {
        VStack(alignment:.leading, spacing: 0.0){
            HStack(alignment: .center){
                Text("Trend Detail").font(.largeTitle)
                Spacer()
                Text(symbol).font(.title)
            }
            TSDetailContent(symbol)
        }
    }
}

struct TSTrendDetail_Previews: PreviewProvider {
    static var previews: some View {
        TSTrendDetail(symbol: "399006.SS")
    }
}
