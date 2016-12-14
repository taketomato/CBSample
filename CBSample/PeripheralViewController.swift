//
//  PeripheralViewController.swift
//  CBSample
//
//  Created by tchiba on 2016/12/14.
//  Copyright © 2016年 tchiba. All rights reserved.
//

import UIKit
import CoreBluetooth

class PeripheralViewController: UITableViewController, CBPeripheralDelegate {
    
    var peripheral: CBPeripheral? = nil
    var services: [CBService] = [CBService]()

    // MARK: - Life Cycle
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        peripheral?.delegate = self
        
        // サービスの問い合わせ
        peripheral?.discoverServices(nil)
    }
    
    // MARK: - UITableViewDataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return services.count
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "cellID") else { return UITableViewCell() }
        guard let label = cell.contentView.subviews.first as? UILabel else { return UITableViewCell() }
        label.text = services[indexPath.row].uuid.uuidString
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // キャラクタリスティック(特性)を問い合わせ
        peripheral?.discoverCharacteristics(nil, for: services[indexPath.row])
    }

    // MARK: - CBPeripheralDelegate
    
    // サービスが見つかった
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let s = peripheral.services {
            services = s
            tableView.reloadData()
        }
    }
    
    // キャラクタリスティックが見つかった
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        guard let vc = sb.instantiateViewController(withIdentifier: "ServiceViewController") as? ServiceViewController else { return }
        vc.title = service.uuid.uuidString
        vc.peripheral = peripheral
        vc.service = service
        navigationController?.pushViewController(vc, animated: true)
    }
}
