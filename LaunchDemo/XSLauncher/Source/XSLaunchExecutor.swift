 

import Foundation
 
class XSLaunchExecutor {

  /// 执行一组任务
  func executeTasks(tasks: [XSLaunchBaseTask], waitUntilFinish: Bool) {
    guard !tasks.isEmpty else {
      return
    }
    guard waitUntilFinish else {
      executeTasksNoCareResult(tasks)
      return
    }
    var concurrentLists = [XSLaunchBaseTask]()
    var mainLists = [XSLaunchBaseTask]()
    
    for taskItem in tasks {
      if taskItem.needMain {
        mainLists.append(taskItem)
      } else {
        concurrentLists.append(taskItem)
      }
    }
    if !(concurrentLists.isEmpty) {
      self.asyncQueue.addOperations(concurrentLists, waitUntilFinished: false)
    }
    if !(mainLists.isEmpty) {
      executeTasksOnMainThread(tasks: mainLists)
    }
  }
  
  /// 多线程异步执行问题 不关心结果 直接放到队列
  private func executeTasksNoCareResult(_ tasks: [XSLaunchBaseTask]) {
    var mainList: [XSLaunchBaseTask] = [XSLaunchBaseTask]()
    var concurrentList: [XSLaunchBaseTask] = [XSLaunchBaseTask]()

    for task in tasks {
      if task.needMain {
        mainList.append(task)
      } else {
        concurrentList.append(task)
      }
    }
    asyncQueue.addOperations(concurrentList, waitUntilFinished: false)
    OperationQueue.main.addOperations(mainList, waitUntilFinished: false)
  }
  // 主线程任务 调度
  private func executeTasksOnMainThread(tasks: [XSLaunchBaseTask]) {
    let operation: Operation = BlockOperation.init { [weak self] in
      guard let self = self else { return }
      var exectingNumber: Int32 = 0
      /// 1. 把主线程任务 ready的都执行一遍   返回没ready的主线程任务
      var noReadyList = self.executeAllTasksSomeIsReady(tasks: tasks)
      while !(noReadyList.isEmpty) {
        let waitConcurrentFinishedTasks = self.filterItem(tasks: noReadyList) { (item) -> Bool in
          /// 依赖的子线程任务没完成
          var bgTaskUnfinished = false
          /// 依赖的主线程任务全部完成
          var mainTaskFinished = true
          
          for depItem in item.dependencies {
            guard let item = depItem as? XSLaunchBaseTask else {
              continue
            }
            if item.needMain {
              mainTaskFinished = mainTaskFinished && item.isFinished
            } else {
              bgTaskUnfinished = bgTaskUnfinished || !(item.isFinished)
            }
          }
          return bgTaskUnfinished && mainTaskFinished
        }
        ///2.  过滤出依赖的子线程任务  等子线程执行完
        for item in waitConcurrentFinishedTasks {
          guard let depenItems = item.dependencies as? [XSLaunchBaseTask] else {
            continue
          }
          let readyToExecutedBGTasks = self.filterItem(tasks: depenItems) { (depenItem) -> Bool in
            return depenItem.isReady && !(depenItem.needMain)
          }
          for item in readyToExecutedBGTasks {
            let start: CFTimeInterval = CFAbsoluteTimeGetCurrent()
            print("[XS launch] start wait salve task : \(item.identifier ?? "")")
            item.waitUntilFinished()
            let end: CFTimeInterval = CFAbsoluteTimeGetCurrent()
            #if DEBUG
            print("[XS launch] Main Wait cost ============= : \(end - start)")
            #else
            print("[XS launch] Main Wait cost ============= : \(end - start)")
            #endif
          }
          /// 3. 主线程任务再执行一遍
          noReadyList = self.executeAllTasksSomeIsReady(tasks: noReadyList)
          self.printTaskStatus(item)
        }
        noReadyList = self.executeAllTasksSomeIsReady(tasks: tasks)
        exectingNumber = exectingNumber + 1
        /// 超过最大执行次数 这里要是出现循环 超过最大次数 打印当前主线程任务执行状态
        if (exectingNumber > 600) && !(noReadyList.isEmpty) {
          print("[XS launch] Task Execute progress over max loop ")
          for task in noReadyList {
            self.printTaskStatus(task)
          }
          #if DEBUG
          assertionFailure("[XS launch] Task Executing in Loop")
          #else
          print("[XS launch] Task Executing in Loop")
          self.finalCheckAllTasksBeExecuted(noReadyList)
          #endif
        }
      }
      /// 该组任务执行完时 再次检查是否有未执行的任务
      self.finalCheckAllTasksBeExecuted(tasks)
    }
    Thread.isMainThread ? operation.main() : OperationQueue.main.addOperation(operation)
  }
  
