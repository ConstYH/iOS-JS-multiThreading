// 辅助函数：格式化输出对象
function logObject(obj) { 
    if (!obj) {
        console.log('null or undefined');
        return;
    }
    // 遍历对象的属性并输出
    Object.keys(obj).forEach(key => {
        console.log(key + ':', obj[key]);
    });
}

// 简单测试：基本计算
function simpleTest() {
    console.log('执行简单测试...');
    doInSubThread(
        function(params) {
            console.log('Worker ' + params.workerId + ' 开始执行');
            let result = params.value * 2;
            console.log('Worker ' + params.workerId + ' 计算结果: ' + result);
            return result;
        },
        {
            workers: 2,
            params: { value: 21 },
            onResult: function(result) {
                console.log('收到结果: ' + result);
            },
            onComplete: function() {
                console.log('简单测试完成');
                // 执行下一个测试
                setTimeout(runDataTransformTest, 1000);
            }
        }
    );
}

// 数据转换测试
function runDataTransformTest() {
    console.log('开始数据转换测试...');
    const testData = Array.from({ length: 100 }, (_, i) => ({
        id: i,
        value: Math.random() * 100
    }));
    
    transformData(testData);
    
    // 执行下一个测试
    setTimeout(runComputeTest, 1000);
}

function transformData(data) {
    console.log('开始数据转换...');
    // 模拟数据转换
    const transformedData = data.map(item => ({
        id: item.id,
        value: item.value * 2
    }));
    console.log('数据转换完成:', transformedData);
}

// 计算测试
function runComputeTest() {
    console.log('开始并行计算测试...');
    parallelCompute({
        data: [1, 2, 3, 4, 5],
        method: nums => nums.map(n => n * n),
        workers: 2,
        onResult: result => console.log('计算结果:', result),
        onComplete: () => console.log('所有测试完成!')
    });
}

// 工具函数
const Utils = {
    // 斐波那契数列（迭代实现）
    fibonacci: function(n) {
        if (n <= 1) return n;
        let fib = [0, 1];
        for(let i = 2; i <= n; i++) {
            fib[i] = fib[i-1] + fib[i-2];
        }
        return fib[n];
    },
    
    // 其他工具函数...
};

// 计算密集型测试
function runHeavyComputeTest() {
    console.log('开始计算密集型测试...');
    
    // 准备测试数据
    const testCases = [
        { name: '斐波那契(200)', n: 200 },
        { name: '斐波那契(250)', n: 250 },
        { name: '斐波那契(300)', n: 300 },
        { name: '斐波那契(350)', n: 350 },
        { name: '斐波那契(400)', n: 400 },
        { name: '斐波那契(450)', n: 450 },
        { name: '斐波那契(500)', n: 500 },
        { name: '斐波那契(550)', n: 550 },
        { name: '斐波那契(600)', n: 600 },
        { name: '斐波那契(650)', n: 650 },
        { name: '斐波那契(700)', n: 700 },
    ];
    
    // 在子线程中执行计算
    doInSubThread(
        function(params) {
            const { testCase, workerId } = params;
            console.log('Worker ' + workerId + ' 开始计算:'+
                'name:'+ testCase.name+
                'n:'+ testCase.n);
            
            const startTime = Date.now();
            const result = Utils.fibonacci(testCase.n);
            const endTime = Date.now();
            
            return {
                name: testCase.name,
                workerId: workerId,
                computeTime: endTime - startTime,
                result: result
            };
        },
        {
            workers: testCases.length,
            params: { 
                testCases: testCases,  // 传递所有测试用例
                workerId: 0
            },
            onResult: function(result) {
                if (result) {
                    console.log('计算结果:'+' 测试用例:'+ result.name+
                        ' Worker ID:'+ result.workerId+
                        ' 计算时间:'+ result.computeTime + 'ms'+
                        ' 结果:'+ result.result
                    );
                } else {
                    console.error('计算失败: 结果为空');
                }
            },
            onComplete: function() {
                console.log('所有计算密集型测试完成');
                setTimeout(runDataTransformTest, 1000);
            }
        }
    );
}

// 修改测试执行顺序
function runAllTests() {
    console.log('开始执行测试序列...');
    
    // 首先执行计算密集型测试
    runHeavyComputeTest();
    
    // 其他测试会在各自的回调中被触发
}

// 并行计算函数
function parallelCompute(options) {
    const { data, method, workers, onResult, onComplete } = options;
    
    doInSubThread(
        function(params) {
            const { chunk, workerId } = params;
            return {
                workerId,
                result: method(chunk)
            };
        },
        {
            workers: workers || 2,
            params: { 
                chunk: data,
                workerId: 0
            },
            onResult: function(result) {
                if (onResult) onResult(result);
            },
            onComplete: function() {
                if (onComplete) onComplete();
            }
        }
    );
}

// 初始化和测试执行
console.log('JS环境初始化完成');
console.log('等待开始测试...');

// 开始执行测试
console.log('设置定时器...');
setTimeout(function() {
    try {
        console.log('定时器回调开始执行');
        runAllTests();
    } catch (error) {
        console.error('测试执行错误:', error);
        console.error('错误堆栈:', error.stack);
    }
}, 500);

console.log('定时器设置完成'); 
