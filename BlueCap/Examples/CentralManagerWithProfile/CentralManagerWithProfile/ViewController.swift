//
//  ViewController.swift
//  Beacon
//
//  Created by Troy Stribling on 4/13/15.
//  Copyright (c) 2015 Troy Stribling. The MIT License (MIT).
//

import UIKit
import CoreBluetooth
import BlueCapKit

public enum AppError : Error {
    case dataCharactertisticNotFound
    case enabledCharactertisticNotFound
    case updateCharactertisticNotFound
    case serviceNotFound
    case disconnected
    case connectionFailed
    case invalidState
    case resetting
    case poweredOff
    case unkown
}

class ViewController: UITableViewController {
    
    struct MainStoryboard {
        static let updatePeriodValueSegue = "UpdatePeriodValue"
        static let updatePeriodRawValueSegue = "UpdatePeriodRawValue"
    }

    @IBOutlet var xAccelerationLabel: UILabel!
    @IBOutlet var yAccelerationLabel: UILabel!
    @IBOutlet var zAccelerationLabel: UILabel!
    @IBOutlet var xRawAccelerationLabel: UILabel!
    @IBOutlet var yRawAccelerationLabel: UILabel!
    @IBOutlet var zRawAccelerationLabel: UILabel!
    
    @IBOutlet var rawUpdatePeriodlabel: UILabel!
    @IBOutlet var updatePeriodLabel: UILabel!
    
    @IBOutlet var activateSwitch: UISwitch!
    @IBOutlet var enabledSwitch: UISwitch!
    @IBOutlet var enabledLabel: UILabel!
    @IBOutlet var statusLabel: UILabel!
    
    var peripheral: Peripheral?
    var accelerometerDataCharacteristic: Characteristic?
    var accelerometerEnabledCharacteristic: Characteristic?
    var accelerometerUpdatePeriodCharacteristic: Characteristic?

    let profileManager = ProfileManager()
    let manager: CentralManager

    required init?(coder aDecoder: NSCoder) {
        TISensorTagServiceProfiles.create(profileManager: profileManager)
        manager = CentralManager(profileManager: profileManager, options: [CBCentralManagerOptionRestoreIdentifierKey : "us.gnos.BlueCap.central-manager-with_profile-example" as NSString])
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.updateUIStatus()
        self.readUpdatePeriod()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == MainStoryboard.updatePeriodValueSegue {
            let viewController = segue.destination as! SetUpdatePeriodViewController
            viewController.characteristic = self.accelerometerUpdatePeriodCharacteristic
            viewController.isRaw = false
        } else if segue.identifier == MainStoryboard.updatePeriodRawValueSegue {
            let viewController = segue.destination as! SetUpdatePeriodViewController
            viewController.characteristic = self.accelerometerUpdatePeriodCharacteristic
            viewController.isRaw = true
        }
        
    }
    
    @IBAction func toggleEnabled(_ sender: AnyObject) {
        if let peripheral = self.peripheral, peripheral.state == .connected {
            self.writeEnabled()
        }
    }
    
    @IBAction func toggleActivate(_ sender: AnyObject) {
        if self.activateSwitch.isOn  {
            self.activate()
        } else {
            self.deactivate()
        }
    }
    
    @IBAction func disconnect(_ sender: AnyObject) {
        if let peripheral = self.peripheral, peripheral.state != .disconnected {
            peripheral.disconnect()
        }
    }

