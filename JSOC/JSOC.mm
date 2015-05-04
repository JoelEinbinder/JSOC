//
//  JSOC.m
//  JSOC
//
//  Created by Joel Einbinder on 4/12/15.
//  Copyright (c) 2015 Joel Einbinder. All rights reserved.
//

#import "JSOC.h"
#import "JCContainer.h"

#import <JavaScriptCore/JavaScriptCore.h>
#import <objc/runtime.h>
JSContext * myContext;
JSValue * (^sendMessage)(JSValue *, JSValue *);
void JSOCFinalize(JSObjectRef ref){
//    NSLog(@"JSOC finalize");
    // Clean up if theres an object in there!
    JCContainer * priv = (JCContainer*)JSObjectGetPrivate(ref);
    if (priv){
        [priv release];
        // be good and set it to null so we cant double release
        // Shouldn't necessarily be needed
        JSObjectSetPrivate(ref, NULL);
    }
}
@implementation JSOC
JSClassRef containerClass;
JSClassRef methodClass;
JSObjectRef objectPrototype;
bool getRealProperty;
JSValueRef JSOCGetProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef *exception){
    //JSObjectHasProperty(ctx, object, propertyName);
    if (getRealProperty)
        return NULL;
    if (JSObjectHasProperty(ctx, objectPrototype, propertyName)){
        return NULL;
    }
    getRealProperty = true;
    bool hasProperty =JSObjectHasProperty(ctx, object, propertyName);
    getRealProperty = false;
    if (hasProperty){
        // Theres something there, just use that
        return NULL;
    }
    NSString * prop =  ( (NSString *) JSStringCopyCFString( kCFAllocatorDefault, propertyName ) ) ;
    //NSLog(@"Property was gotten:%@",prop);

    JSContext * context = [JSContext contextWithJSGlobalContextRef:JSContextGetGlobalContext(ctx)];
    // We know there is nothing here, add our own thing if we should.
    JSValue * JSObj = [JSValue valueWithJSValueRef:object inContext:context];
    
    //NSString * name =[ ( (NSString *) JSStringCopyCFString( kCFAllocatorDefault, propertyName ) ) autorelease ];
    
    if (JCContainer * con =  (JCContainer *)JSObjectGetPrivate(object)){
        if ([con storedObject] || [con storedClass]){
            //make the new function thing
//            JSValue * (^getProp)();
//            getProp =^{
////                NSLog(@"Get prop thing:%@",prop);
//                NSString * p = prop;
//                if ([JSContext currentArguments].count > 0)
//                    p = [NSString stringWithFormat:@"%@:", prop];
//                
//                JSValue * selector = [JSValue valueWithObject:p inContext:[JSContext currentContext]];
//                return [JSOC sendMessage:selector toObject:JSObj withArguments:[JSContext currentArguments]];
//            };
//            JSObj[prop] = Block_copy(getProp);
            JCContainer * newContainer = [[JCContainer alloc] initWithContainer:con method:prop] ;
            JSValue * obj = [JSOC makeObject:newContainer method:YES];
            JSObj[prop] = obj;
            //JSValue * func = JSObj[prop];
            //func[@"name"] = [JSValue valueWithObject:prop inContext:context];
            //func[@"object"] = JSObj;
            return NULL;
        }
    }
    //UIView
    return NULL;
}
JSValueRef JSOCCallAsFunction ( JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef *exception){
    JSContext  * context = [JSContext contextWithJSGlobalContextRef:JSContextGetGlobalContext(ctx)];
    JSValue * JSObj = [JSValue valueWithJSValueRef:function inContext:context];
    
    if (JCContainer * con =  (JCContainer *)JSObjectGetPrivate(function)){
        NSString * prop = [con method];
        NSString * p = prop;
        if (argumentCount > 0)
            p = [NSString stringWithFormat:@"%@:", prop];
        NSMutableArray * args = [NSMutableArray arrayWithCapacity:argumentCount];
        for (int i = 0; i < argumentCount; i++) {
            [args addObject:[JSValue valueWithJSValueRef:arguments[i] inContext:context]];
        }
        JSValue * selector = [JSValue valueWithObject:p inContext:context];
        JSValue * retVal = [JSOC sendMessage:selector
                                    toObject:JSObj
                               withArguments:args
                                 withContext:context];
        return [retVal JSValueRef];
    }
    return NULL;
}

