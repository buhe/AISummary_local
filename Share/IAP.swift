//
//  IAP.swift
//  FinanceDashboard
//
//  Created by 顾艳华 on 2023/1/17.
//

import Foundation

import SwiftUI

import StoreKit

class IAP{

    static let shared = IAP()
    func getProductID() -> [String] {
        ["dev.buhe.sum.monthly"]
    }
   

}
