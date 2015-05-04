//
//  Container.m
//  JSOC
//
//  Created by Joel Einbinder on 4/13/15.
//  Copyright (c) 2015 Joel Einbinder. All rights reserved.
//

#import "JCContainer.h"

@implementation JCContainer

-(instancetype)initWithContainer:(JCContainer*)container method:(NSString *)m{
    if ([container storedObject]){
        self = [self initWithObject:[container storedObject]];
    }
    else if ([container storedClass]){
        self = [self initWithClass:[container storedClass]];
    }
    else if ([container storedProtocol]){
        self = [self initWithProtocol:[container storedProtocol]];
    }
    else if ([container storedSelector]){
        self = [self initWithSelector:[container storedSelector]];
    }
    
    if (self){
        if ([container method]){
            method = [NSString stringWithFormat:@"%@:%@", [container method], m];
        }
        else{
            method = m;
        }
    }
    return self;
}
-(instancetype)init{
    if (self = [super init]){
        c = nil;
        object = nil;
        selector = nil;
        protocol = nil;
    }
    return self;
}
-(instancetype)initWithClass:(Class)cl{
    if (self = [self init]){
        c = cl;
    }
    return self;
}
-(instancetype)initWithObject:(id)obj{
    if (self = [self init]){
        object = obj;
        [object retain];
    }
    return self;
}
-(instancetype)initWithSelector:(SEL)sel{
    if (self = [self init]){
        selector = sel;
    }
    return self;
}
-(instancetype)initWithProtocol:(Protocol*)proto{
    if (self = [self init]){
        protocol = proto;
    }
    return self;
}

-(Class)storedClass{
    return c;
}
-(id)storedObject{
    return object;
}
-(SEL)storedSelector{
    return selector;
}
-(Protocol*)storedProtocol{
    return protocol;
}
-(NSString *)method{
    return method;
}
-(NSString*)toString{
    if (object){
        return [object description];
    }
    else if (protocol){
        return NSStringFromProtocol(protocol);
    }
    else if (selector){
        return NSStringFromSelector(selector);
    }
    else if (c){
        return [c description];
    }
    return @"<Nothing Stored>";
}
-(void *)privateData{
    if (object)
        return object;
    if (protocol)
        return protocol;
    if (c)
        return c;
    if (selector)
        return selector;
    return NULL;
}
-(void)dealloc{
    if (object)
        [object release];
    [super dealloc];
}
@end

