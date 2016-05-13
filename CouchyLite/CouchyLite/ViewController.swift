//
//  ViewController.swift
//  CouchyLite
//
//  Created by Raven Smith on 5/12/16.
//  Copyright © 2016 Raven Smith. All rights reserved.
//

import UIKit
import AFNetworking

class ViewController: UIViewController {
    
    var session: NSURLSession
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        session = NSURLSession()
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

