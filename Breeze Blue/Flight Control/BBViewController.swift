//
//  NORHRMViewController.swift
//  nRF Toolbox
//
//  Created by Mostafa Berg on 04/05/16.
//  Copyright © 2016 Nordic Semiconductor. All rights reserved.
//

import UIKit
import CoreBluetooth

class NORHRMViewController: NORBaseViewController, NORBluetoothManagerDelegate, NORScannerDelegate {

    //MARK: - View Properties
    var bluetoothManager    : NORBluetoothManager?
    var uartPeripheralName  : String?

    //MAKR: TEST
    @IBOutlet weak var slideValue: UILabel!

    @IBAction func slideValueChange(_ sender: Any) {
        let slide = sender as! UISlider
        let newText = NSString(format: "%f", slide.value)
        self.slideValue.text = newText as String
        self.send(value: self.slideValue.text!)
    }

    //MARK: - UIVIewController Outlets
    @IBOutlet weak var deviceName: UILabel!
    @IBOutlet weak var connectionButton: UIButton!

    //MARK: - UIVIewController Actions
    @IBAction func connectionButtonTapped(_ sender: AnyObject) {
        bluetoothManager?.cancelPeripheralConnection()
    }

    @IBAction func aboutButtonTapped(_ sender: AnyObject) {
        self.showAbout(message: NORAppUtilities.getHelpTextForService(service: .hrm))
    }

    //MARK: - UIViewDelegate
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }


    //MARK: - Segue methods
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        // The 'scan' seque will be performed only if bluetoothManager == nil (if we are not connected already).
        return identifier != "scan" || self.bluetoothManager == nil
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard segue.identifier == "scan" else {
            return
        }

        // Set this contoller as scanner delegate
        let nc = segue.destination as! UINavigationController
        let controller = nc.childViewControllers.first as! NORScannerViewController
        // controller.filterUUID = CBUUID.init(string: NORServiceIdentifiers.uartServiceUUIDString)
        controller.delegate = self
    }

    //MARK: - UIPopoverPresentationCtonrollerDelegate
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
    }

    //MARK: - NORScannerViewDelegate
    func centralManagerDidSelectPeripheral(withManager aManager: CBCentralManager, andPeripheral aPeripheral: CBPeripheral) {
        // We may not use more than one Central Manager instance. Let's just take the one returned from Scanner View Controller
        bluetoothManager = NORBluetoothManager(withManager: aManager)
        bluetoothManager!.delegate = self

        if let name = aPeripheral.name {
            self.uartPeripheralName = name
            self.deviceName.text = name
        } else {
            self.uartPeripheralName = "device"
            self.deviceName.text = "No name"
        }
        self.connectionButton.setTitle("CANCEL", for: UIControlState())
        bluetoothManager!.connectPeripheral(peripheral: aPeripheral)
    }

    //MARK: - BluetoothManagerDelegate
    func peripheralReady() {
        print("Peripheral is ready")
    }

    func peripheralNotSupported() {
        print("Peripheral is not supported")
    }

    func didConnectPeripheral(deviceName aName: String?) {
        // Scanner uses other queue to send events. We must edit UI in the main queue
        DispatchQueue.main.async(execute: {
            self.connectionButton.setTitle("DISCONNECT", for: UIControlState())
        })

        //Following if condition display user permission alert for background notification
        if UIApplication.instancesRespond(to: #selector(UIApplication.registerUserNotificationSettings(_:))){
            UIApplication.shared.registerUserNotificationSettings(UIUserNotificationSettings(types: [.sound, .alert], categories: nil))
        }

        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationDidEnterBackgroundCallback), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationDidBecomeActiveCallback), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
    }

    func didDisconnectPeripheral() {
        // Scanner uses other queue to send events. We must edit UI in the main queue
        DispatchQueue.main.async(execute: {
//            self.logger!.bluetoothManager = nil
            self.connectionButton.setTitle("CONNECT", for: UIControlState())
            self.deviceName.text = "DEFAULT DEVICE"

            if NORAppUtilities.isApplicationInactive() {
                NORAppUtilities.showBackgroundNotification(message: "Peripheral \(self.uartPeripheralName!) is disconnected")
            }

            self.uartPeripheralName = nil
        })
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
        bluetoothManager = nil
    }












    @objc func applicationDidEnterBackgroundCallback(){
        NORAppUtilities.showBackgroundNotification(message: "You are still connected to \(self.uartPeripheralName!)")
    }

    @objc func applicationDidBecomeActiveCallback(){
        UIApplication.shared.cancelAllLocalNotifications()
    }

    //MARK: - UART API
    func send(value aValue : String) {
        if self.bluetoothManager != nil {
            bluetoothManager?.send(text: aValue)
        }
    }
}
