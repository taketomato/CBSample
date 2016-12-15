//
//  BeaconRegionsViewController.swift
//  BlueCap
//
//  Created by Troy Stribling on 9/16/14.
//  Copyright (c) 2014 Troy Stribling. The MIT License (MIT).
//

import UIKit
import BlueCapKit

class BeaconRegionsViewController: UITableViewController {

    var stopScanBarButtonItem: UIBarButtonItem!
    var startScanBarButtonItem: UIBarButtonItem!
    var beaconRegions = [String: BeaconRegion]()

    struct MainStoryBoard {
        static let beaconRegionCell = "BeaconRegionCell"
        static let beaconsSegue = "Beacons"
        static let beaconRegionAddSegue = "BeaconRegionAdd"
        static let beaconRegionEditSegue = "BeaconRegionEdit"
    }
    
    required init?(coder aDecoder:NSCoder) {
        super.init(coder:aDecoder)
        self.stopScanBarButtonItem = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(BeaconRegionsViewController.toggleMonitoring(_:)))
        self.startScanBarButtonItem = UIBarButtonItem(title: "Scan", style: UIBarButtonItemStyle.plain, target: self, action: #selector(BeaconRegionsViewController.toggleMonitoring(_:)))
        self.styleUIBarButton(self.startScanBarButtonItem)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.styleNavigationBar()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.reloadData()
        self.navigationItem.title = "Beacon Regions"
        self.setScanButton()
        NotificationCenter.default.addObserver(self, selector: #selector(BeaconRegionsViewController.didBecomeActive), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
        self.navigationItem.title = ""
    }
    
    
    override func prepare(for segue:UIStoryboardSegue, sender:Any!) {
        if segue.identifier == MainStoryBoard.beaconsSegue {
            let selectedIndexPath = sender as! IndexPath
            let beaconsViewController = segue.destination as! BeaconsViewController
            let beaconName = BeaconStore.getBeaconNames()[(selectedIndexPath as NSIndexPath).row]
            if let beaconRegion = self.beaconRegions[beaconName] {
                beaconsViewController.beaconRegion = beaconRegion
            }
        } else if segue.identifier == MainStoryBoard.beaconRegionAddSegue {
        } else if segue.identifier == MainStoryBoard.beaconRegionEditSegue {
            let selectedIndexPath = sender as! IndexPath
            let viewController = segue.destination as! BeaconRegionViewController
            viewController.regionName = BeaconStore.getBeaconNames()[(selectedIndexPath as NSIndexPath).row]
        }
    }
    
    func toggleMonitoring(_ sender:AnyObject) {
        if !Singletons.scanningManager.isScanning {
            if Singletons.beaconManager.isMonitoring {
                Singletons.beaconManager.stopRangingAllBeacons()
                Singletons.beaconManager.stopMonitoringAllRegions()
                self.beaconRegions.removeAll(keepingCapacity: false)
                self.setScanButton()
            } else {
                self.startMonitoring()
            }
            self.tableView.reloadData()
        } else {
            self.present(UIAlertController.alert(message: "Central scan is active. Cannot scan and monitor simutaneously. Stop scan to start monitoring"), animated: true, completion: nil)
        }
    }
    
    func setScanButton() {
        if Singletons.beaconManager.isRanging {
            self.navigationItem.setLeftBarButton(self.stopScanBarButtonItem, animated: false)
        } else {
            self.navigationItem.setLeftBarButton(self.startScanBarButtonItem, animated: false)
        }
    }
    
    func startMonitoring() {
        for (name, uuid) in BeaconStore.getBeacons() {
            let beacon = BeaconRegion(proximityUUID: uuid, identifier: name)
            let regionFuture = Singletons.beaconManager.startMonitoring(for: beacon, authorization: .authorizedAlways)
            let beaconFuture = regionFuture.flatMap { [weak self] status -> FutureStream<[Beacon]> in
                guard let strongSelf = self else {
                    throw AppError.invalid
                }
                switch status {
                case .inside:
                    guard !Singletons.beaconManager.isRangingRegion(identifier: beacon.identifier) else {
                        throw AppError.rangingBeacons
                    }
                    strongSelf.updateDisplay()
                    Notification.send("Entering region '\(name)'. Started ranging beacons.")
                    return Singletons.beaconManager.startRangingBeacons(in: beacon)
                case .outside:
                    Singletons.beaconManager.stopRangingBeacons(in: beacon)
                    strongSelf.updateWhenActive()
                    Notification.send("Exited region '\(name)'. Stoped ranging beacons.")
                    throw AppError.outOfRegion
                case .start:
                    Logger.debug("started monitoring region \(name)")
                    strongSelf.navigationItem.setLeftBarButton(strongSelf.stopScanBarButtonItem, animated: false)
                    return Singletons.beaconManager.startRangingBeacons(in: beacon)
                case .unknown:
                    throw AppError.unknownRegionStatus
                    
                }
            }
            beaconFuture.onSuccess { [weak self] beacons in
                self.forEach { strongSelf in
                    strongSelf.setScanButton()
                    for beacon in beacons {
                        Logger.debug("major:\(beacon.major), minor: \(beacon.minor), rssi: \(beacon.rssi)")
                    }
                    strongSelf.updateWhenActive()
                    if UIApplication.shared.applicationState == .active && beacons.count > 0 {
                        NotificationCenter.default.post(name: NSNotification.Name(rawValue: BlueCapNotification.didUpdateBeacon), object:beacon)
                    }
                }
            }
            regionFuture.onFailure { [weak self] error in
                self.forEach { strongSelf in
                    strongSelf.setScanButton()
                    Singletons.beaconManager.stopRangingBeacons(in: beacon)
                    strongSelf.updateWhenActive()
                    guard error is AppError else {
                        return
                    }
                    strongSelf.present(UIAlertController.alert(title: "Region Monitoring Error", error:error), animated:true, completion:nil)
                }
            }
            self.beaconRegions[name] = beacon
        }
    }
    
    func updateDisplay() {
        if UIApplication.shared.applicationState == .active {
            self.tableView.reloadData()
        }
    }

    func didBecomeActive() {
        Logger.debug()
        self.updateWhenActive()
    }

    // UITableViewDataSource
    override func numberOfSections(in tableView:UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return BeaconStore.getBeacons().count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MainStoryBoard.beaconRegionCell, for: indexPath) as! BeaconRegionCell
        let name = BeaconStore.getBeaconNames()[(indexPath as NSIndexPath).row]
        let beaconRegions = BeaconStore.getBeacons()
        if let beaconRegionUUID = beaconRegions[name] {
            cell.nameLabel.text = name
            cell.uuidLabel.text = beaconRegionUUID.uuidString
        }
        cell.nameLabel.textColor = UIColor.black
        cell.beaconsLabel.text = "0"
        cell.nameLabel.textColor = UIColor.lightGray
        cell.statusLabel.textColor = UIColor.lightGray
        if Singletons.beaconManager.isRangingRegion(identifier: name) {
            if let region = Singletons.beaconManager.beaconRegion(identifier: name) {
                if region.beacons.count == 0 {
                    cell.statusLabel.text = "Monitoring"
                } else {
                    cell.nameLabel.textColor = UIColor.black
                    cell.beaconsLabel.text = "\(region.beacons.count)"
                    cell.statusLabel.text = "Ranging"
                    cell.statusLabel.textColor = UIColor(red: 0.1, green: 0.7, blue: 0.1, alpha: 0.5)
                }
            }
        } else if Singletons.scanningManager.isScanning {
            cell.statusLabel.text = "Monitoring"
        } else {
            cell.statusLabel.text = "Idle"
        }
        return cell
    }
    
    override func tableView(_ tableView:UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        let name = BeaconStore.getBeaconNames()[(indexPath as NSIndexPath).row]
        return !Singletons.beaconManager.isRangingRegion(identifier: name)
    }
    
    override func tableView(_ tableView:UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath:IndexPath) {
        if editingStyle == .delete {
            let name = BeaconStore.getBeaconNames()[(indexPath as NSIndexPath).row]
            BeaconStore.removeBeacon(name)
            tableView.deleteRows(at: [indexPath], with:.fade)
        }
    }
    
    // UITableViewDelegate
    override func tableView(_ tableView:UITableView, didSelectRowAt indexPath:IndexPath) {
        let name = BeaconStore.getBeaconNames()[(indexPath as NSIndexPath).row]
        if Singletons.beaconManager.isRangingRegion(identifier: name) {
            if let beaconRegion = self.beaconRegions[name] {
                if beaconRegion.beacons.count > 0 {
                    self.performSegue(withIdentifier: MainStoryBoard.beaconsSegue, sender:indexPath)
                }
            }
        } else {
            self.performSegue(withIdentifier: MainStoryBoard.beaconRegionEditSegue, sender:indexPath)
        }
    }
    
}
