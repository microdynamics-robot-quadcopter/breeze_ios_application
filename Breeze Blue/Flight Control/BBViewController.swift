//
//  NORHRMViewController.swift
//  nRF Toolbox
//
//  Created by Mostafa Berg on 04/05/16.
//  Copyright © 2016 Nordic Semiconductor. All rights reserved.
//

import UIKit
import CoreBluetooth
import Foundation

class BBViewController: NORBaseViewController, NORBluetoothManagerDelegate, NORScannerDelegate {

    //MARK: - View Properties
    var bluetoothManager    : NORBluetoothManager?
    var uartPeripheralName  : String?

    //==========NEW===========
    //MARK: - View Control Properties
    private var leftJoystick: BBJoystick?
    private var rightJoystick: BBJoystick?

    weak var viewModel: BBViewModel?
    private var settingsViewController: BBSettingsViewController?
    private var timer:Timer?
//    var commander: BreezeBlueCommander?
    var is_connect: Bool = false //Debug!!!
    var is_start: Bool = false
    //==========NEW===========


    //MAKR: TEST
    @IBOutlet weak var imuCali: UIButton!
    @IBOutlet weak var motorLauch: UIButton!
    @IBOutlet weak var powerOff: UIButton!
    @IBOutlet weak var slideValue: UILabel!

    @IBAction func StartimuCali(_ sender: Any) {
        self.send(value: "$>")
        self.send(value: "8")
        self.send(value: "<")
    }

    @IBAction func ChangeLauchState(_ sender: Any) {
        if(is_start == false) {
            self.send(value: "$>")
            self.send(value: "6")
            self.send(value: "<")
            is_start = true
            self.motorLauch.setTitle("CLOSE", for: UIControlState())
        }
        else {
            self.send(value: "$>")
            self.send(value: "7")
            self.send(value: "<")
            is_start = false
            self.motorLauch.setTitle("START", for: UIControlState())
        }
    }

    @IBAction func closePowerOff(_ sender: Any) {
        self.send(value: "$>")
        self.send(value: "4")
        self.send(value: "<")
    }

    @IBAction func slideValueChange(_ sender: Any) {
        let slide = sender as! UISlider
        let newText = NSString(format: "%f", slide.value)
        self.slideValue.text = newText as String
        self.send(value: self.slideValue.text!)



//        let commander = viewModel?.breezeblue?.commander
//
//        commander?.prepareData()
        viewModel?.breezeblue?.commander?.prepareData()
        let tmproll = viewModel?.breezeblue?.commander?.roll
        let tmppitch = viewModel?.breezeblue?.commander?.pitch
        let tmpthrust = viewModel?.breezeblue?.commander?.thrust
        let tmpyaw = viewModel?.breezeblue?.commander?.yaw
        self.sendFlightData(tmproll!, pitch: tmppitch!, thrust: tmpthrust!, yaw: tmpyaw!)
//        sendFlightData((commander?.roll)!, pitch: (commander?.pitch)!, thrust: (commander?.thrust)!, yaw: (commander?.yaw)!)
    }

    //MARK: - BBVIewController Outlets
    @IBOutlet weak var deviceName: UILabel!
    @IBOutlet weak var connectionButton: UIButton!
    //==========NEW===========
    @IBOutlet weak var settingsButton: UIButton!
    @IBOutlet weak var leftView: UIView!
    @IBOutlet weak var rightView: UIView!
    //==========NEW===========

    //MARK: - BBVIewController Actions
    @IBAction func connectionButtonTapped(_ sender: AnyObject) {
        bluetoothManager?.cancelPeripheralConnection()
    }

    //==========NEW===========
    @IBAction func settingsClicked(_ sender: Any) {
        performSegue(withIdentifier: "settings", sender: nil)
    }
    //==========NEW===========

    @IBAction func aboutButtonTapped(_ sender: AnyObject) {
        self.showAbout(message: NORAppUtilities.getHelpTextForService(service: .hrm))
    }

    //MARK: - UIViewDelegate
    override func viewDidLoad() {
        super.viewDidLoad()

        //==========NEW===========
        if viewModel == nil {
            viewModel = BBViewModel()
            viewModel?.delegate = self
        }
        setupUI()
        viewModel?.updateSettings()
        //==========NEW===========
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        //==========NEW===========
        viewModel?.loadSettings()
        updateUI()
        //==========NEW===========

        //==========NEW===========
//        startTimer()
        //==========NEW===========
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        //==========NEW===========
        stopTimer()
        //==========NEW===========
    }

    //==========NEW===========
    //MARK: - Private
    private func setupUI() {
        guard let viewModel = viewModel else { return }
//        settingsButton.layer.borderColor = settingsButton.tintColor.cgColor

        //Init joysticks
        let frame = UIScreen.main.bounds

        let leftViewModel = viewModel.leftJoystickProvider
        let leftJoystick = BBJoystick(frame: frame, viewModel: leftViewModel)
        leftViewModel.delegate = leftJoystick
        leftViewModel.add(observer: viewModel)
        leftView.addSubview(leftJoystick)
        self.leftJoystick = leftJoystick

        let rightViewModel = viewModel.rightJoystickProvider
        let rightJoystick = BBJoystick(frame: frame, viewModel: rightViewModel)
        rightViewModel.delegate = rightJoystick
        rightViewModel.add(observer: viewModel)
        rightView.addSubview(rightJoystick)
        self.rightJoystick = rightJoystick
    }

