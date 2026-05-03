//
//  Item.swift
//  LState
//
//  Created by Lollipop on 2026/5/3.
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
