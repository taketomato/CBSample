//
//  ViewController.swift
//  CBSample
//
//  Created by tchiba on 2016/12/14.
//  Copyright © 2016年 tchiba. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController: UITableViewController, CBCentralManagerDelegate {
    
    var centralManager: CBCentralManager? = nil
    var peripherals: [CBPeripheral] = [CBPeripheral]()

    @IBOutlet var scanButtonItem: UIBarButtonItem!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItems = [scanButtonItem]

        // マネージャ生成
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        centralManager?.stopScan()
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return peripherals.count
    }
    
    // MAKR: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "cellID") else { return UITableViewCell() }
        guard let label = cell.contentView.subviews.first as? UILabel else { return UITableViewCell() }
        label.text = peripherals[indexPath.row].name ?? "no name"
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // ペリフェラルに接続しにいく
        centralManager?.connect(peripherals[indexPath.row], options: nil)
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
    }
    
    // ペリフェラルが見つかった
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print(peripheral)
        if peripherals.count < 10 {
            peripherals.append(peripheral)
            tableView.reloadData()
        }
    }

    // 接続に成功した
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        guard let vc = sb.instantiateViewController(withIdentifier: "PeripheralViewController") as? PeripheralViewController else { return }
        vc.title = peripheral.name
        vc.peripheral = peripheral
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - IB Action

    @IBAction func scanButtonTapped(_ sender: Any) {
        peripherals.removeAll()
        // ペリフェラルをスキャンする
        centralManager?.scanForPeripherals(withServices: nil, options: nil)
    }
}

