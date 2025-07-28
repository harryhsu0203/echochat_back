//
//  Item.swift
//  echochat app
//
//  Created by 徐明漢 on 2025/7/28.
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
