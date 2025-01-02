//
//  JSTaskScheduler.m
//  RIAID-DEMO
//
//  Created by yinhao on 2025/1/2.
//

#import "JSTaskScheduler.h"
#import "JSTask.h"
#import "JSWorkerThread.h"
#import "JSThreadPoolManager.h"

@interface JSTaskScheduler()

@property (nonatomic, strong) NSMutableArray<JSTask *> *taskQueue;
@property (nonatomic, strong) dispatch_queue_t schedulerQueue;
@property (nonatomic, weak) JSThreadPoolManager *threadPool;

@end

@implementation JSTaskScheduler

- (instancetype)initWithThreadPool:(JSThreadPoolManager *)threadPool {
    if (self = [super init]) {
        _threadPool = threadPool;
        _taskQueue = [NSMutableArray array];
        _schedulerQueue = dispatch_queue_create("com.jstaskscheduler.queue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)scheduleTask:(JSTask *)task {
    if (!task) return;
    
    dispatch_async(self.schedulerQueue, ^{
        // 添加任务到队列
        [self.taskQueue addObject:task];
        
        // 按优先级排序
        [self sortTaskQueue];
        
        // 尝试分配任务
        [self assignTasks];
    });
}

- (void)balanceLoad {
    dispatch_async(self.schedulerQueue, ^{
        NSArray<JSWorkerThread *> *workers = self.threadPool.workerThreads;
        
        // 计算每个线程的负载
        NSMutableDictionary *threadLoads = [NSMutableDictionary dictionary];
        for (JSWorkerThread *worker in workers) {
            NSInteger load = worker.pendingTasks.count;
            threadLoads[@(worker.hash)] = @(load);
        }
        
        // 找出负载最重和最轻的线程
        JSWorkerThread *heaviestThread = nil;
        JSWorkerThread *lightestThread = nil;
        NSInteger maxLoad = 0;
        NSInteger minLoad = NSIntegerMax;
        
        for (JSWorkerThread *worker in workers) {
            NSInteger load = [threadLoads[@(worker.hash)] integerValue];
            if (load > maxLoad) {
                maxLoad = load;
                heaviestThread = worker;
            }
            if (load < minLoad) {
                minLoad = load;
                lightestThread = worker;
            }
        }
        
        // 如果负载差异大于阈值，进行任务迁移
        if (maxLoad - minLoad > 2 && heaviestThread && lightestThread) {
            NSInteger tasksToMove = (maxLoad - minLoad) / 2;
            
            for (NSInteger i = 0; i < tasksToMove; i++) {
                JSTask *task = [heaviestThread.pendingTasks lastObject];
                if (task && task.status == JSTaskStatusPending) {
                    [heaviestThread.pendingTasks removeLastObject];
                    [lightestThread.pendingTasks addObject:task];
                }
            }
        }
    });
}

#pragma mark - Private Methods

- (void)sortTaskQueue {
    [self.taskQueue sortUsingComparator:^NSComparisonResult(JSTask *task1, JSTask *task2) {
        // 优先级高的排在前面
        if (task1.priority > task2.priority) {
            return NSOrderedAscending;
        } else if (task1.priority < task2.priority) {
            return NSOrderedDescending;
        }
        return NSOrderedSame;
    }];
}

- (void)assignTasks {
    NSArray<JSWorkerThread *> *availableWorkers = [self getAvailableWorkers];
    if (availableWorkers.count == 0) return;
    
    NSMutableArray<JSTask *> *unassignedTasks = [NSMutableArray array];
    
    // 尝试分配任务
    for (JSTask *task in self.taskQueue) {
        JSWorkerThread *worker = [self findBestWorkerForTask:task fromWorkers:availableWorkers];
        if (worker) {
            [worker executeTask:task];
        } else {
            [unassignedTasks addObject:task];
        }
    }
    
    // 更新任务队列为未分配的任务
    self.taskQueue = unassignedTasks;
}

- (NSArray<JSWorkerThread *> *)getAvailableWorkers {
    return [self.threadPool.workerThreads filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(JSWorkerThread *worker, NSDictionary *bindings) {
        return worker.status != JSThreadStatusBusy;
    }]];
}

- (JSWorkerThread *)findBestWorkerForTask:(JSTask *)task fromWorkers:(NSArray<JSWorkerThread *> *)workers {
    JSWorkerThread *bestWorker = nil;
    NSInteger minLoad = NSIntegerMax;
    
    for (JSWorkerThread *worker in workers) {
        NSInteger load = worker.pendingTasks.count;
        if (load < minLoad) {
            minLoad = load;
            bestWorker = worker;
        }
    }
    
    return bestWorker;
}

@end
