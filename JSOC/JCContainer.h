//
//  Container.h
//  JSOC
//
//  Created by Joel Einbinder on 4/13/15.
//  Copyright (c) 2015 Joel Einbinder. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JCContainer : NSObject{
    Class c;
    id object;
    SEL selector;
    Protocol * protocol;
    NSString * method;
}
-(instancetype)initWithClass:(Class)c;
-(instancetype)initWithObject:(id)object;
-(instancetype)initWithSelector:(SEL)selector;
-(instancetype)initWithProtocol:(Protocol*)protocol;
-(instancetype)initWithContainer:(JCContainer*)container method:(NSString *)method;

-(Class)storedClass;
-(id)storedObject;
-(SEL)storedSelector;
-(Protocol*)storedProtocol;
-(NSString*)toString;
-(NSString*)method;
-(void *)privateData;
@end
