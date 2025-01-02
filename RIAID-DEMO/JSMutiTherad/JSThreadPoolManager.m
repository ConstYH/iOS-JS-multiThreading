//
//  JSThreadPoolManager.m
//  RIAID-DEMO
//
//  Created by yinhao on 2025/1/2.
//

#import "JSThreadPoolManager.h"
#import "JSWorkerThread.h"
#import "JSTaskScheduler.h"

@interface JSThreadPoolManager() <JSWorkerDelegate>

@property (nonatomic, strong) JSTaskScheduler *scheduler;
@property (nonatomic, assign) NSInteger maxPoolSize;
@property (nonatomic, strong) dispatch_queue_t managerQueue;

@end

@implementation JSThreadPoolManager

+ (instancetype)sharedInstance {
    static JSThreadPoolManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[JSThreadPoolManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _workerThreads = [NSMutableArray array];
        _taskQueue = [[NSOperationQueue alloc] init];
        _maxPoolSize = 4; // 默认最大4个线程
        _managerQueue = dispatch_queue_create("com.jsthreadpool.queue", DISPATCH_QUEUE_SERIAL);
        
        // 创建任务调度器
        _scheduler = [[JSTaskScheduler alloc] initWithThreadPool:self];
        
        // 初始化线程池
        [self initializeWorkerThreads];
    }
    return self;
}

- (void)initializeWorkerThreads {
    dispatch_async(self.managerQueue, ^{
        for (NSInteger i = 0; i < self.maxPoolSize; i++) {
            JSWorkerThread *worker = [[JSWorkerThread alloc] initWithDelegate:self];
            [self.workerThreads addObject:worker];
        }
    });
}

- (void)executeTask:(JSTask *)task {
    if (!task) return;
    
    dispatch_async(self.managerQueue, ^{
        [self.scheduler scheduleTask:task];
    });
}

- (void)adjustPoolSize:(NSInteger)size {
    if (size < 1) return;
    
    dispatch_async(self.managerQueue, ^{
        if (size > self.maxPoolSize) {
            // 增加线程
            NSInteger threadsToAdd = size - self.maxPoolSize;
            for (NSInteger i = 0; i < threadsToAdd; i++) {
                JSWorkerThread *worker = [[JSWorkerThread alloc] initWithDelegate:self];
                [self.workerThreads addObject:worker];
            }
        } else if (size < self.maxPoolSize) {
            // 减少线程
            NSInteger threadsToRemove = self.maxPoolSize - size;
            NSArray *workersToRemove = [self.workerThreads subarrayWithRange:NSMakeRange(size, threadsToRemove)];
            [self.workerThreads removeObjectsInArray:workersToRemove];
        }
        
        self.maxPoolSize = size;
        
        // 重新平衡负载
        [self.scheduler balanceLoad];
    });
}

#pragma mark - JSWorkerDelegate

- (void)worker:(JSWorkerThread *)worker didCompleteTask:(JSTask *)task {
    dispatch_async(self.managerQueue, ^{
        // 任务完成后，检查是否需要重新平衡负载
        [self.scheduler balanceLoad];
    });
}

- (void)worker:(JSWorkerThread *)worker didFailWithError:(NSError *)error {
    NSLog(@"Worker %@ failed with error: %@", worker, error);
    
    dispatch_async(self.managerQueue, ^{
        // 如果线程失败，可以考虑重新创建一个新的线程
        NSInteger index = [self.workerThreads indexOfObject:worker];
        if (index != NSNotFound) {
            [self.workerThreads removeObject:worker];
            JSWorkerThread *newWorker = [[JSWorkerThread alloc] initWithDelegate:self];
            [self.workerThreads insertObject:newWorker atIndex:index];
        }
    });
}

@end
