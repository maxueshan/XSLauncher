//
//  TaskA.swift
//  LaunchDemo
//
//  Created by maxueshan on 2024/6/6.
//

import UIKit
import XSLauncher

class TaskA: XSLaunchBaseTask {
  
  override func executeTask(completion: @escaping XSLaunchTaskCompletion) {
    //启动任务的代码
    sleep(1);
    //
    completion()
  }

}
