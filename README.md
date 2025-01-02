# JS多线程方案设计
在移动客户端场景，JSCore/v8引擎均不支持JS多线程操作，我们希望实现一种机制，可以使得JS代码同时在不同的线程上运行。并且需要支持跨线程的通信。

## 可行方案

### 1. 多JSContext + 原生线程池方案

优点：
- 可以实现真正的多线程执行
- 线程池可以复用，降低创建开销
- 通过原生层实现可靠的线程间通信
- 可以灵活控制线程数量和任务调度

缺点：
- 需要维护多个JSContext实例
- 内存占用相对较高
- 需要处理好线程同步问题
- 上下文隔离，状态共享需要特殊处理

实现要点：
- 创建原生线程池管理多个工作线程
- 每个工作线程绑定独立的JSContext
- 通过原生消息队列实现线程间通信
- 实现任务分发和调度机制

### 2. 单JSContext + 任务队列方案

优点：
- 实现简单，无需处理线程同步
- 内存占用小
- 适合轻量级任务
- 容易维护状态一致性

缺点：
- 不是真正的多线程执行
- 无法充分利用多核性能
- 大任务仍可能阻塞主线程
- 任务调度精度受限

实现要点：
- 将大任务拆分为微任务
- 使用定时器错开执行时间
- 实现优先级队列
- 监控执行时间避免阻塞

### 3. 混合模式方案

核心思路：
- 轻量任务使用任务队列处理
- 重任务使用独立JSContext执行
- 动态创建和销毁工作线程
- 实现任务分类和调度策略

关键设计：
1. 任务分类
   - 计算密集型：独立线程执行
   - IO密集型：异步队列处理
   - 普通任务：主线程执行

2. 线程管理
   - 维护线程池生命周期
   - 动态扩缩容
   - 任务负载均衡
   - 异常隔离和恢复

3. 通信机制
   - 原生消息队列
   - 共享内存（可选）
   - 状态同步策略
   - 结果回调机制

4. 性能优化
   - 预热机制
   - 缓存复用
   - 监控告警
   - 自动化降级

注意事项：
- JSContext必须在创建它的线程上执行
- 避免频繁创建销毁JSContext
- 合理设置线程池大小
- 做好异常处理和容错
- 添加性能监控和调试手段

## 类图设计

### 核心类

1. JSThreadPoolManager
   - 单例模式，负责整体线程池管理
   ```objc
   @interface JSThreadPoolManager : NSObject
   @property (nonatomic, strong) NSMutableArray<JSWorkerThread *> *workerThreads;
   @property (nonatomic, strong) NSOperationQueue *taskQueue;
   + (instancetype)sharedInstance;
   - (void)executeTask:(JSTask *)task;
   - (void)adjustPoolSize:(NSInteger)size;
   @end
   ```

2. JSWorkerThread
   - 工作线程封装，管理JSContext生命周期
   ```objc
   @interface JSWorkerThread : NSThread
   @property (nonatomic, strong) JSContext *jsContext;
   @property (nonatomic, strong) NSMutableArray<JSTask *> *pendingTasks;
   @property (nonatomic, assign) JSThreadStatus status;
   - (void)setupJSContext;
   - (void)executeTask:(JSTask *)task;
   @end
   ```

3. JSTask
   - 任务模型，封装JS执行单元
   ```objc
   @interface JSTask : NSObject
   @property (nonatomic, copy) NSString *scriptString;
   @property (nonatomic, strong) NSDictionary *params;
   @property (nonatomic, copy) JSTaskCallback callback;
   @property (nonatomic, assign) JSTaskPriority priority;
   @end
   ```

4. JSMessageBridge
   - 线程间通信桥接器
   ```objc
   @interface JSMessageBridge : NSObject
   @property (nonatomic, weak) JSWorkerThread *workerThread;
   - (void)postMessage:(id)message toThread:(JSWorkerThread *)thread;
   - (void)registerMessageHandler:(JSMessageHandler)handler;
   @end
   ```

### 辅助类

1. JSTaskScheduler
   ```objc
   @interface JSTaskScheduler : NSObject
   - (void)scheduleTask:(JSTask *)task;
   - (void)balanceLoad;
   @end
   ```

2. JSContextManager
   ```objc
   @interface JSContextManager : NSObject
   - (JSContext *)createContext;
   - (void)setupGlobalAPI:(JSContext *)context;
   @end
   ```

### 关键协议

1. JSWorkerDelegate
   ```objc
   @protocol JSWorkerDelegate <NSObject>
   - (void)worker:(JSWorkerThread *)worker didCompleteTask:(JSTask *)task;
   - (void)worker:(JSWorkerThread *)worker didFailWithError:(NSError *)error;
   @end
   ```

2. JSTaskProtocol
   ```objc
   @protocol JSTaskProtocol <NSObject>
   - (void)prepare;
   - (void)execute;
   - (void)cancel;
   @end
   ```

### 类图关系
```
JSThreadPoolManager (Singleton)
├── owns → JSWorkerThread[]
├── uses → JSTaskScheduler
└── manages → JSContextManager
JSWorkerThread
├── owns → JSContext
├── owns → JSMessageBridge
└── executes → JSTask[]
JSTask
├── implements → JSTaskProtocol
└── uses → JSMessageBridge
JSMessageBridge
└── connects → JSWorkerThread ←→ JSWorkerThread
```
### 注意事项
1. JSContext只能在创建它的线程上执行
2. 线程池大小应该可配置且动态调整
3. 任务调度需要考虑优先级和负载均衡
4. 通信机制要保证线程安全
5. 需要实现完善的错误处理和资源回收机制