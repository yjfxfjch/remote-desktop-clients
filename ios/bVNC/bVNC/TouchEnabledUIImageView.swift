//
//  CustomTouchInput.swift
//  bVNC
//
//  Created by iordan iordanov on 2020-02-27.
//  Copyright © 2020 iordan iordanov. All rights reserved.
//

import Foundation
import UIKit

class TouchEnabledUIImageView: UIImageView {
    var fingers = [UITouch?](repeating: nil, count:5)
    var width: CGFloat = 0.0
    var height: CGFloat = 0.0
    var lastX: CGFloat = 0.0
    var lastY: CGFloat = 0.0
    var newX: CGFloat = 0.0
    var newY: CGFloat = 0.0
    var viewTransform: CGAffineTransform = CGAffineTransform()
    var lastTime: Double = 0.0
    var touchEnabled: Bool = false
    var firstDown: Bool = false
    var secondDown: Bool = false
    var thirdDown: Bool = false
    var point: CGPoint = CGPoint(x: 0, y: 0)
    let lock = NSLock()
    var panGesture: UIPanGestureRecognizer?
    var pinchGesture: UIPinchGestureRecognizer?
    var moveEventsSinceFingerDown = 0
    var inScrolling = false
    var inPanning = false
    var panningToleranceEvents = 0

