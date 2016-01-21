//
//  MapViewController.swift
//  CarPool
//
//  Created by Shaik Ghouse Basha on 21/01/16.
//  Copyright © 2016 GlowTouch. All rights reserved.
//

import UIKit
import Spring
import GoogleMaps

enum TravelModes: Int {
    case driving
    case walking
    case bicycling
}

class MapViewController: UIViewController {
    @IBOutlet var mapView: GMSMapView!
    @IBOutlet var originTextField: UITextField!
    @IBOutlet var destinationTextField: UITextField!
    @IBOutlet var searchView: SpringView!
    @IBOutlet var optionView: SpringView!
    
    var activeTextField: String!
    var locationManager = CLLocationManager()
    var didFindMyLocation = false
    var mapTasks = MapTasks()
    var locationMarker: GMSMarker!
    var originMarker: GMSMarker!
    var destinationMarker: GMSMarker!
    var routePolyline: GMSPolyline!
    var markersArray: Array<GMSMarker> = []
    var waypointsArray: Array<String> = []
    var travelMode = TravelModes.driving

    override func viewDidLoad() {
        super.viewDidLoad()
        searchView.hidden=true
        activeTextField = "Driving"
        locationManager.delegate = self
        mapView.delegate = self        
        locationManager.requestWhenInUseAuthorization()
        mapView.addObserver(self, forKeyPath: "myLocation", options: NSKeyValueObservingOptions.New, context: nil)
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    // MARK: ReverseGeoCoder Corordinate
    func reverseGeocodeCoordinate(coordinate: CLLocationCoordinate2D) {
        let geocoder = GMSGeocoder()
        geocoder.reverseGeocodeCoordinate(coordinate) { response, error in
            if let address = response?.firstResult() {
                let lines = address.lines as! [String]
                if self.activeTextField == "Driving" {
                    self.originTextField.text = lines.joinWithSeparator("\n")
                }else {
                    self.destinationTextField.text = lines.joinWithSeparator("\n")
                }
                UIView.animateWithDuration(0.25) {
                    self.view.layoutIfNeeded()
                }
            }
        }
    }
    // MARK: IBAction method implementation
    @IBAction func optionButtonAction(sender: SpringButton) {
        if self.optionView.hidden == true {
            self.optionView.hidden=false
            self.optionView.animation = "squeezeLeft"
            self.optionView.animate()
        }else {
            self.optionView.animation = "squeezeDown"
            self.optionView.animate()
            self.optionView.hidden=true
        }
        
    }
    @IBAction func routeForPoolingButtonAction(sender: SpringButton) {
        
        searchView.hidden=false
        optionView.hidden=true
        searchView.animation="squeezeDown"
        searchView.animate()
    }

    @IBAction func changeMapType(sender: AnyObject) {
        let actionSheet = UIAlertController(title: "Map Types", message: "Select map type:", preferredStyle: UIAlertControllerStyle.ActionSheet)
        
        let normalMapTypeAction = UIAlertAction(title: "Normal", style: UIAlertActionStyle.Default) { (alertAction) -> Void in
            self.mapView.mapType = GoogleMaps.kGMSTypeNormal
        }
        
        let terrainMapTypeAction = UIAlertAction(title: "Terrain", style: UIAlertActionStyle.Default) { (alertAction) -> Void in
            self.mapView.mapType = GoogleMaps.kGMSTypeTerrain
        }
        
        let hybridMapTypeAction = UIAlertAction(title: "Hybrid", style: UIAlertActionStyle.Default) { (alertAction) -> Void in
            self.mapView.mapType = GoogleMaps.kGMSTypeHybrid
        }
        
        let cancelAction = UIAlertAction(title: "Close", style: UIAlertActionStyle.Cancel) { (alertAction) -> Void in
            
        }
        
        actionSheet.addAction(normalMapTypeAction)
        actionSheet.addAction(terrainMapTypeAction)
        actionSheet.addAction(hybridMapTypeAction)
        actionSheet.addAction(cancelAction)
        
        presentViewController(actionSheet, animated: true, completion: nil)
    }
    
    
    @IBAction func findAddress(sender: AnyObject) {
        let addressAlert = UIAlertController(title: "Address Finder", message: "Type the address you want to find:", preferredStyle: UIAlertControllerStyle.Alert)
        
        addressAlert.addTextFieldWithConfigurationHandler { (textField) -> Void in
            textField.placeholder = "Address?"
        }
        
        let findAction = UIAlertAction(title: "Find Address", style: UIAlertActionStyle.Default) { (alertAction) -> Void in
            let address = (addressAlert.textFields![0] as UITextField).text! as String!
            
            self.mapTasks.geocodeAddress(address, withCompletionHandler: { (status, success) -> Void in
                if !success {
                    print(status)
                    
                    if status == "ZERO_RESULTS" {
                        self.showAlertWithMessage("The location could not be found.")
                    }
                }
                else {
                    let coordinate = CLLocationCoordinate2D(latitude: self.mapTasks.fetchedAddressLatitude, longitude: self.mapTasks.fetchedAddressLongitude)
                    self.mapView.camera = GMSCameraPosition.cameraWithTarget(coordinate, zoom: 14.0)
                    
                    self.setupLocationMarker(coordinate)
                }
            })
            
        }
        
        let closeAction = UIAlertAction(title: "Close", style: UIAlertActionStyle.Cancel) { (alertAction) -> Void in
            
        }
        
        addressAlert.addAction(findAction)
        addressAlert.addAction(closeAction)
        
        presentViewController(addressAlert, animated: true, completion: nil)
    }
    
    @IBAction func createRoute2(sender: AnyObject) {
        
        let origin = self.originTextField.text
        let destination = self.destinationTextField.text
        
        if origin?.length<5 {
            SweetAlert().showAlert("Origin field Cannot be blank")
        }
        if destination?.length<5 {
            SweetAlert().showAlert("Destination field Cannot be blank")
        }

        if let _ = self.routePolyline {
            self.clearRoute()
            self.waypointsArray.removeAll(keepCapacity: false)
        }

        self.mapTasks.getDirections(origin, destination: destination, waypoints: nil, travelMode: self.travelMode, completionHandler: { (status, success) -> Void in
            if success {
                self.configureMapAndMarkersForRoute()
                self.drawRoute()
                self.displayRouteInfo()
            }
            else {
                print(status)
            }
        })
    }
    
    @IBAction func changeTravelMode(sender: AnyObject) {
        let actionSheet = UIAlertController(title: "Travel Mode", message: "Select travel mode:", preferredStyle: UIAlertControllerStyle.ActionSheet)
        
        let drivingModeAction = UIAlertAction(title: "Driving", style: UIAlertActionStyle.Default) { (alertAction) -> Void in
            self.travelMode = TravelModes.driving
            self.recreateRoute()
        }
        
        let walkingModeAction = UIAlertAction(title: "Walking", style: UIAlertActionStyle.Default) { (alertAction) -> Void in
            self.travelMode = TravelModes.walking
            self.recreateRoute()
        }
        
        let bicyclingModeAction = UIAlertAction(title: "Bicycling", style: UIAlertActionStyle.Default) { (alertAction) -> Void in
            self.travelMode = TravelModes.bicycling
            self.recreateRoute()
        }
        
        let closeAction = UIAlertAction(title: "Close", style: UIAlertActionStyle.Cancel) { (alertAction) -> Void in
            
        }
        
        actionSheet.addAction(drivingModeAction)
        actionSheet.addAction(walkingModeAction)
        actionSheet.addAction(bicyclingModeAction)
        actionSheet.addAction(closeAction)
        
        presentViewController(actionSheet, animated: true, completion: nil)
    }

    // MARK: Custom method implementation
    
    func showAlertWithMessage(message: String) {
        let alertController = UIAlertController(title: "GMapsDemo", message: message, preferredStyle: UIAlertControllerStyle.Alert)
        
        let closeAction = UIAlertAction(title: "Close", style: UIAlertActionStyle.Cancel) { (alertAction) -> Void in
            
        }
        
        alertController.addAction(closeAction)
        
        presentViewController(alertController, animated: true, completion: nil)
    }
    
    
    func setupLocationMarker(coordinate: CLLocationCoordinate2D) {
        if locationMarker != nil {
            locationMarker.map = nil
        }
         dispatch_async(dispatch_get_main_queue()) {
            self.locationMarker = GMSMarker(position: coordinate)
            self.locationMarker.map = self.mapView
            
            self.locationMarker.title = self.mapTasks.fetchedFormattedAddress
            self.locationMarker.appearAnimation = GoogleMaps.kGMSMarkerAnimationPop
            self.locationMarker.icon = GMSMarker.markerImageWithColor(UIColor.blueColor())
            self.locationMarker.opacity = 0.75
            
            self.locationMarker.flat = true
            self.locationMarker.snippet = "The best place on earth."
        }
    }
    
    
    func configureMapAndMarkersForRoute() {
       
        dispatch_async(dispatch_get_main_queue()) {
            self.mapView.camera = GMSCameraPosition.cameraWithTarget(self.mapTasks.originCoordinate, zoom: 11.0)
            self.originMarker = GMSMarker(position: self.mapTasks.originCoordinate)
            self.originMarker.map = self.mapView
            self.originMarker.icon = GMSMarker.markerImageWithColor(UIColor.greenColor())
            self.originMarker.title = self.mapTasks.originAddress
            
            self.destinationMarker = GMSMarker(position: self.mapTasks.destinationCoordinate)
            self.destinationMarker.map = self.mapView
            self.destinationMarker.icon = GMSMarker.markerImageWithColor(UIColor.redColor())
            self.destinationMarker.title = self.mapTasks.destinationAddress
        
            if self.waypointsArray.count > 0 {
                for waypoint in self.waypointsArray {
                    let lat: Double = (waypoint.componentsSeparatedByString(",")[0] as NSString).doubleValue
                    let lng: Double = (waypoint.componentsSeparatedByString(",")[1] as NSString).doubleValue
                    
                    let marker = GMSMarker(position: CLLocationCoordinate2DMake(lat, lng))
                    marker.map = self.mapView
                    marker.icon = GMSMarker.markerImageWithColor(UIColor.purpleColor())
                    
                    self.markersArray.append(marker)
                }
            }
        }
    }
    
    
    func drawRoute() {
         dispatch_async(dispatch_get_main_queue()) {
            let route = self.mapTasks.overviewPolyline["points"] as! String
            
            let path: GMSPath = GMSPath(fromEncodedPath: route)
            self.routePolyline = GMSPolyline(path: path)
            self.routePolyline.map = self.mapView
        }
    }
    
    
    func displayRouteInfo() {
     //   lblInfo.text = mapTasks.totalDistance + "\n" + mapTasks.totalDuration
    }
    
    
    func clearRoute() {
        originMarker.map = nil
        destinationMarker.map = nil
        routePolyline.map = nil
        
        originMarker = nil
        destinationMarker = nil
        routePolyline = nil
        
        if markersArray.count > 0 {
            for marker in markersArray {
                marker.map = nil
            }
            
            markersArray.removeAll(keepCapacity: false)
        }
    }
    
    
    func recreateRoute() {
        if let _ = routePolyline {
            clearRoute()
            
            mapTasks.getDirections(mapTasks.originAddress, destination: mapTasks.destinationAddress, waypoints: waypointsArray, travelMode: travelMode, completionHandler: { (status, success) -> Void in
                
                if success {
                    self.configureMapAndMarkersForRoute()
                    self.drawRoute()
                    self.displayRouteInfo()
                }
                else {
                    print(status)
                }
            })
        }
    }


}

extension MapViewController: CLLocationManagerDelegate {
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        if status == CLAuthorizationStatus.AuthorizedWhenInUse {
            mapView.myLocationEnabled = true
        }
    }
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        
        if !didFindMyLocation {
            let myLocation: CLLocation = change![NSKeyValueChangeNewKey] as! CLLocation
            mapView.camera = GMSCameraPosition.cameraWithTarget(myLocation.coordinate, zoom: 10.0)
            mapView.settings.myLocationButton = true
            
            didFindMyLocation = true
        }
    }
}
// MARK: GMSMapViewDelegate method implementation
extension MapViewController: GMSMapViewDelegate {

    func mapView(mapView: GMSMapView!, idleAtCameraPosition position: GMSCameraPosition!) {
        view.endEditing(true)
        reverseGeocodeCoordinate(position.target)
    }
    func mapView(mapView: GMSMapView!, didTapAtCoordinate coordinate: CLLocationCoordinate2D) {
        if let _ = routePolyline {
            let positionString = String(format: "%f", coordinate.latitude) + "," + String(format: "%f", coordinate.longitude)
            waypointsArray.append(positionString)
            
            recreateRoute()
        }
    }
}

// MARK: UITextFieldDelegate

extension MapViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(textField: UITextField) {
        activeTextField = ""
        if textField.tag == 0 {
            activeTextField = "Driving"
        }
    }
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder();
        return true;
    }
}