  /**
   方法执行结果检查，正常不应该走到这里
    没有执行完成 且没开始执行的任务
   */
  private func finalCheckAllTasksBeExecuted(_ tasks: [XSLaunchBaseTask]) {
    guard !(tasks.isEmpty) else {
      return
    }
    print("[XS launch] finanl check all unfinished save launch progress")
    let noFinishList = filterItem(tasks: tasks) { (task) -> Bool in
      return !(task.isFinished)
    }
    var indentifierGroup = ""
    /// 拼接未完成id
    for task in noFinishList {
      if let identifier = task.identifier {
        indentifierGroup.append(identifier + "|")
      }
      task.start()
      self.printTaskStatus(task)
    }
    if !(indentifierGroup.isEmpty) {
      print("[XS launch] find Unfinish Task" + indentifierGroup)
      #if DEBUG
      assertionFailure("[XS launch] find Unfinish Task" + indentifierGroup)
      #endif
    }
  }
  
  /// execute ready task，return  no ready task
  private func executeAllTasksSomeIsReady(tasks: [XSLaunchBaseTask]) -> [XSLaunchBaseTask] {
    var readyList = collectReadyUnfinishTask(totalTasks: tasks)
    readyList.sort { (item1, item2) -> Bool in
      return item1.priority.rawValue > item2.priority.rawValue
    }
    
    while !(readyList.isEmpty) {
      for task in readyList {
        task.start()
      }
      readyList = collectReadyUnfinishTask(totalTasks: tasks)
    }
    return filterItem(tasks: tasks) { (task) -> Bool in
      return !(task.isReady)
    }
  }
  /// 过滤收集 准备好未完成的任务
  private func collectReadyUnfinishTask(totalTasks: [XSLaunchBaseTask]) -> [XSLaunchBaseTask]  {
    return filterItem(tasks: totalTasks) { (task) -> Bool in
      return task.isReady && !(task.isFinished) && !(task.isExecuting)
    }
  }
  /// 过滤出符合条件的集合
  private func filterItem(tasks: [XSLaunchBaseTask], filterBlock: ((XSLaunchBaseTask) -> Bool)) -> [XSLaunchBaseTask] {
    var result: [XSLaunchBaseTask] = [XSLaunchBaseTask]()
    if tasks.isEmpty {
      return result
    }
    for task in tasks {
      let kept = filterBlock(task)
      if kept {
        result.append(task)
      }
    }
    return result
  }
  
  private func printTaskStatus(_ task: XSLaunchBaseTask) {
    #if DEBUG
    print("[XS launch] Task Status:" + task.description)
    #else
    print("[XS launch] Task Status:" + task.description)
    #endif
  }
  
  private lazy var asyncQueue: OperationQueue = {
    let ret = OperationQueue.init()
    ret.maxConcurrentOperationCount = (ProcessInfo.processInfo.activeProcessorCount - 1)
    ret.qualityOfService = .userInitiated
    ret.name = "com.XS.launch.asyncQueue"
    return ret
  }()
  
}
