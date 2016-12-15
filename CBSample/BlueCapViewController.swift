import CoreBluetooth
import BlueCapKit

class BlueCapViewController: UITableViewController {
    @IBOutlet var scanButton: UIBarButtonItem!
    var peripherals: [Peripheral] = [Peripheral]()

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
        case unknown
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItems = [scanButton]
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    // MARK: - UITableViewDataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return peripherals.count
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "cellID") else { return UITableViewCell() }
        guard let label = cell.contentView.subviews.first as? UILabel else { return UITableViewCell() }
        label.text = peripherals[indexPath.row].name
        return cell
    }
    
    // MARK: - IB Action
    
    @IBAction func scanButtonTapped(_ sender: Any) {
        try! scanStart()
    }
    
    // MARK: - Internal
    
    func scanStart() throws {

        let manager = CentralManager(options: [CBCentralManagerOptionRestoreIdentifierKey : ".CBSample" as NSString])
        
        let stateChangeFuture = manager.whenStateChanges()

        let serviceUUID = CBUUID(string: TISensorTag.AccelerometerService.uuid)

        // Future オブジェクト生成 - powerOn でスキャン開始する
//        let scanFuture = stateChangeFuture.flatMap { state -> FutureStream<Peripheral> in
//            switch state {
//            case .poweredOn:
//                return manager.startScanning(forServiceUUIDs: [serviceUUID])
//            case .poweredOff:
//                throw AppError.poweredOff
//            case .unauthorized, .unsupported:
//                throw AppError.invalidState
//            case .resetting:
//                throw AppError.resetting
//            case .unknown:
//                throw AppError.unknown
//            }
//        }
        
        let scanFuture = manager.startScanning(forServiceUUIDs: nil)
        
        scanFuture.onComplete { (_) in
            print("Scan Completed")
        }

        // メモ: スキャンは開始しているようだが、成功しない
        scanFuture.onSuccess { (peripheral) in
            print(peripheral)
            if self.peripherals.count < 10 {
                self.peripherals.append(peripheral)
                self.tableView.reloadData()
            }
        }

        // 失敗した時の処理
        scanFuture.onFailure { error in
            guard let appError = error as? AppError else {
                return
            }
            switch appError {
            case .invalidState:
                break
            case .resetting:
                manager.reset()
            case .poweredOff:
                break
            case .unknown:
                break
            default:
                break
            }
        }

        // スキャン完了後の(?) Future オブジェクト生成
        let connectionFuture = scanFuture.flatMap { peripheral -> FutureStream<(peripheral: Peripheral, connectionEvent: ConnectionEvent)> in
            manager.stopScanning()
            return peripheral.connect(timeoutRetries:5, disconnectRetries:5, connectionTimeout: 10.0)
        }
        
        connectionFuture.onComplete { (_) in
//            print("Connect Completed")
        }
        
        connectionFuture.onSuccess { (peripheral, _) in
        }

        var peripheral: Peripheral?
        var dataUUID: CBUUID?
        var enabledUUID: CBUUID?
        var updatePeriodUUID: CBUUID?
        
        // 接続完了後(?)の Future オブジェクト生成 - connect ならサービス探索開始
        let discoveryFuture = connectionFuture.flatMap { (peripheral, connectionEvent) -> Future<Peripheral> in
            switch connectionEvent {
            case .connect:
                return peripheral.discoverServices([serviceUUID])
            case .timeout:
                throw AppError.disconnected
            case .disconnect:
                throw AppError.disconnected
            case .forceDisconnect:
                throw AppError.connectionFailed
            case .giveUp:
                throw AppError.connectionFailed
            }
            }.flatMap { discoveredPeripheral -> Future<Service> in
                guard let service = peripheral?.service(serviceUUID) else {
                    throw AppError.serviceNotFound
                }
                peripheral = discoveredPeripheral
                return Future<Service>()
//                return service.discover(_: [dataUUID, enabledUUID, updatePeriodUUID])
        }
        
        discoveryFuture.onComplete { (_) in
//            print("Discovery Completed")
        }
        
        // 失敗した時の処理
        discoveryFuture.onFailure { error in
            guard let appError = error as? AppError else {
                return
            }
            switch appError {
            case .serviceNotFound:
                break
            case .disconnected:
                peripheral?.reconnect()
            case .connectionFailed:
                peripheral?.terminate()
            default:
                break
            }
        }
        
        var accelerometerDataCharacteristic: Characteristic?
        var accelerometerEnabledCharacteristic: Characteristic?

        let subscriptionFuture = discoveryFuture.flatMap { service -> Future<Characteristic> in
            guard let dataCharacteristic = service.characteristic(dataUUID!) else {
                throw AppError.dataCharactertisticNotFound
            }
            accelerometerDataCharacteristic = dataCharacteristic
            return accelerometerEnabledCharacteristic!.read(timeout: 10.0)
            }.flatMap { _ -> Future<Characteristic> in
                guard let accelerometerDataCharacteristic = accelerometerDataCharacteristic else {
                    throw AppError.dataCharactertisticNotFound
                }
                return accelerometerDataCharacteristic.startNotifying()
            }.flatMap { characteristic -> FutureStream<(characteristic: Characteristic, data: Data?)> in
                return characteristic.receiveNotificationUpdates(capacity: 10)
        }
        
        subscriptionFuture.onFailure { [unowned self] error in
            guard let appError = error as? AppError else {
                return
            }
            switch appError {
            case .dataCharactertisticNotFound:
                break
            default:
                break
            }
        }
    }
}
