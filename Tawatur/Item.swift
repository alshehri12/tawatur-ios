//
//  Item.swift
//  Tawatur
//
//  Created by Abdulrahman Alshehri on 15/12/1447 AH.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
