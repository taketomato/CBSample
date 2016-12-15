//
//  PeripheralManagerServiceCharacteristicEditDiscreteValuesViewController.swift
//  BlueCap
//
//  Created by Troy Stribling on 8/20/14.
//  Copyright (c) 2014 Troy Stribling. The MIT License (MIT).
//

import UIKit
import BlueCapKit

class PeripheralManagerServiceCharacteristicEditDiscreteValuesViewController : UITableViewController {
    
    var characteristic: MutableCharacteristic!
    var peripheralManagerViewController: PeripheralManagerViewController?

    struct MainStoryboard {
        static let peripheralManagerServiceCharacteristicDiscreteValueCell  = "PeripheralManagerServiceCharacteristicEditDiscreteValueCell"
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder:aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = self.characteristic.name
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(PeripheralManagerServiceCharacteristicEditDiscreteValuesViewController.didEnterBackground), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    func didEnterBackground() {
        Logger.debug()
        if let peripheralManagerViewController = self.peripheralManagerViewController {
            _ = self.navigationController?.popToViewController(peripheralManagerViewController, animated: false)
        }
    }
    
    // UITableViewDataSource
    override func numberOfSections(in tableView:UITableView) -> Int {
        return 1
    }
    
    override func tableView(_:UITableView, numberOfRowsInSection section:Int) -> Int {
        return self.characteristic.stringValues.count
    }
    
    override func tableView(_ tableView:UITableView, cellForRowAt indexPath:IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MainStoryboard.peripheralManagerServiceCharacteristicDiscreteValueCell, for: indexPath) as UITableViewCell
        let stringValue = characteristic.stringValues[indexPath.row]
        cell.textLabel?.text = stringValue
        if let valueName = self.characteristic.stringValue?.keys.first {
            if let value = self.characteristic.stringValue?[valueName] {
                if value == stringValue {
                    cell.accessoryType = UITableViewCellAccessoryType.checkmark
                } else {
                    cell.accessoryType = UITableViewCellAccessoryType.none
                }
            }
        }
        return cell
    }
    
    // UITableViewDelegate
    override func tableView(_ tableView:UITableView, didSelectRowAt indexPath: IndexPath) {
        if let characteristic = self.characteristic {
            if let valueName = self.characteristic.stringValue?.keys.first {
                let stringValue = [valueName:characteristic.stringValues[indexPath.row]]
                do {
                    try characteristic.update(withString: stringValue)
                    _ = self.navigationController?.popViewController(animated: true)
                } catch let error {
                    present(UIAlertController.alert(error: error), animated:true) { [weak self] _ in
                        _ = self?.navigationController?.popViewController(animated: true)
                    }
                }
            }
        }
    }
    
}
