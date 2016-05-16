//
//  CouchyController.m
//  Couchy
//
//  Created by Raven Smith on 5/16/16.
//  Copyright © 2016 Raven Smith. All rights reserved.
//

#import "CouchyController.h"

@implementation CouchyController

-(void)viewDidLoad {
    self.view.backgroundColor = [UIColor orangeColor];
    [self setup];
}


-(void)setup {
    self.name = [[UILabel alloc] initWithFrame:self.view.frame];
    self.name.text = @"Demo of Couchy v1.1";
    [self.name sizeToFit];
    [self.view addSubview:self.name];
}

@end
