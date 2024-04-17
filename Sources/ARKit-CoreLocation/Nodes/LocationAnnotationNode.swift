//
//  LocationNode.swift
//  ARKit+CoreLocation
//
//  Created by Andrew Hart on 02/07/2017.
//  Copyright © 2017 Project Dent. All rights reserved.
//
import Foundation
import SceneKit
import CoreLocation
import SwiftUI

/// A `LocationNode` which has an attached `AnnotationNode`.
@available(iOS 13.0, *)
open class LocationAnnotationNode<T : View>: LocationNode {
    /// Subnodes and adjustments should be applied to this subnode
    /// Required to allow scaling at the same time as having a 2D 'billboard' appearance
    public let annotationNode: AnnotationNode<T>
    /// Parameter to raise or lower the label's rendering position relative to the node's actual project location.
    /// The default value of 1.1 places the label at a pleasing height above the node.
    /// To draw the label exactly on the true location, use a value of 0. To draw it below the true location,
    /// use a negative value.
    public var annotationHeightAdjustmentFactor = 1.1
    
    public init(location: CLLocation?, arHost: UIHostingController<T>) {
        let plane = SCNPlane(width: arHost.view.frame.width / 100, height: arHost.view.frame.height / 100)
        
        let material = SCNMaterial()
        material.diffuse.contents = arHost.view
        plane.materials = [material]

        annotationNode = AnnotationNode(arHostingController: arHost)
        annotationNode.geometry = plane
        annotationNode.removeFlicker()
//        annotationNode.eulerAngles = -.pi / 2

        super.init(location: location)

        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = SCNBillboardAxis.Y
        constraints = [billboardConstraint]
        
//        DispatchQueue.main.async {
//            arHost.willMove(toParent: vc)
//        }

        addChildNode(annotationNode)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Note: we repeat code from `LocationNode`'s implementation of this function. Is this because of the use of `SCNTransaction`
    /// to wrap the changes? It's legal to nest the calls, should consider this if any more changes to
    /// `LocationNode`'s implementation are needed.
    override func updatePositionAndScale(setup: Bool = false, scenePosition: SCNVector3?,
                                         locationNodeLocation nodeLocation: CLLocation,
                                         locationManager: SceneLocationManager,
                                         onCompletion: (() -> Void)) {
        guard let position = scenePosition, let location = locationManager.currentLocation else { return }

        SCNTransaction.begin()
        SCNTransaction.animationDuration = setup ? 0.0 : 0.1

        let distance = self.location(locationManager.bestLocationEstimate).distance(from: location)

        childNodes.first?.renderingOrder = renderingOrder(fromDistance: distance)

        let adjustedDistance = self.adjustedDistance(setup: setup, position: position,
                                                     locationNodeLocation: nodeLocation, locationManager: locationManager)

        // The scale of a node with a billboard constraint applied is ignored
        // The annotation subnode itself, as a subnode, has the scale applied to it
        let appliedScale = self.scale
        self.scale = SCNVector3(x: 1, y: 1, z: 1)

        var scale: Float

        if scaleRelativeToDistance {
            scale = appliedScale.y
            annotationNode.scale = appliedScale
            annotationNode.childNodes.forEach { child in
                child.scale = appliedScale
            }
        } else {
            let scaleFunc = scalingScheme.getScheme()
            scale = scaleFunc(distance, adjustedDistance)

            annotationNode.scale = SCNVector3(x: scale, y: scale, z: scale)
            annotationNode.childNodes.forEach { node in
                node.scale = SCNVector3(x: scale, y: scale, z: scale)
            }
        }

        // Translate the pivot's Y coordinate so the label will show above or below the actual node location.
        self.pivot = SCNMatrix4MakeTranslation(0, Float(-1 * annotationHeightAdjustmentFactor) * scale, 0)

        SCNTransaction.commit()

        onCompletion()
    }
}

// MARK: - Image from View

public extension UIView {

    @available(iOS 10.0, *)
    /// Gets you an image from the view.
    var image: UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
    }

}
