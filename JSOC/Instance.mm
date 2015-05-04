//
//  Instance.cpp
//  JSOC
//
//  Created by Joel Einbinder on 4/13/15.
//  Copyright (c) 2015 Joel Einbinder. All rights reserved.
//

#include "Instance.h"
#import <Foundation/Foundation.h>

Instance::~Instance(){
    NSLog(@"*** Instance destroyed ***");
}
Instance::Instance(){
    NSLog(@"*** Instance created ***");
   
}