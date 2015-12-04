//
//  ViewController.h
//  MutilThreadCoreData
//
//  Created by 朱大茂 on 15/12/4.
//  Copyright (c) 2015年 zhudm. All rights reserved.
//

#import <UIKit/UIKit.h>

#define CoreDataMutipltyByNotification 0

/**
 *  测试 coreData 多线程环境数据处理
 *  CoreDataMutipltyByNotification 1 使用通知处理多线程 [thread confinement]
 *  CoreDataMutipltyByNotification 0 使用IOS5 之后的新特性 父 NSManagedObjectContext [Nested Moc]
 */

@interface ViewController : UIViewController


@end

