//
//  ParentContainer.swift
//  Couchy
//
//  Created by Raven Smith on 5/12/16.
//  Copyright © 2016 Raven Smith. All rights reserved.
//

import UIKit
import TMCache

@objc public class ParentContainer: UIView {
    
    var manager: CBLManager
    var database: CBLDatabase?
    var child: ChildModel
    
    override init(frame: CGRect)  {
        
        manager = CBLManager.sharedInstance()
        try! database = self.manager.databaseNamed("Sample")
        child = ChildModel(forNewDocumentInDatabase: database!)
        super.init(frame: frame)
        
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}