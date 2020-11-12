/**
 * 问问我
 */
var global = this;


var test = ""


(function() {
    

    /**
     * 222
     */
    var _ocCls = {};
    var _jsCls = {};
    // log处理
    if (global.console) {
        var jsLogger = console.log;
        global.console.log = function() {
            global._OC_log.apply(global, arguments);
            if (jsLogger) {
                jsLogger.apply(global.console, arguments);
            }
        }
    } else {
        global.console = {
           log: global._OC_log
        }
    }

    /**
     * 1. require处理 这一段处理完成后，所有的OC类都会加入到 global {__clsName:UIButton}
     */
    global.require = function() {
        var lastRequire
        for (var i = 0; i < arguments.length; i ++) {
            arguments[i].split(',').forEach(function(clsName) {
                lastRequire = _require(clsName.trim())
            })
        }
        return lastRequire
    }
    
    var _require = function(clsName) {
        if (!global[clsName]) {
            global[clsName] = {
            __clsName: clsName
            }
        }
        return global[clsName]
    }
    // 2. defineClass定义declaration OC类名 properties 函数例如viewDidLoad
    global.defineClass = function(declaration, properties, instMethods, clsMethods) {
        var newInstMethods = {}, newClsMethods = {}
        if (!(properties instanceof Array)) {
            clsMethods = instMethods
            instMethods = properties
            properties = null
        }
        if (properties) {
            properties.forEach(function(name){
                if (!instMethods[name]) {
                    instMethods[name] = _propertiesGetFun(name);
                }
                var nameOfSet = "set"+ name.substr(0,1).toUpperCase() + name.substr(1);
                if (!instMethods[nameOfSet]) {
                    instMethods[nameOfSet] = _propertiesSetFun(name);
                }
            });
        }
        var realClsName = declaration.split(':')[0].trim()
        _formatDefineMethods(instMethods, newInstMethods, realClsName)
        _formatDefineMethods(clsMethods, newClsMethods, realClsName)
        // 在OC中定义
        var ret = _OC_defineClass(declaration, newInstMethods, newClsMethods)
        var className = ret['cls']
        var superCls = ret['superCls']
        // 初始化该类的类方法和实例方法到 _ocCls 中
        _ocCls[className] = {
            instMethods: {},
            clsMethods: {},
        }
        if (superCls.length && _ocCls[superCls]) {
            for (var funcName in _ocCls[superCls]['instMethods']) {
                _ocCls[className]['instMethods'][funcName] = _ocCls[superCls]['instMethods'][funcName]
            }
            for (var funcName in _ocCls[superCls]['clsMethods']) {
                _ocCls[className]['clsMethods'][funcName] = _ocCls[superCls]['clsMethods'][funcName]
            }
        }
        _setupJSMethod(className, instMethods, 1, realClsName)
        _setupJSMethod(className, clsMethods, 0, realClsName)
        return require(className)
    }
    var _setupJSMethod = function(className, methods, isInst, realClsName) {
        for (var name in methods) {
            var key = isInst ? 'instMethods': 'clsMethods',
            func = methods[name]
            _ocCls[className][key][name] = _wrapLocalMethod(name, func, realClsName)
        }
    }
    var _wrapLocalMethod = function(methodName, func, realClsName) {
        return function() {
            var lastSelf = global.self
            global.self = this
            this.__realClsName = realClsName
            var ret = func.apply(this, arguments)
            global.self = lastSelf
            return ret
        }
    }
    // 3.属性get set方法
    var _propertiesGetFun = function(name){
        return function(){
            var slf = this;
            if (!slf.__ocProps) {
                var props = _OC_getCustomProps(slf.__obj)
                if (!props) {
                    props = {}
                    _OC_setCustomProps(slf.__obj, props)
                }
                slf.__ocProps = props;
            }
            return slf.__ocProps[name];
        };
    }
    var _propertiesSetFun = function(name){
        return function(jval){
            var slf = this;
            if (!slf.__ocProps) {
                var props = _OC_getCustomProps(slf.__obj)
                if (!props) {
                    props = {}
                    _OC_setCustomProps(slf.__obj, props)
                }
                slf.__ocProps = props;
            }
            slf.__ocProps[name] = jval;
        };
    }
    //4.调用的方法切片处理，将js文件的方法转换成可执行的方法
    var _formatDefineMethods = function(methods, newMethods, realClsName) {
        for (var methodName in methods) {
            if (!(methods[methodName] instanceof Function)) return;
            (function(){
                var originMethod = methods[methodName]
                // 把原来的 method 拿出来，新的 method 变成了一个数组，第一个参数是原来方法的调用参数的个数，第二个参数是
                // 因为runtime 添加方法的时候需要设置函数签名，因此需要知道方法中参数个数。这里直接在 js 中将参数个数取出
                newMethods[methodName] = [originMethod.length, function() {
                    try {
                        // js 端执行的方法，需要先把参数转为 js 的类型
                        var args = _formatOCToJS(Array.prototype.slice.call(arguments))
                        // 暂存之前的 self 对象
                        var lastSelf = global.self
                        // oc 调用 js 方法的时候，默认第一个参数是 self
                        global.self = args[0]
                        if (global.self) global.self.__realClsName = realClsName
                            // oc 调用 js 方法的时候，第一个参数是 self，因此要把它去掉。
                            args.splice(0,1)
                            // 调用 js 方法
                            var ret = originMethod.apply(originMethod, args)
                            // 恢复 原始的 self 指向
                            global.self = lastSelf
                            return ret
                            } catch(e) {
                                _OC_catch(e.message, e.stack)
                            }
                }]
            })()
        }
    }

    //5.把OC转js对象
    var _formatOCToJS = function(obj) {
        // 如果 oc 端返回的直接是 undefined 或者 null，那么直接返回 false
        if (obj === undefined || obj === null) return false
            if (typeof obj == "object") {
                // js 传给 oc 时会把自己包裹在 __obj 中。因此，存在 __obj 就可以直接拿到 js 对象
                if (obj.__obj) return obj
                    // 如果是空，那么直接返回 false。因为如果返回 null 的话，就无法调用方法了。
                    if (obj.__isNil) return false
                        }
        // 如果是数组，要对每一个 oc 转 js 一下
        if (obj instanceof Array) {
            var ret = []
            obj.forEach(function(o) {
                ret.push(_formatOCToJS(o))
            })
            return ret
        }
        if (obj instanceof Function) {
            return function() {
                var args = Array.prototype.slice.call(arguments)
                // 如果 oc 传给 js 的是一个函数，那么 js 端调用的时候就需要先把 js 参数转为 oc 对象，调用。
                var formatedArgs = _OC_formatJSToOC(args)
                for (var i = 0; i < args.length; i++) {
                    if (args[i] === null || args[i] === undefined || args[i] === false) {
                        formatedArgs.splice(i, 1, undefined)
                    } else if (args[i] == nsnull) {
                        formatedArgs.splice(i, 1, null)
                    }
                }
                // 在调用完 oc 方法后，又要 oc 对象转为 js 对象回传给 oc
                return _OC_formatOCToJS(obj.apply(obj, formatedArgs))
            }
        }
        if (obj instanceof Object) {
            // 如果是一个 object 并且没有 __obj，那么把所有的 key 都 format 一遍
            var ret = {}
            for (var key in obj) {
                ret[key] = _formatOCToJS(obj[key])
            }
            return ret
        }
        return obj
    }
    /// 提供方法给OC调用
    var _customMethods = {
        __c: function(methodName) {
            var slf = this
            // 如果 oc 返回了一个空对象，在 js 端会以 false 的形式接受。当这个空对象再调用方法的时候，就会走到这个分支中，直接返回 false，而不会走 oc 的消息转发
            if (slf instanceof Boolean) {
                return function() {
                    return false
                }
            }
            if (slf[methodName]) {
                return slf[methodName].bind(slf);
            }
            /// 如果当前调用的父类的方法，那么通过 OC 方法获取该 clsName 的父类的名字
            if (!slf.__obj && !slf.__clsName) {
                throw new Error(slf + '.' + methodName + ' is undefined')
            }
            if (slf.__isSuper && slf.__clsName) {
                slf.__clsName = _OC_superClsName(slf.__obj.__realClsName ? slf.__obj.__realClsName: slf.__clsName);
            }
            var clsName = slf.__clsName
            if (clsName && _ocCls[clsName]) {
                /// 根据 __obj 字段判断是否是实例方法或者类方法
                var methodType = slf.__obj ? 'instMethods': 'clsMethods'
                /// 如果当前方法是提前定义的方法，那么直接走定义方法的调用
                if (_ocCls[clsName][methodType][methodName]) {
                    slf.__isSuper = 0;
                    return _ocCls[clsName][methodType][methodName].bind(slf)
                }
            }
            /// 当前方法不是在 js 中定义的，那么直接调用 oc 的方法
            return function(){
                var args = Array.prototype.slice.call(arguments)
                return _methodFunc(slf.__obj, slf.__clsName, methodName, args, slf.__isSuper)
            }
        },
        
        super: function() {
            var slf = this
            if (slf.__obj) {
                slf.__obj.__realClsName = slf.__realClsName;
            }
            return {__obj: slf.__obj, __clsName: slf.__clsName, __isSuper: 1}
        },
        
        performSelectorInOC: function() {
            var slf = this
            var args = Array.prototype.slice.call(arguments)
            return {__isPerformInOC:1, obj:slf.__obj, clsName:slf.__clsName, sel: args[0], args: args[1], cb: args[2]}
        },
            
        performSelector: function() {
            var slf = this
            var args = Array.prototype.slice.call(arguments)
            return _methodFunc(slf.__obj, slf.__clsName, args[0], args.splice(1), slf.__isSuper, true)
        }
    }
    //6.执行方法一定要注意顺序
    for (var method in _customMethods) {
        if (_customMethods.hasOwnProperty(method)) {
            Object.defineProperty(Object.prototype, method, {value: _customMethods[method], configurable:false, enumerable: false})
        }
    }
    //7.调用OC的方法
    var _methodFunc = function(instance, clsName, methodName, args, isSuper, isPerformSelector) {
        var selectorName = methodName
        // js 端的方法都是 xxx_xxx 的形式，而 oc 端的方法已经在 defineClass 的时候转为了 xxx:xxx: 的形式。所以一般情况下 js 调用 oc 方法的时候都需要先把方法名转换一下。也就是当 isPerformSelector 为 false 的情况。
        // 那么什么时候这个属性为 true 呢？当 js 端调用 performSelector 这个的方法的时候。这个方法默认需要传入 xxx:xxx: 形式的 OC selector 名。
        // 一般 performSelector 用于从 oc 端动态传来 selectorName 需要 js 执行的时候。没有太多的使用场景
        if (!isPerformSelector) {
            methodName = methodName.replace(/__/g, "-")
            selectorName = methodName.replace(/_/g, ":").replace(/-/g, "_")
            var marchArr = selectorName.match(/:/g)
            var numOfArgs = marchArr ? marchArr.length : 0
            if (args.length > numOfArgs) {
                selectorName += ":"
            }
        }
        var ret = instance ? _OC_callI(instance, selectorName, args, isSuper):
        _OC_callC(clsName, selectorName, args)
        return _formatOCToJS(ret)
    }
 

    global.YES = 1
    global.NO = 0
    global.nsnull = _OC_null
    global._formatOCToJS = _formatOCToJS
})()
