//
//  PeripheralViewController.swift
//  CBSample
//
//  Created by tchiba on 2016/12/14.
//  Copyright © 2016年 tchiba. All rights reserved.
//

import UIKit
import CoreBluetooth

class ServiceViewController: UITableViewController, CBPeripheralDelegate {

    var peripheral: CBPeripheral? = nil
    var service: CBService? = nil
    var characteristics: [CBCharacteristic] = [CBCharacteristic]()
    
    // MARK: - Life Cycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        peripheral?.delegate = self
        guard let c = service?.characteristics else { return }
        characteristics = c
    }
    
    // MARK: - UITableViewDataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return characteristics.count
    }

    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "cellID") else { return UITableViewCell() }
        guard let uuidLabel = cell.contentView.subviews.first as? UILabel else { return UITableViewCell() }
        guard let valueLabel = cell.contentView.subviews.last as? UILabel else { return UITableViewCell() }
        uuidLabel.text = characteristics[indexPath.row].uuid.uuidString
        valueLabel.text = characteristics[indexPath.row].value?.description
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // キャラクタリスティックの値を読みにいく
        peripheral?.readValue(for: characteristics[indexPath.row])
    }
    
    // MARK: - CBPeripheralDelegate
    
    // 値読み取りに成功した
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        for var c in characteristics {
            if c.uuid == characteristic.uuid {
                c = characteristic
                tableView.reloadData()
                return
            }
        }
    }
}
