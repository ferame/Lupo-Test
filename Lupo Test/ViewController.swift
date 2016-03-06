//
//  ViewController.swift
//  Lupo Test
//
//  Created by Justinas Alisauskas on 04/03/2016.
//  Copyright © 2016 JustInCode. All rights reserved.
//
import CoreBluetooth
import MediaPlayer
import UIKit

let ServiceUUID = CBUUID(string: "0x52233523-B000-47C5-A6A9-B1833F23B0F2")
let ButtonUUID = CBUUID(string: "0x52233523-B011-47C5-A6A9-B1833F23B0F2")
var elapsedTime = 0
var wasPlayPressed = false
var timeAtPress = NSDate()
var wasFirstPressedAtLeastOnce = false

var wasSubmitButtonPressed = false

let speechSynthesizer = AVSpeechSynthesizer()

class ViewController: UIViewController, UITextFieldDelegate {
    var centralManager : CBCentralManager!
    var lupoPeripheral : CBPeripheral!
    
    @IBOutlet var statusLabel: UILabel!
    @IBOutlet var label1: UILabel!
    @IBOutlet var label2: UILabel!
    @IBOutlet var label3: UILabel!
    @IBOutlet var cityTextField: UITextField!
    @IBOutlet var weatherForecastLabel: UILabel!
    @IBAction func SubmitButtonPressed(sender: AnyObject) {
        wasSubmitButtonPressed = true
        if cityTextField.text != "" {
            findWeather(cityTextField.text!)
        }
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        self.view.endEditing(true)
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool{
        textField.resignFirstResponder()
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.cityTextField.delegate = self
        centralManager = CBCentralManager(delegate: self, queue: nil)
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

extension ViewController: CBPeripheralDelegate{
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        print("Searches for peripheral services")
        self.statusLabel.text = "Looking at peripheral services"
        for service in peripheral.services! {
            let thisService = service as CBService
            if service.UUID == ServiceUUID {
                // Discover characteristics of IR Temperature Service
                peripheral.discoverCharacteristics(nil, forService: thisService)
            }
            // Uncomment to print list of UUIDs
            print("Prints the UUIDs of the Services")
            print(thisService.UUID)
        }
    }
    
    // Enable notification and sensor for each characteristic of valid service
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        
        // update status label
        print("Enabling sensors")
        self.statusLabel.text = "Enabling sensors"
        
        // 0x01 data byte to enable sensor
        var enableValue = 1
        _ = NSData(bytes: &enableValue, length: sizeof(UInt8))
        print("Does it crash after enableBytes")
        // check the uuid of each characteristic to find config and data characteristics
        for charateristic in service.characteristics! {
            let thisCharacteristic = charateristic as CBCharacteristic
            // check for data characteristic
            print("Checking if the button stuff happens")
            if thisCharacteristic.UUID == ButtonUUID {
                // Enable Sensor Notification
                print("THIS")
                self.lupoPeripheral.setNotifyValue(true, forCharacteristic: thisCharacteristic)
                print("Button pressed and value given")
            }
            print("crash maybe?")

        }
        print("Does it crash after the loop?")
        
    }
    
    func findWeather(city: String) -> String{
        let url = NSURL(string: "http://www.weather-forecast.com/locations/" + city.stringByReplacingOccurrencesOfString(" ", withString: "-") + "/forecasts/latest")
        let task = NSURLSession.sharedSession().dataTaskWithURL(url!){ (data, response, error) -> Void in
            if let urlContent = data{
                let webContent = NSString(data: urlContent, encoding: NSUTF8StringEncoding)
                let websiteArray = webContent!.componentsSeparatedByString("3 Day Weather Forecast Summary:</b><span class=\"read-more-small\"><span class=\"read-more-content\"> <span class=\"phrase\">")
                if websiteArray.count > 1{
                    let weatherArray = websiteArray[1].componentsSeparatedByString("</span>")
                    print(weatherArray[0])
                    if weatherArray.count > 1{
                        let weatherSummary = weatherArray[0].stringByReplacingOccurrencesOfString("&deg;", withString: "°")
                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            if !wasSubmitButtonPressed{
                                self.speak(weatherSummary)
                                wasSubmitButtonPressed = false
                            }
                            self.weatherForecastLabel.text = weatherSummary
                            //return weatherSummary.joinWithSeparator(" ")
                        })
                    }
                }
            }
        }
        task.resume()
        return ""
    }
    
    func speak(whatToSpeak: String){
        let speechUtterance = AVSpeechUtterance(string: whatToSpeak)
        print("Should utter")
        speechSynthesizer.speakUtterance(speechUtterance)
        print("Did it utter?")
    }
    
    // Get data values when they are updated
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        self.statusLabel.text = "Connected"
        print("Peripheral connected")
        
        if characteristic.UUID == ButtonUUID {
            // Convert NSData to array of signed 16 bit values
            print("first let")
            let dataBytes = characteristic.value
            print("second let")
            let dataLength = dataBytes!.length
            print("third let")
            var dataArray = [Int16](count: dataLength, repeatedValue: 0)
            dataBytes!.getBytes(&dataArray, length: dataLength * sizeof(Int16))
            
            // Element 1 of the array will be ambient temperature raw value
            print("fourt let")
            print(dataArray)
            
            let musicPlayer = MPMusicPlayerController.systemMusicPlayer()
            
            if dataArray == [3] {
                label1.text = "Previous song pressed"
                speak("Going to Previous Song")
                musicPlayer.skipToPreviousItem()
                label2.text = "None"
                label3.text = "None"
            }else if dataArray == [2]{
                label1.text = "None"
                label2.text = "Next song pressed"
                speak("Going to Next Song")
                musicPlayer.skipToNextItem()
                label3.text = "None"
            }else if dataArray == [1]{
                if !wasFirstPressedAtLeastOnce{
                    timeAtPress = NSDate()
                    wasFirstPressedAtLeastOnce = true
                }
                
                elapsedTime = Int(NSDate().timeIntervalSinceDate(timeAtPress))
                print(elapsedTime)
                if elapsedTime < 1 {
                    timeAtPress = NSDate()
                    print("WeatherPart")
                    print(findWeather("Manchester"))
                }
                else {
                    if wasPlayPressed{
                        musicPlayer.pause()
                        speak("Playback paused")
                        wasPlayPressed = false
                        label1.text = "None"
                        label2.text = "None"
                        label3.text = "Pause pressed"
                    }else{
                        speak("Playback Started")
                        musicPlayer.play()
                        wasPlayPressed = true
                        label1.text = "None"
                        label2.text = "None"
                        label3.text = "Play pressed"
                    }
                    timeAtPress = NSDate()
                }
            }
            print("button press stuff done")
            //let buttonValue = dataArray[1]
            //let ambientTemperature = Double(dataArray[1])/128
            
            // Display on the temp label
            //print("five let")
            //self.buttonLabel.text = NSString(format: "%.2f", ambientTemperature) as String
        }
    }
}

