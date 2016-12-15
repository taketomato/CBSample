//
//  PeripheralManagerServiceCharacteristicEditValueViewController.swift
//  BlueCap
//
//  Created by Troy Stribling on 8/20/14.
//  Copyright (c) 2014 Troy Stribling. The MIT License (MIT).
//

import UIKit
import BlueCapKit

class PeripheralManagerServiceCharacteristicEditValueViewController: UIViewController, UITextViewDelegate {
  
    @IBOutlet var valueTextField: UITextField!
    var characteristic: MutableCharacteristic?
    var valueName: String?
    var peripheralManagerViewController: PeripheralManagerViewController?

    
    required init?(coder aDecoder:NSCoder) {
        super.init(coder:aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let valueName = self.valueName {
            self.navigationItem.title = valueName
            if let value = self.characteristic?.stringValue?[valueName] {
                self.valueTextField.text = value
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(PeripheralManagerServiceCharacteristicEditValueViewController.didEnterBackground), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }

    func didEnterBackground() {
        Logger.debug()
        if let peripheralManagerViewController = self.peripheralManagerViewController {
            _ = self.navigationController?.popToViewController(peripheralManagerViewController, animated:false)
        }
    }
    
    // UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField!) -> Bool {
        if let newValue = self.valueTextField.text,
            let valueName = self.valueName,
            let characteristic = self.characteristic  , !valueName.isEmpty {
            if var values = characteristic.stringValue {
                values[valueName] = newValue
                do {
                    try characteristic.update(withString: values)
                    _ = self.navigationController?.popViewController(animated: true)
                } catch let error {
                    present(UIAlertController.alert(error: error), animated:true) { [weak self] _ in
                        _ = self?.navigationController?.popViewController(animated: true)
                    }
                }
            }
        }
        return true
    }

}
