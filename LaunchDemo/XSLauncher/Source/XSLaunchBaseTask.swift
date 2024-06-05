


import Foundation
 
/// 任务优先级
public enum XSLaunchTaskPriority: Int32 {
  case veryHigh = 1000
  case high = 500
  case normal = 100
  case low = 75
  case veryLow = 0
}
/// 任务执行回调
public typealias XSLaunchTaskCompletion = () -> Void

open class XSLaunchBaseTask: Operation {
  
  enum State {
    case initialized
    case executing
    case finished
  }
  /// 唯一标记
  var identifier: String?
  /// 模块名称
  var moduleName: String
  /// 描述
  var desc: String?
  /// 是否需要主线程
  var needMain: Bool = true
  /// 任务优先级
  var priority: XSLaunchTaskPriority = .normal
  /// 任务执行的时间
  var executeTaskBlock: ((_ duration: Double) -> Void)?
  /// 任务调用时间
  var callTaskBlock: ((_ duration: Double) -> Void)?
  
  private var _lock = pthread_rwlock_t()
  
  deinit {
    let status = pthread_rwlock_destroy(&_lock)
    assert(status == 0)
  }

  /// identifier: 唯一ID moduleName: 模块名， needMain: 需要主线程， desc: 任务描述，priority：任务优先级
  public init(identifier: String? = nil, moduleName: String, needMain: Bool? = true, desc : String? = nil, priority: XSLaunchTaskPriority? = .normal) {
    self.identifier = identifier
    if identifier == nil {
      self.identifier = String(describing: type(of: self))
    }
    self.desc = desc
    self.moduleName = moduleName
    self.needMain = needMain ?? true
    self.priority = priority ?? .normal
    super.init()
    setOperationPriority(priority ?? .normal)
    pthread_rwlock_init(&_lock, nil)
  }
  
  /// 设置系统优先级
  private func setOperationPriority(_ priority: XSLaunchTaskPriority) {
    switch priority {
      case .veryHigh:
        self.queuePriority = .veryHigh
      case .high:
        self.queuePriority = .high
      case .normal:
        self.queuePriority = .normal
      case .low:
        self.queuePriority = .low
      case .veryLow:
        self.queuePriority = .veryLow
    }
  }
  /// 当前线程
  private func currentThreadName() -> String {
    if Thread.current.isMainThread {
      return "main"
    } else {
      let pid = pthread_mach_thread_np(pthread_self())
      return "Thread - \(pid)"
    }
  }
  
  public override func start() {
    lockForWriting()
    state = .executing
    unlock()
    print("[XS Launch] Task: \(identifier ?? "") State Change To executing")
    if isCancelled {
        self.taskFinished()
      return
    }
    finalExecutTask()
  }
  /// 真正执行任务
  private func finalExecutTask() {
    print("[XS Launch] Task: \(identifier ?? "") Start To Execute")
    let start: CFTimeInterval = CFAbsoluteTimeGetCurrent()
    executeTask { [weak self] in
      guard let self = self else { return }
      let cost: CFTimeInterval = CFAbsoluteTimeGetCurrent() - start
      if let logBlock = self.executeTaskBlock {
        logBlock(cost)
        #if DEBUG
        print("[XS Launch12] \(self.identifier ?? "") be executed | cost \(cost * 1000)")
        #else
        print("[XS Launch] \(self.identifier ?? "") be executed | cost \(cost * 1000)")
        #endif
      }
    }
 
    self.taskFinished()
    
    let end = CFAbsoluteTimeGetCurrent()
    if let logBlock = self.callTaskBlock {
      logBlock(end - start)
    }
  }

  open func executeTask(completion: @escaping XSLaunchTaskCompletion) {
    fatalError("[XS launch] Abstract symbol, override by concrete class")
  }

  private func taskFinished() {
    lockForWriting()
    state = .finished
    unlock()
    print("[XS Launch] Task: \(identifier ?? "") State Change To finished")
  }
  
  public override class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
    if (["isExecuting", "isFinished"].contains(key)) {
      return ["state"]
    }
    return super.keyPathsForValuesAffectingValue(forKey: key)
  }
  
  var state: State = .initialized {
    willSet {
      willChangeValue(forKey: "state")
    }
    didSet {
      didChangeValue(forKey: "state")
    }
  }
  
  public override var isExecuting: Bool {
    lockForReading()
    defer {
      unlock()
    }
    return state == .executing
  }
  
  public override var isFinished: Bool {
    lockForReading()
    defer {
      unlock()
    }
    return state == .finished
  }
  
  private func lockForReading() {
    pthread_rwlock_rdlock(&_lock)
  }
  
  private func lockForWriting() {
    pthread_rwlock_wrlock(&_lock)
  }
  
  private func unlock() {
    pthread_rwlock_unlock(&_lock)
  }

  open override var description: String {
    return "< Task: \(self.identifier ?? ""), isExecuting: \(isExecuting), isReady: \(isReady), isFinished: \(isFinished)> "
  }
}
