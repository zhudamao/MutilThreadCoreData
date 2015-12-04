//
//  ViewController.m
//  MutilThreadCoreData
//
//  Created by 朱大茂 on 15/12/4.
//  Copyright (c) 2015年 zhudm. All rights reserved.
//

#import "ViewController.h"
#import "AppDelegate.h"

@interface ViewController ()<UITableViewDataSource,UITableViewDelegate,NSFetchedResultsControllerDelegate>
{
    
}

@property (strong, nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic, strong) NSArray * dataArry; // 只能保存 NSManagedObjectID
@property (nonatomic, strong) NSFetchedResultsController  * fetchedResultsController;

#if CoreDataMutipltyByNotification

#else
@property (nonatomic, strong) NSManagedObjectContext * backWriteContex;// 负责后台写
@property (nonatomic, strong) NSManagedObjectContext * mainContex;
#endif

@end

@implementation ViewController

+ (void)initialize{
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
   // dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self p_checkData];
    //});
}

#if CoreDataMutipltyByNotification
- (void)p_checkData{
    AppDelegate * delegate = [UIApplication sharedApplication].delegate;
    NSManagedObjectContext * contex = delegate.managedObjectContext;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error;
        NSManagedObjectContext * tempContex = [[NSManagedObjectContext alloc]initWithConcurrencyType:NSConfinementConcurrencyType];
        tempContex.persistentStoreCoordinator = delegate.persistentStoreCoordinator;
        NSFetchRequest * request = [[NSFetchRequest alloc]initWithEntityName:@"Salary"];
        NSSortDescriptor * sorDescriptor = [[NSSortDescriptor alloc]initWithKey:@"money" ascending:NO];
        request.sortDescriptors = @[sorDescriptor];
        request.fetchLimit = 100;
        request.resultType = NSManagedObjectIDResultType;
        
        //[self.dataArry removeAllObjects];
        
        NSArray * arry = [tempContex executeFetchRequest:request error:&error];
        if (arry.count > 0) {
            NSManagedObjectID * salaryId = arry[0];
            //obj.objectID;//在不同线程中 只能通过 NSManagedObjectID 传递NSMangedObject，不能直接传递mangeobject 会有问题
            self.dataArry = arry;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                NSManagedObject * obj = [contex objectWithID:salaryId];// 用主线程的context 去获取
                if (obj) {
                    NSLog(@"%@ %@",[obj valueForKey:@"date"],[obj valueForKey:@"money"]);
                }
                [self.tableView reloadData];
            });
        }
    });
}

#else
- (void)p_checkData{
    NSManagedObjectContext * tempContex = [[NSManagedObjectContext alloc]initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    tempContex.parentContext = self.mainContex;
    
    [tempContex performBlock:^{
        NSError *error;
        NSFetchRequest * request = [[NSFetchRequest alloc]initWithEntityName:@"Salary"];
        NSSortDescriptor * sorDescriptor = [[NSSortDescriptor alloc]initWithKey:@"money" ascending:NO];
        request.sortDescriptors = @[sorDescriptor];
        request.fetchLimit = 100;
        request.resultType = NSManagedObjectIDResultType;
        NSArray * arry = [tempContex executeFetchRequest:request error:&error];
        
        self.dataArry = arry;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
        });
    }];
}


#endif

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#if CoreDataMutipltyByNotification
- (IBAction)addObject:(id)sender {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSUInteger  num = 2;
/*
 * 插入的同时，查询 会导致crash，所以说，NSManagedObjectContext 不是线程安全的
 **/
            NSError *error;
            AppDelegate * delegate = [UIApplication sharedApplication].delegate;
//            NSManagedObjectContext * contex = delegate.managedObjectContext;
        
/***********************************改进如下****************************************************/
        NSManagedObjectContext * tempContex = [[NSManagedObjectContext alloc]initWithConcurrencyType:NSConfinementConcurrencyType];
        tempContex.persistentStoreCoordinator = delegate.persistentStoreCoordinator;/*persistenStoreCoordinator 虽然不是线程安全的，单NSMangeedObjectContex 在使用时如何加锁*/
        
        for (NSUInteger i = 0 ; i < num; i++) {
            NSManagedObject * obj = [NSEntityDescription insertNewObjectForEntityForName:@"Salary" inManagedObjectContext:tempContex];
            [NSThread sleepForTimeInterval:1.0];
            [obj setValue:[NSNumber numberWithDouble:i *3.1415926] forKey:@"money"];
            [obj setValue:[NSDate date] forKey:@"date"];
        }
        
        [tempContex save:&error];
    });
}

- (IBAction)refreshNow:(id)sender {
    [self p_checkData];
}

#else

- (IBAction)refreshNow:(id)sender {
    [self p_checkData];
}

