 

import Foundation

class XSTaskChecker {
  
  private let kTASK_NOT_SEARCHED: Int8 = 0
  private let kTASK_HAS_SEARCHED: Int8 = -1
  private let kTASK_SEARCHED_ALL: Int8 = 1

  /// 合法性检查 检查无依赖环
  func checkStartupTasksLegal(tasks: [XSLaunchBaseTask]) {
    let taskMap: NSMapTable = NSMapTable<AnyObject, NSNumber>.weakToWeakObjects()
    for model in tasks {
      taskMap.setObject(NSNumber.init(value: kTASK_NOT_SEARCHED), forKey: model)
    }
    for model in tasks {
      dfsForItem(model, map: taskMap)
    }
  }
  /// 对所有任务 合法性检查 检查注册的任务 只被注册过一次
  func checkTaskIsUnique(totalTasks: [String: [XSLaunchBaseTask]]) {
    var itemSet: Set<String> = Set<String>()
    for (_, tasks) in totalTasks {
      for item in tasks {
        let setCount = itemSet.count
        let identifier = item.identifier ?? String(describing: type(of: item))
        itemSet.insert(identifier)
        if setCount == itemSet.count {
          assertionFailure("[XS Start] 任务:" + identifier + "被多次注册或命名冲突")
        }
      }
    }
  }
  /// 检查 依赖项 有向无环 深度优先  递归
  private func dfsForItem(_ item: XSLaunchBaseTask, map: NSMapTable<AnyObject, NSNumber>) {
    let itemStatus: Int8 = map.object(forKey: item)?.int8Value ?? kTASK_NOT_SEARCHED
    if kTASK_SEARCHED_ALL == itemStatus { // 判断缓存结果 防止多次重复
      return
    }
    map.setObject(NSNumber.init(value: kTASK_HAS_SEARCHED), forKey: item)
    guard let depItems = item.dependencies as? [XSLaunchBaseTask], !(depItems.isEmpty) else {
      map.setObject(NSNumber.init(value: kTASK_SEARCHED_ALL), forKey: item)
      return
    }
    for depItem in depItems {
      let status: Int8 = map.object(forKey: depItem)?.int8Value ?? kTASK_NOT_SEARCHED
      if kTASK_NOT_SEARCHED == status {
        dfsForItem(depItem, map: map)
      } else if kTASK_HAS_SEARCHED == status {
        let identifier = item.identifier ?? String(describing: type(of: depItem))
        assertionFailure("[XS Start] 出现依赖环，请检查" + identifier + "的依赖")
      }
    }
    map.setObject( NSNumber.init(value: kTASK_SEARCHED_ALL), forKey: item)
  }
}
