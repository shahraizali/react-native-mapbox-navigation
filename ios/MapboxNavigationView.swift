import MapboxCoreNavigation
import MapboxDirections
import MapboxNavigation

// adapted from https://pspdfkit.com/blog/2017/native-view-controllers-and-react-native/ and https://github.com/mslabenyak/react-native-mapbox-navigation/blob/master/ios/Mapbox/MapboxNavigationView.swift
extension UIView {
  var parentViewController: UIViewController? {
    var parentResponder: UIResponder? = self
    while parentResponder != nil {
      parentResponder = parentResponder!.next
      if let viewController = parentResponder as? UIViewController {
        return viewController
      }
    }
    return nil
  }
}

class MapboxNavigationView: UIView, NavigationViewControllerDelegate {
  weak var navViewController: NavigationViewController?
  var embedded: Bool
  var embedding: Bool
  
  @objc var origin: NSArray = [] {
    didSet { setNeedsLayout() }
  }
  
  @objc var destination: NSArray = [] {
    didSet { setNeedsLayout() }
  }
  
  @objc var shouldSimulateRoute: Bool = false
  
  @objc var onProgressChange: RCTDirectEventBlock?
  @objc var onError: RCTDirectEventBlock?
  
  override init(frame: CGRect) {
    self.embedded = false
    self.embedding = false
    super.init(frame: frame)
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    if (navViewController == nil && !embedding && !embedded) {
      embed()
    } else {
      navViewController?.view.frame = bounds
    }
  }
  
  override func removeFromSuperview() {
    super.removeFromSuperview()
    // cleanup and teardown any existing resources
    self.navViewController?.removeFromParent()
  }
  
  private func embed() {
    guard origin.count == 2 && destination.count == 2 else { return }
    
    embedding = true

    let originWaypoint = Waypoint(coordinate: CLLocationCoordinate2D(latitude: origin[1] as! CLLocationDegrees, longitude: origin[0] as! CLLocationDegrees))
    let destinationWaypoint = Waypoint(coordinate: CLLocationCoordinate2D(latitude: destination[1] as! CLLocationDegrees, longitude: destination[0] as! CLLocationDegrees))

    let options = NavigationRouteOptions(waypoints: [originWaypoint, destinationWaypoint])
            
    Directions.shared.calculate(options) { [weak self] (session, result) in
      guard let strongSelf = self, let parentVC = strongSelf.parentViewController else {
        return
      }
      
      switch result {
        case .failure(let error):
          strongSelf.onError!(["message": error.localizedDescription])
        case .success(let response):
          guard let route = response.routes?.first else {
            return
          }
          
          let navigationService = MapboxNavigationService(route: route, routeIndex: 0, routeOptions: options, simulating: strongSelf.shouldSimulateRoute ? .always : .never)
          
          let navigationOptions = NavigationOptions(navigationService: navigationService)
          let vc = NavigationViewController(for: route, routeIndex: 0, routeOptions: options, navigationOptions: navigationOptions)
          
          vc.delegate = strongSelf
          
          CancelButton.appearance().isHidden = true;
        
          parentVC.addChild(vc)
          strongSelf.addSubview(vc.view)
          vc.view.frame = strongSelf.bounds
          vc.didMove(toParent: parentVC)
          strongSelf.navViewController = vc
      }
      
      strongSelf.embedding = false
      strongSelf.embedded = true
    }
  }
  
  func navigationViewController(_ navigationViewController: NavigationViewController, didUpdate progress: RouteProgress, with location: CLLocation, rawLocation: CLLocation) {
    onProgressChange?(["longitude": location.coordinate.longitude, "latitude": location.coordinate.latitude])
  }
}
