//
//  JCTest.m
//  JSOC
//
//  Created by Joel Einbinder on 4/12/15.
//  Copyright (c) 2015 Joel Einbinder. All rights reserved.
//

//#import <Cocoa/Cocoa.h>
#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "JSOC.h"
@interface OurClass : NSObject
+(NSString *)secretString;

@end
@implementation OurClass

- (NSString *)instanceString{
    return @"another secret string";
}
+(NSString *)secretString{
    return @"Secret String!!!";
}
+(int)plusFive:(int)inval{
    return inval + 5;
}
+(int)addRect:(CGRect)r{
    return r.origin.x + r.origin.y + r.size.width + r.size.height;
}
+(CGRect)myRect{
    return CGRectMake(5, 10, 20, 40);
}
@end

@interface JCTest : XCTestCase

@end

@implementation JCTest
JSOC * jsoc;
- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    jsoc = [[JSOC alloc] init];
    //[jsoc valueByEvaluatingString:@"polluteClasses();"];
    [jsoc valueByEvaluatingString:@"addClass('UIView');"];
    [jsoc valueByEvaluatingString:@"addClass('OurClass');"];
    [jsoc valueByEvaluatingString:@"addClass('UIColor');"];
    [jsoc valueByEvaluatingString:@"addClass('NSString');"];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}
- (BOOL)string:(NSString *) string evaluatesTo:(NSString *)answer{
    NSString * res = [jsoc stringByEvaluatingString:string];
    BOOL retVal = [res isEqualToString:answer];
    if (!retVal){
        NSLog(@"Failed: `%@` != `%@`",res, answer);
    }
    return retVal;
}
- (void)testBasicJavascript {
    // Make sure we didn't break any fundamentals of JavaScript
    XCTAssert([self string:@"3;" evaluatesTo:@"3"], @"Pass");
    XCTAssert([self string:@"'yo';" evaluatesTo:@"yo"], @"Pass");
    XCTAssert([self string:@"var x = 3 + 5; x + 8;" evaluatesTo:@"16"], @"Pass");
}
- (void)testClasses{
    // Does it find our classes and can we interact with them?
    XCTAssert([self string:@"OurClass" evaluatesTo:[OurClass description]], @"Pass");
    XCTAssert([self string:@"NSString" evaluatesTo:[NSString description]], @"Pass");
}
- (void)testSendMessage{
    // Can we use sendMessage to access the objC runtime?
    XCTAssert([self string:@"sendMessage(OurClass,'secretString')" evaluatesTo:[OurClass secretString]], @"Pass");
    XCTAssert([self string:@"sendMessage(sendMessage(sendMessage(OurClass,'alloc'),'init'),'instanceString')" evaluatesTo:[[[OurClass alloc] init] instanceString]]);
    XCTAssert([self string:@"sendMessage(OurClass, 'plusFive:', 7);" evaluatesTo:@"12"]);
    XCTAssert([self string:@"sendMessage(OurClass, 'plusFive:', 7.9);" evaluatesTo:@"12"]);
    XCTAssert([self string:@"sendMessage(OurClass, 'plusFive:', 7) + 6;" evaluatesTo:@"18"]);
    
}
- (void)testNiceSendMessage{
    //NSLog(@"log: %@", [jsoc stringByEvaluatingString:@"var x = OurClass.alloc().init();x.instanceString();"]);
    XCTAssert([self string:@"OurClass.secretString()" evaluatesTo:[OurClass secretString]]);
    XCTAssert([self string:@"OurClass.new().instanceString();" evaluatesTo:[[OurClass new] instanceString]]);
    XCTAssert([self string:@"OurClass.alloc().init().instanceString();" evaluatesTo:[[OurClass new] instanceString]]);
    XCTAssert([self string:@"OurClass.plusFive(3)" evaluatesTo:@"8"]);
    
}
-(void)testStructHandling{
    XCTAssert([self string:@"OurClass.myRect().length" evaluatesTo:@"2"]);
    XCTAssert([self string:@"OurClass.myRect()[0].length" evaluatesTo:@"2"]);
    XCTAssert([self string:@"OurClass.myRect()[1].length" evaluatesTo:@"2"]);
    NSString * val = [NSString stringWithFormat:@"%d", [OurClass addRect:[OurClass myRect]]];
    XCTAssert([self string:@"OurClass.addRect(OurClass.myRect())" evaluatesTo:val]);
}
-(void)testViewStuff{
    XCTAssert([self string:@"view = UIView.alloc().initWithFrame([[0,0],[50,50]]); view.class();" evaluatesTo:[UIView description]]);
    XCTAssert([self string:@"view.setBackgroundColor(UIColor.redColor());view.backgroundColor();" evaluatesTo:[[UIColor redColor] description]]);
}
-(void)testMultiArguments{
    XCTAssert([self string:@"UIColor.colorWithRed.green.blue.alpha(1,.5,.25,1);"
               evaluatesTo:[[UIColor colorWithRed:1.0f green:.5f blue:.25f alpha:1.0f] description]]);
    
    XCTAssert([self string:@"UIColor.colorWithRed.green.blue.alpha(0,0,1,1);"
               evaluatesTo:[[UIColor colorWithRed:0.0f green:0.0f blue:1.0f alpha:1.0f] description]]);
}
@end