    fileprivate func updateUI() {
        guard let viewModel = viewModel else {
            return
        }
        leftJoystick?.hLabel.text = viewModel.leftXTitle
        leftJoystick?.vLabel.text = viewModel.leftYTitle
        rightJoystick?.hLabel.text = viewModel.rightXTitle
        rightJoystick?.vLabel.text = viewModel.rightYTitle
    }
    //==========NEW===========


    //MARK: - Segue methods
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        // The 'scan' seque will be performed only if bluetoothManager == nil (if we are not connected already).
        return identifier != "scan" || self.bluetoothManager == nil
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        //==========NEW===========
        if segue.identifier == "settings" {
            guard let viewController = segue.destination as? BBSettingsViewController else {
                return
            }
            viewController.viewModel = viewModel?.settingsViewModel
        }
        //==========NEW===========

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
            self.connectionButton.setTitle("DISCONN", for: UIControlState())
        })

        //Following if condition display user permission alert for background notification
        if UIApplication.instancesRespond(to: #selector(UIApplication.registerUserNotificationSettings(_:))){
            UIApplication.shared.registerUserNotificationSettings(UIUserNotificationSettings(types: [.sound, .alert], categories: nil))
        }

        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationDidEnterBackgroundCallback), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationDidBecomeActiveCallback), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)

        //==========NEW===========
//        startTimer()
        setTheTimer()
        //==========NEW===========
    }

    func didDisconnectPeripheral() {
        // Scanner uses other queue to send events. We must edit UI in the main queue
        DispatchQueue.main.async(execute: {
//            self.logger!.bluetoothManager = nil
            self.connectionButton.setTitle("CONNECT", for: UIControlState())
            self.deviceName.text = "DEFAULT"

            if NORAppUtilities.isApplicationInactive() {
                NORAppUtilities.showBackgroundNotification(message: "Peripheral \(self.uartPeripheralName!) is disconnected")
            }

            self.uartPeripheralName = nil
        })
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
        bluetoothManager = nil

        //==========NEW===========
//        stopTimer()
        deinitTimer()
        //==========NEW===========
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

    //==========NEW===========
    private var test_timer: DispatchSourceTimer?
    var pageStepTime: DispatchTimeInterval = .seconds(1)

    // deadline 结束时间
    // interval 时间间隔
    // leeway  时间精度
    func setTheTimer() {
        test_timer = DispatchSource.makeTimerSource(queue: .main)
        test_timer?.scheduleRepeating(deadline: .now() + pageStepTime, interval: pageStepTime)
        test_timer?.setEventHandler {
            self.viewModel?.breezeblue?.commander?.prepareData()
            let tmproll = self.viewModel?.breezeblue?.commander?.roll
            let tmppitch = self.viewModel?.breezeblue?.commander?.pitch
            let tmpthrust = self.viewModel?.breezeblue?.commander?.thrust
            let tmpyaw = self.viewModel?.breezeblue?.commander?.yaw
            self.sendFlightData(tmproll!, pitch: tmppitch!, thrust: tmpthrust!, yaw: tmpyaw!)
        }
        // 启动定时器
        test_timer?.resume()
    }

    func deinitTimer() {
        if let time = self.test_timer {
            time.cancel()
            test_timer = nil
        }
    }





    private func startTimer() {
        stopTimer()

        self.timer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(self.updateData), userInfo:nil, repeats:true)
        NSLog("start timer")
    }

    private func stopTimer() {
        if timer != nil {
            timer?.invalidate()
            timer = nil
            NSLog("stop timer")
        }
    }

    @objc private func updateData(_ timter:Timer){
        guard timer != nil, let commander = viewModel?.breezeblue?.commander else {
            return
        }
//        send(value: "I am maksyuki")
            NSLog("I am supermaker")
            viewModel?.breezeblue?.commander?.prepareData()
            let tmproll = viewModel?.breezeblue?.commander?.roll
            let tmppitch = viewModel?.breezeblue?.commander?.pitch
            let tmpthrust = viewModel?.breezeblue?.commander?.thrust
            let tmpyaw = viewModel?.breezeblue?.commander?.yaw
            self.sendFlightData(tmproll!, pitch: tmppitch!, thrust: tmpthrust!, yaw: tmpyaw!)
//        commander.prepareData()
//        sendFlightData(commander.roll, pitch: commander.pitch, thrust: commander.thrust, yaw: commander.yaw)
    }

    private func sendFlightData(_ roll:Float, pitch:Float, thrust:Float, yaw:Float){
//        let bleSendRollValue   = NSString(format: "%f", roll)
//        let bleSendPitchValue  = NSString(format: "%f", pitch)
//        let bleSendThrustValue = NSString(format: "%f", thrust)
//        let bleSendYawValue    = NSString(format: "%f", yaw)
        let bleSendRollValue   = NSString(format: "%d", Int(roll))
        let bleSendPitchValue  = NSString(format: "%d", Int(pitch))
        let bleSendThrustValue = NSString(format: "%d", Int(thrust))
        let bleSendYawValue    = NSString(format: "%d", Int(yaw))
        send(value: "$>")
        send(value: "5")
        send(value: bleSendRollValue as String)
        send(value: bleSendPitchValue as String)
        send(value: bleSendYawValue as String)
        send(value: bleSendThrustValue as String)
        send(value: "<")
//        self.send(value: self.slideValue.text!)
    }
    //==========NEW===========
}

//==========NEW===========
extension BBViewController: BBViewModelDelegate {
    func signalUpdate() {
        updateUI()
    }

    func signalFailed(with title: String, message: String?) {
        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok",
                                      style: .default,
                                      handler: {[weak alert] (action) in
                                        alert?.dismiss(animated: true, completion: nil)
        }))
        present(alert, animated: true, completion: nil)
    }
}
//==========NEW===========
