

import Foundation

public enum XSLaunchKey: String {
  /// 第一任务组
  case firstLevel = "kFirstLevel"
  /// 启动DidFinishLaunch执行
  case didLaunch = "kDidFinish"
  /// 启动首页渲染完执行
  case freeTime = "kFreeTime"
}

public class XSLaunchManager {
  
  private static var sharedInstance: XSLaunchManager?
  private let kAppLaunchSuccess: String = "kApplicationLaunchSuccess" // 启动真正完成 通知 key
  lazy private var taskChecker = XSTaskChecker()
  lazy private var executor = XSLaunchExecutor()
  lazy private var taskLogger = XSLaunchLogger()
  private var currentLaunchKey = XSLaunchKey.firstLevel.rawValue
  private var taskMap: [String: [XSLaunchBaseTask]] = [String: [XSLaunchBaseTask]]()
  private var events: [XSLaunchBaseTask] = [XSLaunchBaseTask]()
  private let semaphore = DispatchSemaphore.init(value: 1)
  
  
  public class func shared() -> XSLaunchManager {
    guard let sharedItem = sharedInstance else {
      sharedInstance = XSLaunchManager()
      return sharedInstance ?? XSLaunchManager()
    }
    return sharedItem
  }
  
  /*
   注册任务到对应分组
   firstLevel: 第一任务组
   kDidFinish: 启动DidFinishLaunch执行
   kFreeTime: 启动首页渲染完执行
   **/
  
  public func registTasksInGroup(_ key: XSLaunchKey, tasks: [XSLaunchBaseTask]) {
    guard !(tasks.isEmpty) else {
      return
    }
    taskMap[key.rawValue] = tasks
    #if DEBUG
    /// 检查任务唯一
    taskChecker.checkTaskIsUnique(totalTasks: taskMap)
    /// 检查启动项 无环
    taskChecker.checkStartupTasksLegal(tasks: tasks)
    #endif
  }
  /*
   执行对应分组任务
   firstLevel: 第一任务组
   kDidFinish: 启动DidFinishLaunch执行
   kFreeTime: 启动首页渲染完执行
   **/
  public func executeLaunchItems(with key: XSLaunchKey) {
    var tasks = taskMap[key.rawValue] ?? [XSLaunchBaseTask]()
    if tasks.isEmpty {
      return
    }
    let start: CFTimeInterval = CFAbsoluteTimeGetCurrent()
    currentLaunchKey = key.rawValue
    let waitTilFinish: Bool = (key == .firstLevel) || (key == .didLaunch)
    /// 每个任务组最后一个任务
    let separateTask: XSGroupSeparateTask = XSGroupSeparateTask.init(moduleName: "LaunchSepTask")
    separateTask.executeTaskBlock = { [weak self, weak separateTask] (duration: Double)  in
      let end: CFTimeInterval = CFAbsoluteTimeGetCurrent()
      self?.taskLogger.logTasksInGroup(group: key, timeCost: (end - start))
      if let identifier = separateTask?.identifier {
        self?.someTaskExecuteFinished(identifier)
      }
      
      // 最后一组任务执行完成
      //
      if key == .freeTime {
        self?.notifySubscriberLaunchSuccessFinsish()
      }
    }
    
    /// 关联单个任务的  埋点上报 logger
    for task in tasks {
      task.executeTaskBlock = { [weak self, weak task] (duration: Double)  in
        if let self = self, let identifier = task?.identifier {
          self.taskLogger.logReportTaskExecuteInfo(identifier: identifier, moduleName: task?.moduleName, duration: duration, desc: task?.desc, groupKey: self.currentLaunchKey)
          self.someTaskExecuteFinished(identifier)
        }
      }
      task.callTaskBlock = { [weak self, weak task] (duration: Double)  in
        if let identifier = task?.identifier {
          self?.taskLogger.logReportTaskCallInfo(identifier: identifier, moduleName: task?.moduleName, duration: duration, desc: task?.desc)
        }
      }
      separateTask.addDependency(task)
    }
    tasks.append(separateTask)
    appendExecuteEvents(tasks)
    executor.executeTasks(tasks: tasks, waitUntilFinish: waitTilFinish)
  }
  /// 记录正在执行的任务
  private func appendExecuteEvents(_ eventItems: [XSLaunchBaseTask]) {
    semaphore.wait()
    defer {
      semaphore.signal()
    }
    events.append(contentsOf: eventItems)
  }
  
  /// 某一个任务执行完
  private func someTaskExecuteFinished(_ identifier: String) {
    semaphore.wait()
    events.removeAll { (item) -> Bool in
      return (item.identifier == identifier)
    }
    semaphore.signal()
    if (XSLaunchKey.freeTime.rawValue == self.currentLaunchKey) && (0 == events.count){
      instanceNilOut()
    }
  }
  /// 所有任务完成 销毁
  private func instanceNilOut() {
    /* 延迟原因：此函数的调用，依赖最后一组任务的最后一个任务C的执行完成回调。回调发生时
     任务C的状态还是 executing 还没有置成finished, 此时执行当前函数开始清理会导致直接清掉执行流程还未完成的任务C
     延迟执行等每个任务的流程都执行完  ready -> finished, 再进行所有的清空操作
     */
    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
      self.taskLogger.printReportTaskDetailInfo()
      self.taskMap.removeAll()
      XSLaunchManager.sharedInstance = nil
    }
  }
  
  /// 通知观察者 启动完成
  private func notifySubscriberLaunchSuccessFinsish() {
    NotificationCenter.default.post(name: NSNotification.Name(rawValue: kAppLaunchSuccess), object: nil)
  }
  
}



