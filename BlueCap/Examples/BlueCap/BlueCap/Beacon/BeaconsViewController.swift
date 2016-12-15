//
//  BeaconsViewController.swift
//  BlueCap
//
//  Created by Troy Stribling on 9/13/14.
//  Copyright (c) 2014 Troy Stribling. The MIT License (MIT).
//

import UIKit
import BlueCapKit

class BeaconsViewController: UITableViewController {

    var beaconRegion: BeaconRegion?

    struct MainStoryBoard {
        static let beaconCell   = "BeaconCell"
    }
    
    required init?(coder aDecoder:NSCoder) {
        super.init(coder:aDecoder)
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let beaconRegion = self.beaconRegion {
            self.navigationItem.title = beaconRegion.identifier
            // TODO: Use Future Callback
            NotificationCenter.default.addObserver(self, selector: #selector(BeaconsViewController.updateBeacons), name: NSNotification.Name(rawValue: BlueCapNotification.didUpdateBeacon), object: beaconRegion)
        } else {
            self.navigationItem.title = "Beacons"
        }
        NotificationCenter.default.addObserver(self, selector:#selector(BeaconsViewController.didEnterBackground), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationItem.title = ""
        NotificationCenter.default.removeObserver(self)
    }
    
    override func prepare(for segue:UIStoryboardSegue, sender: Any!) {
    }

    func updateBeacons() {
        Logger.debug()
        self.tableView.reloadData()
    }
    
    func sortBeacons(_ beacons: [Beacon]) -> [Beacon] {
        return beacons.sorted() { (b1: Beacon, b2: Beacon) -> Bool in
            if b1.major > b2.major {
                return true
            } else if b1.major == b2.major && b1.minor > b2.minor {
                return true
            } else {
                return false
            }
        }
    }
    
    func didEnterBackground() {
        Logger.debug()
        _ = self.navigationController?.popToRootViewController(animated: false)
    }
    
    // UITableViewDataSource
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let beaconRegion = self.beaconRegion {
            return beaconRegion.beacons.count
        } else {
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MainStoryBoard.beaconCell, for: indexPath) as! BeaconCell
        if let beaconRegion = self.beaconRegion {
            let beacon = self.sortBeacons(beaconRegion.beacons)[indexPath.row]
            cell.proximityUUIDLabel.text = beacon.proximityUUID.uuidString
            cell.majorLabel.text = "\(beacon.major)"
            cell.minorLabel.text = "\(beacon.minor)"
            cell.proximityLabel.text = beacon.proximity.stringValue
            cell.rssiLabel.text = "\(beacon.rssi)"
            let accuracy = NSString(format:"%.4f", beacon.accuracy)
            cell.accuracyLabel.text = "\(accuracy)m"
        }
        return cell
    }

}
