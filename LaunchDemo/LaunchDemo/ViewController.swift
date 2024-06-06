//
//  ViewController.swift
//  LaunchDemo
//
//  Created by maxueshan on 2024/6/4.
//

import UIKit
import XSLauncher

class HomeViewController: UIViewController {

  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view.
  }
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    
    XSLaunchManager.shared().executeLaunchItems(with: .freeTime)
  }
   
}

