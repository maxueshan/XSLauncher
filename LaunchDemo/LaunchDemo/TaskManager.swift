//
//  TaskManager.swift
//  LaunchDemo
//
//  Created by maxueshan on 2024/6/6.
//

import UIKit
import XSLauncher


class TaskManager {
  
  static func registLaunchTasks() {
    //初始化
    let taskA = TaskA(moduleName: "启动任务A", needMain: true)
    let taskB = TaskB(moduleName: "启动任务B")
    let taskC = TaskC(moduleName: "启动任务C", priority: .high)
  
    //设置任务间的依赖关系
    taskB.addDependency(taskA)
    
    //注册
    XSLaunchManager.shared().registTasksInGroup(.didLaunch, tasks: [taskA,taskB,taskC])
  }

}
