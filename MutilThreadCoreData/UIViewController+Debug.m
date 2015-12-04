//
//  UIViewController+Debug.m
//  WoPlus
//
//  Created by 朱大茂 on 15/12/3.
//  Copyright (c) 2015年 zhudm. All rights reserved.
//

#import "UIViewController+Debug.h"
#import <objc/objc-runtime.h>

@implementation UIViewController (Debug)

+ (void)load{
    Method  method = class_getInstanceMethod([self class], NSSelectorFromString(@"dealloc"));
    Method  newmethod = class_getInstanceMethod([self class], @selector(dealloc_Debug));
    
    method_exchangeImplementations(method, newmethod);
}

- (void)dealloc_Debug{
     NSLog(@"%@ delloc",NSStringFromClass([self class]));
    [self dealloc_Debug];
}

@end
