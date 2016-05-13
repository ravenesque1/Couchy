//
//  ChildView.h
//  Couchy
//
//  Created by Raven Smith on 5/12/16.
//  Copyright © 2016 Raven Smith. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CouchbaseLite/CouchbaseLite.h"

@interface ChildModel : CBLModel

@property (strong, nonatomic) NSArray* contents;

@end