- (IBAction)addObject:(id)sender {
    //dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSUInteger  num = 2;
/***********************************改进如下****************************************************/    
        NSManagedObjectContext * tempContex = [[NSManagedObjectContext alloc]initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        tempContex.parentContext = self.mainContex;
        //performBlockAndWait总是在调用线程中运行。performBlock它总是排队块到接收任务的队列
        [tempContex performBlock:^{//迫使让你在正确的线程或队列当中进行数据操作
            NSError *error;
            for (NSUInteger i = 0 ; i < num; i++) {
                NSManagedObject * obj = [NSEntityDescription insertNewObjectForEntityForName:@"Salary" inManagedObjectContext:tempContex];
                [NSThread sleepForTimeInterval:1.0];
                
                [obj setValue:[NSNumber numberWithDouble:i *3.1415926] forKey:@"money"];
                [obj setValue:[NSDate date] forKey:@"date"];
            }
            
            if (![tempContex save:&error]) {
                NSLog(@"%@",error.description);
                return ;
            }
            
            if (![self.mainContex save:&error] || ![self.backWriteContex save:&error]) {
                NSLog(@"%@",error.description);
                return;
            }
        }];
    
    //});
}

- (NSManagedObjectContext *)backWriteContex{
    if (_backWriteContex == nil) {
        AppDelegate * delegate = [UIApplication sharedApplication].delegate;
        _backWriteContex = [[NSManagedObjectContext alloc]initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        _backWriteContex.persistentStoreCoordinator = delegate.persistentStoreCoordinator;
    }

    return _backWriteContex;
}

- (NSManagedObjectContext *)mainContex{
    if (_mainContex == nil) {
        
        _mainContex = [[NSManagedObjectContext alloc]initWithConcurrencyType:NSMainQueueConcurrencyType];
        _mainContex.parentContext = self.backWriteContex;
    }
    return _mainContex;
}

#endif

- (NSFetchedResultsController *)fetchedResultsController{
    if (!_fetchedResultsController) {
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        // Edit the entity name as appropriate.
#if CoreDataMutipltyByNotification
        AppDelegate * delegate = [UIApplication sharedApplication].delegate;
        NSManagedObjectContext * contex = delegate.managedObjectContext;
#else
        NSManagedObjectContext * contex = self.mainContex;
#endif
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Salary" inManagedObjectContext:contex];

        [fetchRequest setEntity:entity];// 设定查询的表
        
        // Set the batch size to a suitable number.
        [fetchRequest setFetchBatchSize:20];
        
        // Edit the sort key as appropriate.
        NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:NO];//查询条件
        NSArray *sortDescriptors = @[sortDescriptor];
        
        [fetchRequest setSortDescriptors:sortDescriptors];//设置查询条件
        
        // Edit the section name key path and cache name if appropriate.
        // nil for section name key path means "no sections".
        [NSFetchedResultsController deleteCacheWithName:nil];
        NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:contex sectionNameKeyPath:nil cacheName:@"Master"]; // 在这里 传入fetchRequest
        aFetchedResultsController.delegate = self;
        _fetchedResultsController = aFetchedResultsController;
        
        NSError *error = nil;
        if (![self.fetchedResultsController performFetch:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            //abort();
        }
    }

    return _fetchedResultsController;
}

#pragma mark -UITableViewDelegate
/*
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return _dataArry? _dataArry.count:0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"subCell"];
    AppDelegate * delegate = [UIApplication sharedApplication].delegate;
    NSManagedObjectContext * contex = delegate.managedObjectContext;//用主线程的context 取值
    NSManagedObjectID * idx = _dataArry[indexPath.row];
    
    NSManagedObject * obj = [contex objectWithID:idx];// 用主线程的context 去获取

    NSDate * now = [obj valueForKey:@"date"];
    cell.textLabel.text = now.description;
    cell.detailTextLabel.text = [[obj valueForKey:@"money"] stringValue];

    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath{
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSManagedObjectID * idx = _dataArry[indexPath.row];

#if  CoreDataMutipltyByNotification
        AppDelegate * delegate = [UIApplication sharedApplication].delegate;
        NSManagedObjectContext * contex = delegate.managedObjectContext;//用主线程的context 取值
        NSManagedObject * obj = [contex objectWithID:idx];
        [contex deleteObject:obj];
        [contex save:nil];
#else
        NSManagedObject * obj = [self.backWriteContex objectWithID:idx];// 用主线程的context 去获取
        [self.backWriteContex deleteObject:obj];
        [self.backWriteContex save:nil];
#endif
        NSMutableArray * tempArry = [_dataArry mutableCopy];
        [tempArry removeObjectAtIndex:indexPath.row];
        _dataArry = [tempArry copy];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationLeft];
    }
}*/
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[self.fetchedResultsController sections] count];// section 数目
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    return [sectionInfo numberOfObjects]; // 每个section 的objects 个数
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"subCell" forIndexPath:indexPath];
    NSManagedObject *obj = [self.fetchedResultsController objectAtIndexPath:indexPath];
    NSDate * now = [obj valueForKey:@"date"];
    cell.textLabel.text = now.description;
    cell.detailTextLabel.text = [[obj valueForKey:@"money"] stringValue];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    NSManagedObject *obj = [self.fetchedResultsController objectAtIndexPath:indexPath];
    
    [obj setValue:[NSNumber numberWithDouble:indexPath.row *.1415926] forKey:@"money"];
    [self.fetchedResultsController.managedObjectContext save:nil];
    
#if  !CoreDataMutipltyByNotification
    [self.backWriteContex save:nil];
#endif
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        [context deleteObject:[self.fetchedResultsController objectAtIndexPath:indexPath]];
        
        NSError *error = nil;
        if (![context save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
           // abort();
        }
    }
}

#pragma mark -NSFetchedResultsControllerDelegate
- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];// 插入section
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationRight];
            break;
        default:
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    UITableView *tableView = self.tableView;
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];// 插入rows
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
        {
            UITableViewCell * cell = [tableView cellForRowAtIndexPath:indexPath];
            NSManagedObject *obj = [self.fetchedResultsController objectAtIndexPath:indexPath];
            NSDate * now = [obj valueForKey:@"date"];
            cell.textLabel.text = now.description;
            cell.detailTextLabel.text = [[obj valueForKey:@"money"] stringValue];
        }
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
    
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView endUpdates];
}

#pragma mark -UIStroyBoard
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    UIViewController * dest = segue.destinationViewController;
    UITableViewCell * cell = (UITableViewCell *)sender;
    
    NSIndexPath * indexPath = [self.tableView indexPathForCell:cell];
    NSManagedObject *obj = [self.fetchedResultsController objectAtIndexPath:indexPath];
    
    dest.title = [[obj valueForKey:@"money"] stringValue];
}

@end