-(JSOC*)init{
    if (self = [super init]){
        getRealProperty = false;
        sendMessage = ^(JSValue * obj, JSValue * message){
            NSArray * args = [JSContext currentArguments];
            args = [args subarrayWithRange:NSMakeRange(2, [args count]-2)];
            return [JSOC sendMessage:message toObject:obj withArguments:args];
        };
        context = [[JSContext alloc] init];
        myContext = context;

        JSClassDefinition containerClassDefintion = kJSClassDefinitionEmpty;
        containerClassDefintion.finalize = &JSOCFinalize;
        containerClassDefintion.getProperty = &JSOCGetProperty;
        containerClass = JSClassCreate(&containerClassDefintion);
        
        JSClassDefinition methodClassDefinition = containerClassDefintion;
        methodClassDefinition.callAsFunction = &JSOCCallAsFunction;
        methodClass = JSClassCreate(&methodClassDefinition);
        
        //TODO make this thing
        context[@"sendMessage"] = sendMessage;
        context[@"polluteClasses"] = ^{
            [self setUpClasses];
        };
        context[@"getClass"] = ^(NSString * s){
            return [self makeClassObject:NSClassFromString(s)];
        };
        context[@"addClass"] = ^(NSString * s){
            [self addClass:NSClassFromString(s)];
        };
        
        //[self setUpClasses];
        objectPrototype = (JSObjectRef) [[context evaluateScript:@"Object.prototype"] JSValueRef];
        
        
    }
    return self;
}
+(void)invoke:(NSInvocation*)inv withArgs:args{
    int index = 2;
    NSMethodSignature * sig = [inv methodSignature];
    void * frameOrig = malloc([sig frameLength]);
    void * frame = frameOrig;
    for (JSValue * arg in args){
        const char * rawArgType = [sig getArgumentTypeAtIndex:index ];
        NSObject * argType = [self parseType:[NSString stringWithUTF8String:rawArgType]];
        void * now = frame;
        [JSOC writeVoid:&frame forJS:arg withType:argType];
        [inv setArgument:now atIndex:index];
        index ++;
    }
    free(frameOrig);
    [inv invoke];
}
+(void)writeVoid:(void **)frame forJS:(JSValue *)arg withType:(NSObject *)type{
    //base case
    if ([type isKindOfClass:NSString.class]){
        [self writeVoid:(char **)frame forJS:arg withSingleType:[(NSString *)type UTF8String]];
        return;
    }
    //recursive case
    else if ([type isKindOfClass:NSArray.class]){
        NSArray * arr = (NSArray *)type;
/*        JSValue * JSArr = [JSValue valueWithNewArrayInContext:[JSContext currentContext]];
        for (NSObject * object : arr){
            JSValue * JSObj = [self valueFromRaw:raw forType:object];
            [JSArr invokeMethod:@"push" withArguments:@[JSObj]];
        }*/
        int i = 0;
        for (NSObject * object : arr){
            [self writeVoid:frame forJS:[arg objectAtIndexedSubscript:i] withType:object];
            i++;
        }
        return;
    }
}
+(JSValue *)returnFromInvocation:(NSInvocation *)inv withContext:(JSContext *)context{
    NSMethodSignature * sig = [inv methodSignature];
    const char * returnType = [sig methodReturnType];
    NSUInteger retSize = [sig methodReturnLength];
    if (retSize <= 0){
        return [JSValue valueWithUndefinedInContext:context];
    }
    void * retVal = malloc(retSize);
    void * retCopy = retVal;
    [inv getReturnValue:retVal];
    NSObject * type = [self parseType:[NSString stringWithUTF8String:returnType]];
    JSValue * val = [self valueFromRaw:&retCopy forType:type withContext:context];
    // release an object if we allocated one, so it doesn't get double retained.
    if (strcmp(returnType, @encode(NSObject *)) == 0){
        if ([inv selector] == @selector(alloc) ||
            
            [inv selector] == @selector(new) ||
            [inv selector] == @selector(copy) ||
            [inv selector] == @selector(mutableCopy) ||
            [inv selector] == @selector(copyWithZone:) ||
            [inv selector] == @selector(mutableCopyWithZone:)){
            id object = *(id *)retVal;
            [object release];
        }
    }
    free(retVal);
    return val;
}
+(JSValue *)valueFromRaw:(void **)raw forType:(NSObject*)type withContext:(JSContext *)context{
    if ([type isKindOfClass:NSString.class]){
        return [self valueFromRaw:(char **)raw withSingleType:[(NSString*)type UTF8String] withContext:context];
    }
    else if ([type isKindOfClass:NSArray.class]){
        NSArray * arr = (NSArray *)type;
        JSValue * JSArr = [JSValue valueWithNewArrayInContext:context];
        for (NSObject * object : arr){
            JSValue * JSObj = [self valueFromRaw:raw forType:object withContext:context];
            [JSArr invokeMethod:@"push" withArguments:@[JSObj]];
        }
        return JSArr;
    }
    return nil;
}
+(JSValue *)valueFromRaw:(char **)rawPtr withSingleType:(const char *)type withContext:(JSContext *)context{
    void * raw = *rawPtr;
    if (strcmp(type, @encode(NSObject *)) == 0){
        //object
        id object = *(id *)raw;
        *rawPtr += sizeof(object);
        return [JSOC makeObject:(void *)[[JCContainer alloc] initWithObject:object ] ];
    }
    else if (strcmp(type, @encode(Class)) == 0){
        Class c = *(Class *)raw;
        *rawPtr += sizeof(c);
        return [JSOC makeObject:(void *)[[JCContainer alloc] initWithClass:c ] ];
    }
    else if (strcmp(type, @encode(BOOL)) == 0){
        BOOL b = *(BOOL *)raw;
        *rawPtr += sizeof(b);
        return [JSValue valueWithBool:b inContext:context];
    }
    else if (strcmp(type, @encode(int)) == 0){
        int b = *(int *)raw;
        *rawPtr += sizeof(b);
        return [JSValue valueWithInt32:b inContext:context];
    }
    else if (strcmp(type, @encode(float)) == 0){
        float b = *(float *)raw;
        *rawPtr += sizeof(b);
        return [JSValue valueWithDouble:b inContext:context];
    }
    else if (strcmp(type, @encode(double)) == 0){
        double b = *(double *)raw;
        *rawPtr += sizeof(b);
        return [JSValue valueWithDouble:b inContext:context];
    }
    
    //[JSValue valueWithObject:@[] inContext:[JSContext currentContext]];
    NSLog(@"Unknown type:%@",[self parseType:[NSString stringWithUTF8String:type]]);
    return [JSValue valueWithUndefinedInContext:context];
}
+(NSObject *)parseType:(NSString *)type{
    if ([@"{" isEqualToString:[type substringToIndex:1]]){
        //Its a struct
        NSUInteger equals = [type rangeOfString:@"="].location;
        NSRange r;
        r.location = equals + 1;
        r.length = type.length - equals - 2;
        NSString * inner = [type substringWithRange:r];
        //NSLog(@"Type inner: %@",inner);
        NSMutableArray * a = [NSMutableArray arrayWithArray:@[]];
        for (int i = 0; i < inner.length; i++){
            NSString * c = [inner substringWithRange:NSMakeRange(i, 1)];
            if ([c isEqualToString:@"{"]){
                int count = 1;
                int j;
                for (j = 1; i+j < inner.length; j++){
                    if ([inner characterAtIndex:i+j] == '{'){
                        count += 1;
                    }
                    else if ([inner characterAtIndex:i+j] == '}'){
                        count -= 1;
                    }
                    if (count == 0){
                        break;
                    }
                }
                c = [inner substringWithRange:NSMakeRange(i, j+1)];
                i += j;
            }
            [a addObject:[self parseType:c]];
        }
        return a;
    }
    return type;
}
// Setting up all the classes in JavaScript. Fun!
-(void)setUpClasses{
    
    
    int numClasses;
    Class *classes = NULL;
    
    classes = NULL;
    numClasses = objc_getClassList(NULL, 0);
    
    if (numClasses > 0 )
    {
        classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * numClasses);
        numClasses = objc_getClassList(classes, numClasses);
        for (int i = 0; i < numClasses; i++) {
            [self addClass:classes[i]];
        }
        free(classes);
    }
}
+(JSValue *)makeObject:(void *)privateData{
    return [self makeObject:privateData method:NO];
}
+(JSValue *)makeObject:(void *)privateData method:(BOOL)method{
    JSClassRef c = containerClass;
    if (method)
        c = methodClass;
    
    JSValue * val = [JSValue valueWithJSValueRef:JSObjectMake([myContext JSGlobalContextRef],c, privateData) inContext:myContext];
    val[@"toString"] = ^{
        JSObjectRef obj = (JSObjectRef)[[JSContext currentThis] JSValueRef];
        JCContainer * con = (JCContainer *)JSObjectGetPrivate(obj);
        return [con toString];
    };
    return val;

}
#define voidForType(x,y) if(strcmp( type, @encode( x )) == 0){ \
    *frame += sizeof(x); \
    *(x *)v = [n y];\
    return;\
}
+(void)writeVoid:(char **)frame forJS:(JSValue *)val withSingleType:(const char *)type{
    void ** v = (void **)*frame;
    
    if ([val isString]){
        *v = [val toString];
        *frame += sizeof(void *);
    }
    else if ([val isNumber]){
        NSNumber * n = [val toNumber];
        voidForType(int, intValue)
        else voidForType(BOOL, boolValue)
        else voidForType(char, charValue)
        else voidForType(double, doubleValue)
        else voidForType(float, floatValue)
        else voidForType(long long, longLongValue)
        else voidForType(long, longValue)
        else voidForType(void *, pointerValue)
        else voidForType(NSString *, stringValue)
        else voidForType(short, shortValue)
        else voidForType(unsigned char, unsignedCharValue)
        else voidForType(unsigned int, unsignedIntValue)
        else voidForType(unsigned long long, unsignedLongLongValue)
        else voidForType(unsigned long, unsignedLongValue)
        else voidForType(unsigned short, unsignedShortValue)
    }
    else if ([val isObject]){
        if (JCContainer * con = (JCContainer*)JSObjectGetPrivate((JSObjectRef) [val JSValueRef])){
            *frame += sizeof(void *);
            *v = [con privateData];
        }
        else{
            /*NSArray * arr = [val toArray];
            if ([arr count] > 0){
                for (var i = 0; i < arr.count; i++){
                    JSValue * inner = [val objectAtIndexedSubscript:i];
                    void * iv = [self voidForJS:<#(JSValue *)#> type:<#(const char *)#>];
                    
                }
            }
            else*/
            {
                *frame += sizeof(void *);
                *v = [val toObject];
            }
        }
        return;
    }
    else if ([val isBoolean]){
        *frame += sizeof(void *);
        *(BOOL *)v = [val toBool];
        return;
    }
    else if ([val isNull]){
        *frame += sizeof(void *);
        *v = NULL;
        return;
    }
    else if ([val isUndefined]){
        *frame += sizeof(void *);
        *v = NULL;
        return;
    }
}
-(void)setGlobalVariable:(NSString *)name value:(JSValue *)value{
    context[name] = value;
}
-(void)addClass:(Class)c{
    NSString * name = NSStringFromClass(c);
    //NSLog(@"Debugify adding class:%@",name);
    // There was a horrible bug here where we were overwriting Object
    if ([[self valueByEvaluatingString:name] isUndefined])
        [self setGlobalVariable:name
                          value:[self makeClassObject:c]];
    //NSLog(@"Debugify Added class:%@",name);
}
-(JSValue *)makeClassObject:(Class) c{
    return [JSOC makeObject:(void *)[[JCContainer alloc] initWithClass:c]];
}
-(JSValue*)valueByEvaluatingString:(NSString *)str{
    return [context evaluateScript:str];
}
-(NSString*)stringByEvaluatingString:(NSString*) str{
    return [[context evaluateScript:str] toString];
}
-(void)dealloc{
    [context release];
    [super dealloc];
}
+(JSValue *)sendMessage:(JSValue *)message
               toObject:(JSValue *)obj
          withArguments:(NSArray *)args
            withContext:(JSContext *) con{
    if (![obj isObject])
        return [JSValue valueWithUndefinedInContext:con];
    
    JCContainer * priv = (JCContainer *)JSObjectGetPrivate((JSObjectRef)[obj JSValueRef]);
    if (!priv)
        return [JSValue valueWithUndefinedInContext:con];
    
    SEL selector = nil;
    if ([message isString]){
        selector = NSSelectorFromString([message toString]);
    }
    else if ([message isObject]){
        JCContainer * priv= (JCContainer *)JSObjectGetPrivate((JSObjectRef)[obj JSValueRef]);
        if (priv ){
            if (!priv)
                return [JSValue valueWithUndefinedInContext:con];
            selector = [priv storedSelector];
            if (!selector){
                return [JSValue valueWithUndefinedInContext:con];
            }
        }
    }
    else{
        return [JSValue valueWithUndefinedInContext:con];
    }
    
    if (Class c = [priv storedClass]){
        if (![c respondsToSelector:selector])
            return [JSValue valueWithUndefinedInContext:con];
        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:[c methodSignatureForSelector:selector]];
        [inv setSelector:selector];
        [inv setTarget:c];
        [JSOC invoke:inv withArgs:args];
        return [JSOC returnFromInvocation:inv withContext:con];
    }
    else if (id object = [priv storedObject]){
        if ([object respondsToSelector:selector]){
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:[object methodSignatureForSelector:selector]];
            [inv setSelector:selector];
            [inv setTarget:object];
            [JSOC invoke:inv withArgs:args];
            return [JSOC returnFromInvocation:inv withContext:con];
        }
    }
    return [JSValue valueWithUndefinedInContext:con];
   
}

+(JSValue *)sendMessage:(JSValue *)message toObject:(JSValue *)obj withArguments:(NSArray *)args{
    JSContext * con = [JSContext currentContext];
    return [self sendMessage:message toObject:obj withArguments:args withContext:con];
    
}
@end






