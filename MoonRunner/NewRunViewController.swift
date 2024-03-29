/*
* Copyright (c) 2015 Razeware LLC
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
* THE SOFTWARE.
*/

import UIKit
import CoreData
import CoreLocation
import HealthKit
import MapKit

let DetailSegueName = "RunDetails"

class NewRunViewController: UIViewController {
  var managedObjectContext: NSManagedObjectContext?

  var run: Run!

  @IBOutlet weak var drinkCounterLabel: UILabel!
  @IBOutlet weak var promptLabel: UILabel!
  @IBOutlet weak var timeLabel: UILabel!
  @IBOutlet weak var distanceLabel: UILabel!
  @IBOutlet weak var paceLabel: UILabel!
  @IBOutlet weak var startButton: UIButton!
  @IBOutlet weak var stopButton: UIButton!
  @IBOutlet weak var drinkMoreButton: UIButton!
  @IBOutlet weak var mapView: MKMapView!

  var seconds = 0.0
  var distance = 0.0
  var numberDrinks = 0
  

    @IBAction func moreDrinks(sender: UIButton) {
        numberDrinks++
        drinkCounterLabel.text = "# of Drinks: \(numberDrinks)"
    }
  lazy var locationManager: CLLocationManager = {
    var _locationManager = CLLocationManager()
    _locationManager.delegate = self
    _locationManager.desiredAccuracy = kCLLocationAccuracyBest
    _locationManager.activityType = .Fitness

    // Movement threshold for new events
    _locationManager.distanceFilter = 10.0
    return _locationManager
    }()

  lazy var locations = [CLLocation]()
  lazy var timer = NSTimer()

  override func viewWillAppear(animated: Bool) {
    super.viewWillAppear(animated)

    drinkCounterLabel.text = "# of Drinks: 0"
    startButton.hidden = false

    promptLabel.hidden = false

    timeLabel.hidden = true
    distanceLabel.hidden = true
    paceLabel.hidden = true
    stopButton.hidden = true
    drinkMoreButton.hidden = true
    drinkCounterLabel.hidden = true
    

    locationManager.requestAlwaysAuthorization()

    mapView.hidden = true
  }

  override func viewWillDisappear(animated: Bool) {
    super.viewWillDisappear(animated)
    timer.invalidate()
  }

  func eachSecond(timer: NSTimer) {
    seconds++
    let secondsQuantity = HKQuantity(unit: HKUnit.secondUnit(), doubleValue: seconds)
    timeLabel.text = "Time: " + secondsQuantity.description
    let distanceQuantity = HKQuantity(unit: HKUnit.meterUnit(), doubleValue: distance)
    distanceLabel.text = "Distance: " + distanceQuantity.description

    let paceUnit = HKUnit.secondUnit().unitDividedByUnit(HKUnit.meterUnit())
    let paceQuantity = HKQuantity(unit: paceUnit, doubleValue: seconds / distance)
    paceLabel.text = "Pace: " + paceQuantity.description
    
  }

  func startLocationUpdates() {
    // Here, the location manager will be lazily instantiated
    locationManager.startUpdatingLocation()
  }

  func saveRun() {
    // 1
    let savedRun = NSEntityDescription.insertNewObjectForEntityForName("Run",
      inManagedObjectContext: managedObjectContext!) as! Run
    savedRun.distance = distance
    savedRun.duration = seconds
    savedRun.timestamp = NSDate()

    // 2
    var savedLocations = [Location]()
    for location in locations {
      let savedLocation = NSEntityDescription.insertNewObjectForEntityForName("Location",
        inManagedObjectContext: managedObjectContext!) as! Location
      savedLocation.timestamp = location.timestamp
      savedLocation.latitude = location.coordinate.latitude
      savedLocation.longitude = location.coordinate.longitude
      savedLocations.append(savedLocation)
    }

    savedRun.locations = NSOrderedSet(array: savedLocations)
    run = savedRun

    // 3
    var error: NSError?
    let success = managedObjectContext!.save(&error)
    if !success {
      println("Could not save the run!")
    }
  }

  @IBAction func startPressed(sender: AnyObject) {
    startButton.hidden = true
    promptLabel.hidden = true

    timeLabel.hidden = false
    distanceLabel.hidden = false
    paceLabel.hidden = true
    stopButton.hidden = false
    drinkCounterLabel.hidden = false
    drinkMoreButton.hidden = false

    seconds = 0.0
    distance = 0.0
    
    locations.removeAll(keepCapacity: false)
    timer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: "eachSecond:", userInfo: nil, repeats: true)
    startLocationUpdates()

    mapView.hidden = false
  }

  @IBAction func stopPressed(sender: AnyObject) {
    let actionSheet = UIActionSheet(title: "Run Stopped", delegate: self, cancelButtonTitle: "Cancel", destructiveButtonTitle: nil, otherButtonTitles: "Save", "Discard")
    actionSheet.actionSheetStyle = .Default
    actionSheet.showInView(view)
  }

  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    if let detailViewController = segue.destinationViewController as? DetailViewController {
      detailViewController.run = run
    }
  }
}

// MARK: - MKMapViewDelegate
extension NewRunViewController: MKMapViewDelegate {
  func mapView(mapView: MKMapView!, rendererForOverlay overlay: MKOverlay!) -> MKOverlayRenderer! {
    if !overlay.isKindOfClass(MKPolyline) {
      return nil
    }

    let polyline = overlay as! MKPolyline
    let renderer = MKPolylineRenderer(polyline: polyline)
    renderer.strokeColor = UIColor.blueColor()
    renderer.lineWidth = 3
    return renderer
  }
}

// MARK: - CLLocationManagerDelegate
extension NewRunViewController: CLLocationManagerDelegate {
  func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
    for location in locations as! [CLLocation] {
      let howRecent = location.timestamp.timeIntervalSinceNow

      if abs(howRecent) < 10 && location.horizontalAccuracy < 20 {
        //update distance
        if self.locations.count > 0 {
          distance += location.distanceFromLocation(self.locations.last)

          var coords = [CLLocationCoordinate2D]()
          coords.append(self.locations.last!.coordinate)
          coords.append(location.coordinate)

          let region = MKCoordinateRegionMakeWithDistance(location.coordinate, 500, 500)
          mapView.setRegion(region, animated: true)

          mapView.addOverlay(MKPolyline(coordinates: &coords, count: coords.count))
        }

        //save location
        self.locations.append(location)
      }
    }
  }
}

// MARK: - UIActionSheetDelegate
extension NewRunViewController: UIActionSheetDelegate {
  func actionSheet(actionSheet: UIActionSheet, clickedButtonAtIndex buttonIndex: Int) {
    //save
    if buttonIndex == 1 {
      saveRun()
      performSegueWithIdentifier(DetailSegueName, sender: nil)
    }
      //discard
    else if buttonIndex == 2 {
      navigationController?.popToRootViewControllerAnimated(true)
    }
  }
}
