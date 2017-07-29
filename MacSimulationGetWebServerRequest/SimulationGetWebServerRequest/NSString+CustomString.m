//
//  NSString+CustomString.m
//  SimulationGetWebServerRequest
//
//  Created by wujungao on 29/07/2017.
//  Copyright © 2017 wjg. All rights reserved.
//

#import "NSString+CustomString.h"

@implementation NSString (CustomString)

-(BOOL)isEmptyString{
    
    if([self isKindOfClass:[NSNull class]]
       || !self
       || self==NULL
       || ([self isKindOfClass:[NSString class]] && self.length==0)){
        
        return YES;
        
    }else{
        
        return NO;
    }
}

@end
