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
    self.name = [UILabel new];
    self.name.text = @"Demo of Couchy v1.1";
    [self.name sizeToFit];
    [self.view addSubview:self.name];
    
    self.name.translatesAutoresizingMaskIntoConstraints = false;
    
    NSLayoutConstraint *horiz = [NSLayoutConstraint constraintWithItem:self.name
                                                             attribute:NSLayoutAttributeCenterX
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self.view
                                                             attribute:NSLayoutAttributeCenterX
                                                            multiplier:1.0
                                                              constant:0.f];
    
    NSLayoutConstraint *vert = [NSLayoutConstraint constraintWithItem:self.name
                                                             attribute:NSLayoutAttributeCenterY
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self.view
                                                             attribute:NSLayoutAttributeCenterY
                                                            multiplier:1.0
                                                              constant:0.f];

    [self.view addConstraints:@[horiz, vert]];
}

@end
