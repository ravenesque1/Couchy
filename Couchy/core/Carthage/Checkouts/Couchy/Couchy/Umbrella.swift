//
//  Umbrella.swift
//  Couchy
//
//  Created by Raven Smith on 5/16/16.
//  Copyright © 2016 Raven Smith. All rights reserved.
//

import Foundation

@objc public class MakesReferences: NSObject {
    var container: ParentContainer?
    var child: ChildModel?
    var controller: CouchyController?
    
    override init() {
        super.init()
    }
}