    func initialize() {
        isMultipleTouchEnabled = true
        self.width = self.frame.width
        self.height = self.frame.height
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handleZooming(_:)))
        panGesture?.minimumNumberOfTouches = 2
        panGesture?.maximumNumberOfTouches = 2

    }
    
    override init(image: UIImage?) {
        super.init(image: image)
        initialize()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initialize()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialize()
    }
    
    func enableTouch() {
        touchEnabled = true
    }
    
    func disableTouch() {
        touchEnabled = false
    }
    
    func isOutsideImageBoundaries(touch: UITouch, touchView: UIView) -> Bool {
        if (!touch.view!.isKind(of: UIImageView.self)) {
            return false
        }
        return true
    }
    
    func setViewParameters(touch: UITouch, touchView: UIView) {
        self.width = touchView.frame.width
        self.height = touchView.frame.height
        self.point = touch.location(in: touchView)
        self.viewTransform = touchView.transform
        self.newX = self.point.x*viewTransform.a
        self.newY = self.point.y*viewTransform.d
    }
    
    func sendPointerEvent(action: String, index: Int, touch: UITouch, moving: Bool, firstDown: Bool, secondDown: Bool, thirdDown: Bool) {
        Background {
            self.lock.lock()
            if (self.touchEnabled) {
                if !moving || abs(self.lastX - self.newX) > 12.0 || abs(self.lastY - self.newY) > 12.0 {
                    //print ("Not moving or moved far enough, sending event.")
                    sendPointerEventToServer(Int32(self.width), Int32(self.height), Int32(self.newX), Int32(self.newY), firstDown, secondDown, thirdDown, false, false)
                    self.lastX = self.newX
                    self.lastY = self.newY
                //} else {
                //    print ("Moving and not moved far enough, discarding event.")
                }
            }
            self.lock.unlock()
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        /*
        if (touches.count == 2) {
            print("Two fingers down, so ignore to allow pinch zooming and panning unhindered.")
            return
        }*/
        for touch in touches {
            if let touchView = touch.view {
                if !isOutsideImageBoundaries(touch: touch, touchView: touchView) {
                    print("Touch is outside image, ignoring.")
                    continue
                }
            } else {
                print("Could not unwrap touch.view, sending event at last coordinates.")
            }
            
            for (index, finger)  in self.fingers.enumerated() {
                if finger == nil {
                    self.fingers[index] = touch
                    if index == 0 {
                        self.inScrolling = false
                        self.inPanning = false
                        self.moveEventsSinceFingerDown = 0
                        print("ONE FINGER Detected, marking this a left-click")
                        self.firstDown = true
                        self.secondDown = false
                        self.thirdDown = false
                        // Record location only for first index
                        if let touchView = touch.view {
                            self.setViewParameters(touch: touch, touchView: touchView)
                        }
                    }
                    if index == 1 {
                        print("TWO FINGERS Detected, marking this a right-click")
                        self.firstDown = false
                        self.secondDown = false
                        self.thirdDown = true
                    }
                    if index == 2 {
                        print("THREE FINGERS Detected, marking this a middle-click")
                        self.firstDown = false
                        self.secondDown = true
                        self.thirdDown = false
                    }
                    break
                }
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        for touch in touches {
            if let touchView = touch.view {
                if !isOutsideImageBoundaries(touch: touch, touchView: touchView) {
                    print("Touch is outside image, ignoring.")
                    continue
                }
            } else {
                print("Could not unwrap touch.view, sending event at last coordinates.")
            }
            
            for (index, finger) in self.fingers.enumerated() {
                if let finger = finger, finger == touch {
                    if index == 0 {
                        // Record location only for first index
                        if let touchView = touch.view {
                            self.setViewParameters(touch: touch, touchView: touchView)
                        }
                        if moveEventsSinceFingerDown > 2 {
                            self.sendPointerEvent(action: "finger moved", index: index, touch: touch, moving: true, firstDown: self.firstDown, secondDown: self.secondDown, thirdDown: self.thirdDown)
                        } else {
                            print("Discarding some events")
                            moveEventsSinceFingerDown += 1
                        }
                    }
                    break
                }
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        if (!firstDown && !secondDown && !thirdDown) {
            print("No buttons are indicated to be down, ignoring.")
            return
        }

        for touch in touches {
            if let touchView = touch.view {
                if !isOutsideImageBoundaries(touch: touch, touchView: touchView) {
                    print("Touch is outside image, ignoring.")
                    continue
                }
            } else {
                print("Could not unwrap touch.view, sending event at last coordinates.")
            }
            
            for (index, finger) in self.fingers.enumerated() {
                if let finger = finger, finger == touch {
                    self.fingers[index] = nil
                    if (index == 0) {
                        if (self.panGesture?.state == .began || self.pinchGesture?.state == .began) {
                            print("Currently panning or zooming and first finger lifted, not sending mouse events.")
                        } else {
                            print("Not panning or zooming and first finger lifted, sending mouse events.")
                            self.sendPointerEvent(action: "finger lifted", index: index, touch: touch, moving: false, firstDown: self.firstDown, secondDown: self.secondDown, thirdDown: self.thirdDown)
                            self.firstDown = false
                            self.secondDown = false
                            self.thirdDown = false
                            self.sendPointerEvent(action: "finger lifted", index: index, touch: touch, moving: false, firstDown: self.firstDown, secondDown: self.secondDown, thirdDown: self.thirdDown)
                        }
                    } else {
                        print("Fingers other than first lifted, not sending mouse events.")
                    }
                    break
                }
            }
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>?, with event: UIEvent?) {
        super.touchesCancelled(touches!, with: event)
        guard let touches = touches else { return }
        self.touchesEnded(touches, with: event)
    }
    
    func enableGestures() {
        isUserInteractionEnabled = true
        if let pinchGesture = pinchGesture { addGestureRecognizer(pinchGesture) }
        if let panGesture = panGesture { addGestureRecognizer(panGesture) }
    }
    
    @objc private func handlePan(_ sender: UIPanGestureRecognizer) {
        let translation = sender.translation(in: sender.view)

        if let view = sender.view {
            let scaleX = sender.view!.transform.a
            let scaleY = sender.view!.transform.d
            //print ("abs(scaleX*translation.x): \(abs(scaleX*translation.x)), abs(scaleY*translation.y): \(abs(scaleY*translation.y))")
            // If scrolling or tolerance for scrolling is exceeded
            if (!self.inPanning && (self.inScrolling || abs(scaleX*translation.x) < 0.25 && abs(scaleY*translation.y) >= 0.25)) {
                // If tolerance for scrolling was just exceeded, begin scroll event
                if (!self.inScrolling) {
                    self.inScrolling = true
                    self.point = sender.location(in: view)
                    self.viewTransform = view.transform
                    self.newX = self.point.x*viewTransform.a
                    self.newY = self.point.y*viewTransform.d
                }
                var sentDown = false
                if translation.y >= 0.25 {
                    sendPointerEventToServer(Int32(self.width), Int32(self.height), Int32(self.newX), Int32(self.newY), false, false, false, true, false)
                    sentDown = true
                } else if translation.y <= 0.25 {
                    sendPointerEventToServer(Int32(self.width), Int32(self.height), Int32(self.newX), Int32(self.newY), false, false, false, false, true)
                    sentDown = true
                }
                if sentDown {
                    sendPointerEventToServer(Int32(self.width), Int32(self.height), Int32(self.newX), Int32(self.newY), false, false, false, false, false)
                }
                return
            }
            self.inPanning = true
            var newCenterX = view.center.x + scaleX*translation.x
            var newCenterY = view.center.y + scaleY*translation.y
            let scaledWidth = sender.view!.frame.width/scaleX
            let scaledHeight = sender.view!.frame.height/scaleY
            if sender.view!.frame.minX/scaleX >= 20 { newCenterX = view.center.x - 10 }
            if sender.view!.frame.minY/scaleY >= 20 { newCenterY = view.center.y - 10 }
            if sender.view!.frame.minX/scaleX <= -20 - (scaleX-1.0)*scaledWidth/scaleX { newCenterX = view.center.x + 10 }
            if sender.view!.frame.minY/scaleY <= -20 - (scaleY-1.0)*scaledHeight/scaleY { newCenterY = view.center.y + 10 }
            view.center = CGPoint(x: newCenterX, y: newCenterY)
            sender.setTranslation(CGPoint.zero, in: view)
        }
    }
    
    @objc private func handleZooming(_ sender: UIPinchGestureRecognizer) {
        let scale = sender.scale
        let transformResult = sender.view?.transform.scaledBy(x: sender.scale, y: sender.scale)
        guard let newTransform = transformResult, newTransform.a > 1, newTransform.d > 1 else { return }

        if let view = sender.view {
            let scaledWidth = sender.view!.frame.width/scale
            let scaledHeight = sender.view!.frame.height/scale
            if view.center.x/scale < -20 { view.center.x = -20*scale }
            if view.center.y/scale < -20 { view.center.y = -20*scale }
            if view.center.x/scale > scaledWidth/2 + 20 { view.center.x = (scaledWidth/2 + 20)*scale }
            if view.center.y/scale > scaledHeight/2 + 20 { view.center.y = (scaledHeight/2 + 20)*scale }
        }
        sender.view?.transform = newTransform
        sender.scale = 1
        //print("Frame: \(sender.view!.frame)")
    }
    
}