    func activate() {
        let serviceUUID = CBUUID(string: TISensorTag.AccelerometerService.uuid)
        let dataUUID = CBUUID(string: TISensorTag.AccelerometerService.Data.uuid)
        let enabledUUID = CBUUID(string: TISensorTag.AccelerometerService.Enabled.uuid)
        let updatePeriodUUID = CBUUID(string: TISensorTag.AccelerometerService.UpdatePeriod.uuid)
        
        // on power, start scanning. when peripheral is discovered connect and stop scanning
        let dataUpdateFuture = self.manager.whenStateChanges().flatMap { [unowned self] state -> FutureStream<Peripheral> in
            switch state {
            case .poweredOn:
                self.activateSwitch.isOn = true
                return self.manager.startScanning(forServiceUUIDs: [serviceUUID], capacity: 10)
            case .poweredOff:
                throw AppError.poweredOff
            case .unauthorized, .unsupported:
                throw AppError.invalidState
            case .resetting:
                throw AppError.resetting
            case .unknown:
                throw AppError.unkown
            }
            }.flatMap { [unowned self] peripheral -> FutureStream<(peripheral: Peripheral, connectionEvent: ConnectionEvent)> in
                self.manager.stopScanning()
                self.peripheral = peripheral
                return peripheral.connect(timeoutRetries:5, disconnectRetries:5, connectionTimeout: 10.0)
            }.flatMap { [unowned self] (peripheral, connectionEvent) -> Future<Peripheral> in
                switch connectionEvent {
                case .connect:
                    self.updateUIStatus()
                    return peripheral.discoverServices([serviceUUID])
                case .timeout:
                    throw AppError.disconnected
                case .disconnect:
                    throw AppError.disconnected
                case .forceDisconnect:
                    self.updateUIStatus()
                    throw AppError.connectionFailed
                case .giveUp:
                    throw AppError.connectionFailed
                }
            }.flatMap { peripheral -> Future<Service> in
                guard let service = peripheral.service(serviceUUID) else {
                    throw AppError.serviceNotFound
                }
                return service.discoverCharacteristics([dataUUID, enabledUUID, updatePeriodUUID])
            }.flatMap { [unowned self] service -> Future<Characteristic> in
                guard let dataCharacteristic = service.characteristic(dataUUID) else {
                    throw AppError.dataCharactertisticNotFound
                }
                guard let enabledCharacteristic = service.characteristic(enabledUUID) else {
                    throw AppError.enabledCharactertisticNotFound
                }
                guard let updatePeriodCharacteristic = service.characteristic(updatePeriodUUID) else {
                    throw AppError.updateCharactertisticNotFound
                }
                self.accelerometerDataCharacteristic = dataCharacteristic
                self.accelerometerEnabledCharacteristic = enabledCharacteristic
                self.accelerometerUpdatePeriodCharacteristic = updatePeriodCharacteristic
                return enabledCharacteristic.write(TISensorTag.AccelerometerService.Enabled.yes)
            }.flatMap { [unowned self] _ -> Future<[Characteristic]> in
                return [self.accelerometerEnabledCharacteristic,
                        self.accelerometerUpdatePeriodCharacteristic,
                        self.accelerometerDataCharacteristic].flatMap { $0 }.map { $0.read(timeout: 10.0) }.sequence()
            }.flatMap { [unowned self] _ -> Future<Characteristic> in
                guard let accelerometerDataCharacteristic = self.accelerometerDataCharacteristic else {
                    throw AppError.dataCharactertisticNotFound
                }
                self.updateEnabled()
                self.updatePeriod()
                return accelerometerDataCharacteristic.startNotifying()
            }.flatMap { characteristic -> FutureStream<(characteristic: Characteristic, data: Data?)> in
                return characteristic.receiveNotificationUpdates(capacity: 10)
        }
        
        dataUpdateFuture.onFailure { [unowned self] error in
            guard let appError = error as? AppError else {
                self.present(UIAlertController.alertOnError(error), animated:true, completion:nil)
                return
            }
            switch appError {
            case .dataCharactertisticNotFound:
                fallthrough
            case .enabledCharactertisticNotFound:
                fallthrough
            case .updateCharactertisticNotFound:
                fallthrough
            case .serviceNotFound:
                self.present(UIAlertController.alertOnError(error), animated:true, completion:nil)
            case .disconnected:
                self.peripheral?.reconnect()
            case .connectionFailed:
                self.peripheral?.terminate()
                self.present(UIAlertController.alertWithMessage("Connection failed"), animated: true, completion: nil)
            case .invalidState:
                self.present(UIAlertController.alertWithMessage("Invalid state"), animated: true, completion: nil)
            case .resetting:
                self.manager.reset()
                self.present(UIAlertController.alertWithMessage("Bluetooth service resetting"), animated: true, completion: nil)
            case .poweredOff:
                self.present(UIAlertController.alertWithMessage("Bluetooth powered off"), animated: true, completion: nil)
            case .unkown:
                break
            }
            self.peripheral = nil
            self.updateUIStatus()
        }
        
        dataUpdateFuture.onSuccess { [unowned self] (_, data) in
            self.updateData(data)
        }
        
    }
    
