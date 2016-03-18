//
//  ViewController.swift
//  HealthKitPractice
//
//  Created by Nam (Nick) N. HUYNH on 3/17/16.
//  Copyright (c) 2016 Enclave. All rights reserved.
//

import UIKit
import HealthKit

enum HeightUnits: String {
    
    case Millimeters = "Milimeters"
    case Centimeters = "Centimeters"
    case Meters = "Meters"
    case Inches = "Inches"
    case Feet = "Feet"
    static let allValues = [Millimeters, Centimeters, Meters, Inches, Feet]
    
    func healthKitUnit() -> HKUnit {
        
        switch self {
            
        case .Millimeters:
            return HKUnit.meterUnitWithMetricPrefix(HKMetricPrefix.Milli)
        case .Centimeters:
            return HKUnit.meterUnitWithMetricPrefix(HKMetricPrefix.Centi)
        case .Meters:
            return HKUnit.meterUnit()
        case .Inches:
            return HKUnit.inchUnit()
        case .Feet:
            return HKUnit.footUnit()
            
        }
        
    }
    
}

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {

    @IBOutlet weak var weightTextField: UITextField!
    
    @IBOutlet weak var saveButton: UIButton!
    
    @IBOutlet weak var heightTextField: UITextField!
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var dateOfBirthLabel: UILabel!
    
    let weightTextFieldRightLabel = UILabel(frame: CGRectZero)
    
    let heightQuantityType = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeight)
    let weightQuantityType = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBodyMass)
    let heartRateQuantityType = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeartRate)
    let dateOfBirthCharacteristicType = HKCharacteristicType.characteristicTypeForIdentifier(HKCharacteristicTypeIdentifierDateOfBirth)
    
    lazy var healthStore = HKHealthStore()
    lazy var typesToShare: NSSet = {
        
        return NSSet(objects: self.heightQuantityType, self.weightQuantityType)
        
    }()
    lazy var typesToRead: NSSet = {
        
        return NSSet(objects: self.heightQuantityType, self.weightQuantityType, self.heartRateQuantityType, self.dateOfBirthCharacteristicType)
        
    }()
    lazy var predicate: NSPredicate = {
        
        let now = NSDate()
        let yesterday = NSCalendar.currentCalendar().dateByAddingUnit(NSCalendarUnit.DayCalendarUnit, value: -1, toDate: now, options: NSCalendarOptions.WrapComponents)
        return HKQuery.predicateForSamplesWithStartDate(yesterday, endDate: now, options: HKQueryOptions.StrictEndDate)
        
    }()
    lazy var query: HKObserverQuery = {

        let strongSelf = self
        return HKObserverQuery(sampleType: strongSelf.weightQuantityType, predicate: strongSelf.predicate, updateHandler: strongSelf.weightChangedHandler)
        
    }()
    
    var heightUnit: HeightUnits = HeightUnits.Millimeters {
        
        willSet {
            
            readHeightInformation()
            
        }
        
    }
    
    var selectedIndexPath = NSIndexPath(forRow: 0, inSection: 0)
    
    struct TableViewInfo {
    
        static let identifier = "Cell"
        
    }
    
    // MARK: Reading weight, height and date of birth data with healthKit
    
    func readWeightInformation() {
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: weightQuantityType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { (query, result, error) -> Void in
            
            if result.count > 0 {
                
                let sample = result[0] as HKQuantitySample
                let weightInKilograms = sample.quantity.doubleValueForUnit(HKUnit.gramUnitWithMetricPrefix(HKMetricPrefix.Kilo))
                
                let formatter = NSMassFormatter()
                let kilogramSuffix = formatter.unitStringFromValue(weightInKilograms, unit: NSMassFormatterUnit.Kilogram)
                NSOperationQueue.mainQueue().addOperationWithBlock({ () -> Void in
                    
                    self.weightTextFieldRightLabel.text = kilogramSuffix
                    self.weightTextFieldRightLabel.sizeToFit()
                    
                    let weightFormattedAsString = NSNumberFormatter.localizedStringFromNumber(NSNumber(double: weightInKilograms), numberStyle: NSNumberFormatterStyle.NoStyle)
                    self.weightTextField.text = weightFormattedAsString
                    
                })
                
            } else {
                
                println("Could not read data or no data available!")
                
            }
            
        }
        
        healthStore.executeQuery(query)
        
    }
    
    func readHeightInformation() {
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: heightQuantityType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { (query, result, error) -> Void in
            
            if result.count > 0 {
                
                let sample = result[0] as HKQuantitySample
                let currentlySelectedUnit = self.heightUnit.healthKitUnit()
                let heightInUnit = sample.quantity.doubleValueForUnit(currentlySelectedUnit)
                NSOperationQueue.mainQueue().addOperationWithBlock({ () -> Void in
                    
                    let heightFormattedAsString = NSNumberFormatter.localizedStringFromNumber(NSNumber(double: heightInUnit), numberStyle: NSNumberFormatterStyle.DecimalStyle)
                    self.heightTextField.text = heightFormattedAsString
                    
                })
                
            } else {
                
                println("Could not read data or no data available!")
                
            }
            
        }
        
        healthStore.executeQuery(query)
        
    }
    
    func readDateOfBirthInformation() {
        
        var dateOfBirthError: NSError?
        let birthDate = healthStore.dateOfBirthWithError(&dateOfBirthError) as NSDate?
        if let error = dateOfBirthError {
            
            println("Could not read data from health kit \(error)")
            
        } else {
            
            if let dateOfBirth = birthDate {
                
                let formatter = NSDateFormatter()
                formatter.dateFormat = "yyyy-MMM-dd"
                let now = NSDate()
                let components = NSCalendar.currentCalendar().components(NSCalendarUnit.YearCalendarUnit, fromDate: dateOfBirth, toDate: now, options: NSCalendarOptions.WrapComponents)
                let age = components.year
                
                dateOfBirthLabel.text = formatter.stringFromDate(dateOfBirth)
                
            } else {
                
                println("Date of birth is not available!")
                
            }
            
        }
        
    }
    
    // MARK: Observering weight changes
    
    func startObserveringWeightChanges() {
        
        healthStore.executeQuery(query)
        healthStore.enableBackgroundDeliveryForType(weightQuantityType, frequency: HKUpdateFrequency.Immediate) { (succeeded, error) -> Void in
            
            if succeeded {
                
                println("Enabled background delivery of weight changes")
                
            } else {
                
                if let theError = error {
                    
                    println("Failed with error: \(theError)")
                    
                }
                
            }
            
        }
        
    }
    
    func stopObserveringWeightChanges() {
        
        healthStore.stopQuery(query)
        healthStore.disableAllBackgroundDeliveryWithCompletion { (succeeded, error) -> Void in
            
            if succeeded {
                
                println("Disabled background delivery of weight changes")
                
            } else {
                
                if let theError = error {
                    
                    println("Failed to disabled with error: \(theError)")
                    
                }
                
            }
            
        }
        
    }
    
    func fetchRecordedWeightLastDay() {
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
        let query = HKSampleQuery(sampleType: weightQuantityType, predicate: predicate, limit: Int(HKObjectQueryNoLimit), sortDescriptors: [sortDescriptor]) { (query, results, error) -> Void in
            
            if results.count > 0 {
                
                for sample in results as [HKQuantitySample] {
                    
                    let weightInKilograms = sample.quantity.doubleValueForUnit(HKUnit.gramUnitWithMetricPrefix(HKMetricPrefix.Kilo))
                    let formatter = NSMassFormatter()
                    let kilogramSuffix = formatter.unitStringFromValue(weightInKilograms, unit: NSMassFormatterUnit.Kilogram)
                    NSOperationQueue.mainQueue().addOperationWithBlock({ () -> Void in
                        
                        println("Weight has been changed to \(weightInKilograms) \(kilogramSuffix) in \(sample.startDate)")
                        
                    })
                    
                }
                
            } else {
                
                println("Could not find any information!")
                
            }
            
        }
        
        healthStore.executeQuery(query)
        
    }
    
    func weightChangedHandler(query: HKObserverQuery!, completionHandler: HKObserverQueryCompletionHandler!, error: NSError!) {
        
        fetchRecordedWeightLastDay()
        completionHandler()
        
    }
    
    // MARK: ViewController life cycle
    
    override func viewDidAppear(animated: Bool) {
        
        super.viewDidAppear(animated)
        if HKHealthStore.isHealthDataAvailable() {
            
            healthStore.requestAuthorizationToShareTypes(typesToShare, readTypes: typesToRead, completion: { (succeeded, error) -> Void in
                
                if succeeded && error == nil {
                    
                    println("Success")
                    
                } else {
                    
                    if let theError = error {
                        
                        println("\(theError)")
                        
                    }
                    
                }
                
            })
            
        } else {
            
            println("Health Data are not available.")
            
        }
        
        readWeightInformation()
        readHeightInformation()
        readDateOfBirthInformation()
        startObserveringWeightChanges()
        
    }
    
    override func viewDidDisappear(animated: Bool) {
        
        super.viewDidDisappear(animated)
        stopObserveringWeightChanges()
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        weightTextField.rightView = weightTextFieldRightLabel
        weightTextField.rightViewMode = UITextFieldViewMode.Always
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: UITableView DataSource
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return HeightUnits.allValues.count
        
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCellWithIdentifier(TableViewInfo.identifier, forIndexPath: indexPath) as UITableViewCell
        cell.textLabel.text = HeightUnits.allValues[indexPath.row].rawValue
        
        if indexPath == selectedIndexPath {
            
            cell.accessoryType = UITableViewCellAccessoryType.Checkmark
            
        } else {
            
            cell.accessoryType = UITableViewCellAccessoryType.None
            
        }
        
        return cell
        
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        let previousSelectedIndexPath = selectedIndexPath
        selectedIndexPath = indexPath
        heightUnit = HeightUnits.allValues[indexPath.row]
        if selectedIndexPath != previousSelectedIndexPath {
            
            tableView.reloadRowsAtIndexPaths([previousSelectedIndexPath, selectedIndexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
            
        }
        
    }
    
    // MARK: Restoration
    
    override func encodeRestorableStateWithCoder(coder: NSCoder) {
        
        super.encodeRestorableStateWithCoder(coder)
        coder.encodeObject(selectedIndexPath, forKey: "SelectedIndexPath")
        coder.encodeObject(heightUnit.rawValue, forKey: "HeightUnit")
        
    }
    
    override func decodeRestorableStateWithCoder(coder: NSCoder) {
        
        super.decodeRestorableStateWithCoder(coder)
        selectedIndexPath = coder.decodeObjectForKey("SelectedIndexPath") as NSIndexPath
        if let newUnit = HeightUnits(rawValue: coder.decodeObjectForKey("HeightUnit") as String) {
            
            heightUnit = newUnit
            
        }
        
    }
    
    // MARK: UITextField Delegate
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        
        textField.resignFirstResponder()
        return true
        
    }

    // MARK: Save Weight and Height Button Performing
    
    @IBAction func saveUserWeight(sender: AnyObject) {
        
        let kilogramUnit = HKUnit.gramUnitWithMetricPrefix(HKMetricPrefix.Kilo)
        let weightQuantity = HKQuantity(unit: kilogramUnit, doubleValue: (weightTextField.text as NSString).doubleValue)
        let now = NSDate()
        let sample = HKQuantitySample(type: weightQuantityType, quantity: weightQuantity, startDate: now, endDate: now)
        healthStore.saveObject(sample, withCompletion: { (succeeded, error) -> Void in
            
            if error == nil {
                
                println("Succeeded save weight!")
                
            } else {
                
                println("Failed to save weight!")
                
            }
            
        })
        
    }
    
    @IBAction func saveUserHeight(sender: AnyObject) {
        
        let currentlySelectedUnit = heightUnit.healthKitUnit()
        let heightQuantity = HKQuantity(unit: currentlySelectedUnit, doubleValue: (heightTextField.text as NSString).doubleValue)
        let now = NSDate()
        let sample = HKQuantitySample(type: heightQuantityType, quantity: heightQuantity, startDate: now, endDate: now)
        healthStore.saveObject(sample, withCompletion: { (succeeded, error) -> Void in
            
            if error == nil {
                
                println("Save user's height successfully!")
                
            } else {
                
                println("Failed to save user's height!")
                
            }
            
        })
        
    }
    
}

