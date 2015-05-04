//
//  JSOC.h
//  JSOC
//
//  Created by Joel Einbinder on 4/12/15.
//  Copyright (c) 2015 Joel Einbinder. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

@interface JSOC : NSObject{
    JSContext * context;
}
-(NSString*)stringByEvaluatingString:(NSString*)string;
-(JSValue*)valueByEvaluatingString:(NSString *)str;
@end