    func updateUIStatus() {
        if let peripheral = self.peripheral {
            switch peripheral.state {
            case .connected:
                statusLabel.text = "Connected"
                statusLabel.textColor = UIColor(red:0.2, green:0.7, blue:0.2, alpha:1.0)
            case .connecting:
                statusLabel.text = "Connecting"
                statusLabel.textColor = UIColor(red:0.9, green:0.7, blue:0.0, alpha:1.0)
            case .disconnected:
                statusLabel.text = "Disconnected"
                statusLabel.textColor = UIColor.lightGray
            case .disconnecting:
                statusLabel.text = "Disconnecting"
                statusLabel.textColor = UIColor.lightGray
            }
            if peripheral.state == .connected {
                enabledLabel.textColor = UIColor.black
                enabledSwitch.isEnabled = true
            } else {
                enabledLabel.textColor = UIColor.lightGray
                enabledSwitch.isEnabled = false
                enabledSwitch.isOn = false
            }
        } else {
            statusLabel.text = "Disconnected"
            statusLabel.textColor = UIColor.lightGray
            enabledLabel.textColor = UIColor.lightGray
            enabledSwitch.isOn = false
            enabledSwitch.isEnabled = false
            activateSwitch.isOn = false
        }
    }
    
    func updateEnabled() {
        guard let accelerometerEnabledCharacteristic = accelerometerEnabledCharacteristic,
              let data = accelerometerEnabledCharacteristic.stringValue,
              let value = data.values.first else {
            return
        }
        enabledSwitch.isOn = value == "Yes"
    }
    
    func updatePeriod() {
        guard let accelerometerUpdatePeriodCharacteristic = accelerometerUpdatePeriodCharacteristic,
            let data = accelerometerUpdatePeriodCharacteristic.stringValue,
            let period = data["period"], let rawPeriod = data["periodRaw"] else {
            return
        }
        updatePeriodLabel.text = period
        rawUpdatePeriodlabel.text = rawPeriod
    }
    
    func readUpdatePeriod() {
        guard let accelerometerUpdatePeriodCharacteristic = self.accelerometerUpdatePeriodCharacteristic else {
            return
        }
        let readFuture = accelerometerUpdatePeriodCharacteristic.read(timeout: 10.0)
        
        readFuture.onSuccess { [unowned self] _ in
            self.updatePeriod()
        }
        readFuture.onFailure{ [unowned self] error in
            self.present(UIAlertController.alertOnError(error), animated:true, completion:nil)
        }
    }
    
    func updateData(_ data: Data?) {
        guard let data = data, let stringData = self.accelerometerDataCharacteristic?.stringValue(data),
              let x = stringData["x"], let y = stringData["y"], let z = stringData["z"],
              let xRaw = stringData["xRaw"], let yRaw = stringData["yRaw"], let zRaw = stringData["zRaw"] else {
                    return
        }
        xAccelerationLabel.text = x
        yAccelerationLabel.text = y
        zAccelerationLabel.text = z
        xRawAccelerationLabel.text = xRaw
        yRawAccelerationLabel.text = yRaw
        zRawAccelerationLabel.text = zRaw
    }
    
    func writeEnabled() {
        guard let accelerometerEnabledCharacteristic = accelerometerEnabledCharacteristic else {
            return
        }
        let value = TISensorTag.AccelerometerService.Enabled(boolValue: enabledSwitch.isOn)
        let writeFuture = accelerometerEnabledCharacteristic.write(value, timeout:10.0)
        writeFuture.onSuccess { [unowned self] _ in
            self.present(UIAlertController.alertWithMessage("Accelerometer is " + (self.enabledSwitch.isOn ? "on" : "off")), animated:true, completion:nil)
        }
        writeFuture.onFailure { [unowned self] error in
            self.present(UIAlertController.alertOnError(error), animated:true, completion:nil)
        }
    }
    
    func deactivate() {
        guard let peripheral = peripheral else {
            return
        }
        peripheral.terminate()
        self.peripheral = nil
        updateUIStatus()
    }

}