// #MARK - CBCentralManagerDelegate
extension ViewController: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(central: CBCentralManager) {
        if central.state == CBCentralManagerState.PoweredOn {
            // Scan for peripherals if BLE is turned on
            central.scanForPeripheralsWithServices(nil, options: nil)
            self.statusLabel.text = "Searching for BLE Devices"
            print("Searching for BLE Devices")
        }
        else {
            // Can have different conditions for all states if needed - print generic message for now
            print("Bluetooth switched off or not initialized")
        }
    }
    
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        
        let deviceName = "Lupo"
        let nameOfDeviceFound = (advertisementData as NSDictionary).objectForKey(CBAdvertisementDataLocalNameKey) as? NSString
        
        if (nameOfDeviceFound == deviceName) {
            // Update Status Label
            self.statusLabel.text = "Lupo Found"
            print("Lupo device found")
            
            // Stop scanning
            self.centralManager.stopScan()
            // Set as the peripheral to use and establish connection
            self.lupoPeripheral = peripheral
            self.lupoPeripheral.delegate = self
            self.centralManager.connectPeripheral(peripheral, options: nil)
        }
        else {
            self.statusLabel.text = "Lupo NOT Found"
            print("Lupo device NOT found")
        }
    }


    // Discover services of the peripheral
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        self.statusLabel.text = "Discovering peripheral services"
        print("Discovering peripheral services")
        peripheral.discoverServices(nil)
    }
    
    // If disconnected, start searching again
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        self.statusLabel.text = "Disconnected"
        print("Peripheral disconnected")
        central.scanForPeripheralsWithServices(nil, options: nil)
    }

}