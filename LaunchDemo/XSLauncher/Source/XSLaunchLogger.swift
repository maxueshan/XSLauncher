

import Foundation
 

class XSLaunchLogger {
  
  var exectTaskLogList: [String] = [String]()
  var totalLaunchCallTime: CFTimeInterval = 0.0
  var totalLaunchExecuteTime: CFTimeInterval = 0.0

  private let logListSemaphore = DispatchSemaphore.init(value: 1)
  private let logTotalSemaphore = DispatchSemaphore.init(value: 1)
  
  private lazy var launchTimeDict: [String: [String: String]] = {
    let timeDict:  [String: [String: String]] = [String: [String: String]]()
    return timeDict
  }()
  
  /// 记录上报单个任务耗时
  func logReportTaskExecuteInfo(identifier: String, moduleName: String?, duration: Double, desc: String?, groupKey: String) {
    let logString = "moduleName:\(String(describing: moduleName)), duration:\(duration)"
    let timeCost: TimeInterval = duration * 1000
  
    logListSemaphore.wait()
    totalLaunchExecuteTime = totalLaunchExecuteTime + timeCost
    exectTaskLogList.append(logString)
    #if !DEBUG
    launchTimeDict[(identifier + "Cost")] = ["cost": "\(timeCost)", "group": groupKey]
    #endif
    logListSemaphore.signal()
  }
  
  /// 记录任务的调用耗时
  func logReportTaskCallInfo(identifier: String, moduleName: String?, duration: Double, desc: String?) {
    logTotalSemaphore.wait()
    defer {
      logTotalSemaphore.signal()
    }
    totalLaunchCallTime = totalLaunchCallTime + (duration * 1000)
  }
  
  /// 启动完成 打印任务信息并埋点上报
  func printReportTaskDetailInfo() {
    printTaskInvokeInfo() // 打印调用信息
    printTaskExecutedInfo() // 打印执行信息
    commitLaunchDetails() // 埋点上报
  }
  
  /// 记录一组任务耗时
  func logTasksInGroup(group: XSLaunchKey, timeCost: Double) {
    if timeCost < 0 {
      return
    }
    let time = timeCost * 1000
    print("[XS Launch] Group: " + group.rawValue + "| cost : \(time)")
    
    #if !DEBUG
    var key: String = "KFirstLevel"
    switch group {
      case .didLaunch:
        key = "KLaunchDidFinish"
      case .freeTime:
        key = "KLaunchDidAppear"
      case .firstLevel:
        key = "KFirstLevel"
    }
    logListSemaphore.wait()
    launchTimeDict[key] = ["cost": "\(time)"]
    logListSemaphore.signal()
    #endif
  }
}


extension XSLaunchLogger {   // Private
  /// 上报埋点
  private func commitLaunchDetails() {
    #if !DEBUG
    logListSemaphore.wait()
    for (key, value) in launchTimeDict {
      //耗时上报
    }
    logListSemaphore.signal()
    #endif
  }
  
  /// 打印任务调用信息
  private func printTaskInvokeInfo() {
    print("[XS Launch] Total Launch time = <Call: \(totalLaunchCallTime) | Execute: \(totalLaunchExecuteTime)>")
  }
  
  /// 打印任务执行信息
  private func printTaskExecutedInfo() {
    logListSemaphore.wait()
    print("================ Launch Info Start ==================\n")
    for log in exectTaskLogList {
      print("[XS Launch] Item: " + log + "\n")
    }
    print("================ Launch Info End ==================\n")
    logListSemaphore.signal()
  }

  
}
