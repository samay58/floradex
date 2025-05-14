//
//  Item.swift
//  plantlife
//
//  Created by Samay Dhawan on 5/14/25.
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
