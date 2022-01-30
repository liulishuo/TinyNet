# TinyNet

一个小型网络库，用来验证插件系统。

核心为一个 start() 函数，实现了 request -> response 的映射。log、cache、loading，模型解析等能力通过函数嵌套，作为插件使用，这种设计导致核心库非常小，功能组合非常灵活。

相较于业界著名的 Moya ，同样重度依赖插件系统，但是 Moya 使用数组保存插件对象，在合适的时机遍历数组调用每个插件对应的方法，在使用中发现这种设计不灵活，侵入性强，效率低。

### 插件用法

```swift
let s = TinyNet.start ^
        ReMapM(destFactor: DF(successCode: 200, statusCodeKey: "code", messageKey: "message", modelKey: "")) ^
        LoadingM(.viewController(viewController), loadingDelay: 1) ^
        LogM() ^
        TestAPI.blogs
```



![未命名文件](/Users/liulishuo/Downloads/未命名文件.png)





### 完整请求

```swift
let s = TinyNet.start ^
        ReMapM(destFactor: DF(successCode: 200, statusCodeKey: "code", messageKey: "message", modelKey: "")) ^
        LoadingM(.viewController(viewController), loadingDelay: 1) ^
        LogM() ^
        TestAPI.blogs

    s?.mapArrayResult(RModel.Blog.self)
        .subscribe { result in
        /// HTTP Code == 200
        /// code 是业务状态码
         let ((suc, (code, message)), model) = result
            print("===>", suc, code, message, model)
    } onError: { error in
        /// HTTP Code != 200
        print("===> E: ", error)
    }
```



