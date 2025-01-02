//
//  JSTask.m
//  RIAID-DEMO
//
//  Created by yinhao on 2025/1/2.
//

#import "JSTask.h"

@interface JSTask()

@property (nonatomic, strong) NSDate *createTime;
@property (nonatomic, strong) NSDate *startTime;
@property (nonatomic, strong) NSDate *endTime;
@property (nonatomic, assign) JSTaskStatus status;

@end

@implementation JSTask

- (instancetype)initWithScript:(NSString *)scriptString {
    if (self = [super init]) {
        _scriptString = [scriptString copy];
        _params = @{};
        _priority = JSTaskPriorityDefault;
        _status = JSTaskStatusPending;
        _createTime = [NSDate date];
        _timeout = 30.0; // 默认30秒超时
    }
    return self;
}

- (instancetype)initWithScript:(NSString *)scriptString params:(NSDictionary *)params {
    if (self = [super init]) {
        _scriptString = [scriptString copy];
        _params = [params copy];
        _priority = JSTaskPriorityDefault;
        _status = JSTaskStatusPending;
        _createTime = [NSDate date];
        _timeout = 30.0;
    }
    return self;
}

#pragma mark - Task Lifecycle

- (void)prepare {
    if (self.status != JSTaskStatusPending) return;
    
    self.status = JSTaskStatusPreparing;
    
    // 执行预处理逻辑
    if (self.prepareBlock) {
        self.prepareBlock(self);
    }
    
    self.status = JSTaskStatusReady;
}

- (void)execute {
    if (self.status != JSTaskStatusReady) return;
    
    self.status = JSTaskStatusRunning;
    self.startTime = [NSDate date];
    
    // 设置超时定时器
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.timeout * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [weakSelf checkTimeout];
    });
}

- (void)complete:(id)result error:(NSError *)error {
    self.endTime = [NSDate date];
    
    if (error) {
        self.status = JSTaskStatusFailed;
        if (self.errorCallback) {
            self.errorCallback(error);
        }
    } else {
        self.status = JSTaskStatusCompleted;
        if (self.callback) {
            self.callback(result);
        }
    }
    
    // 执行清理工作
    [self cleanup];
}

- (void)cancel {
    if (self.status == JSTaskStatusRunning || self.status == JSTaskStatusReady) {
        self.status = JSTaskStatusCancelled;
        
        NSError *error = [NSError errorWithDomain:@"JSTaskErrorDomain"
                                           code:-1
                                       userInfo:@{NSLocalizedDescriptionKey: @"Task cancelled"}];
        
        if (self.errorCallback) {
            self.errorCallback(error);
        }
        
        [self cleanup];
    }
}

#pragma mark - Private Methods

- (void)checkTimeout {
    if (self.status == JSTaskStatusRunning) {
        NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:self.startTime];
        if (duration >= self.timeout) {
            NSError *error = [NSError errorWithDomain:@"JSTaskErrorDomain"
                                               code:-2
                                           userInfo:@{NSLocalizedDescriptionKey: @"Task timeout"}];
            [self complete:nil error:error];
        }
    }
}

- (void)cleanup {
    // 清理资源
    self.prepareBlock = nil;
    self.callback = nil;
    self.errorCallback = nil;
}

#pragma mark - Getters

- (NSTimeInterval)duration {
    if (!self.startTime) return 0;
    
    NSDate *end = self.endTime ?: [NSDate date];
    return [end timeIntervalSinceDate:self.startTime];
}

- (NSTimeInterval)lifeTime {//存活时间，单位毫秒
    if (!self.createTime) return 0;
    
    NSDate *now = [NSDate date];
    return [now timeIntervalSinceDate:self.createTime] * 1000; // 转换为毫秒
}


- (NSString *)description {
    return [NSString stringWithFormat:@"JSTask: %p, 已经被创建: %.2fms",
            self, self.lifeTime];
}

@end
