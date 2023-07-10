//
//  MKToolTip.swift
//
// Copyright (c) 2018 Metin Kilicaslan
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import UIKit

@objc public protocol MKToolTipDelegate: class {
    func toolTipViewDidAppear(for identifier: String)
    func toolTipViewDidDisappear(for identifier: String, with timeInterval: TimeInterval)
}

// MARK: Public methods extensions

public extension UIView {

    @objc public func showToolTip(identifier: String,
                                  title: String? = nil,
                                  message: String,
                                  button: String? = nil,
                                  arrowPosition: MKToolTip.ArrowPosition,
                                  preferences: ToolTipPreferences = ToolTipPreferences(),
                                  delegate: MKToolTipDelegate? = nil) {
        let tooltip = MKToolTip(view: self, identifier: identifier, title: title, message: message, button: button, arrowPosition: arrowPosition, preferences: preferences, delegate: delegate)
        tooltip.calculateFrame()
        tooltip.show()
    }
    
}

public extension UIBarItem {
    
    @objc public func showToolTip(identifier: String, title: String? = nil, message: String, button: String? = nil, arrowPosition: MKToolTip.ArrowPosition, preferences: ToolTipPreferences = ToolTipPreferences(), delegate: MKToolTipDelegate? = nil) {
        if let view = self.view {
            view.showToolTip(identifier: identifier, title: title, message: message, button: button, arrowPosition: arrowPosition, preferences: preferences, delegate: delegate)
        }
    }
    
}

// MARK: Preferences

@objc public class ToolTipPreferences: NSObject {
    
    @objc public class Drawing: NSObject {
        
        @objc public class Arrow: NSObject {
            @objc fileprivate var tip: CGPoint = .zero
            @objc public var size: CGSize = CGSize(width: 20, height: 10)
            @objc public var tipCornerRadius: CGFloat = 5
        }
        
        @objc public class Bubble: NSObject {
            @objc public class Border: NSObject {
                @objc public var color: UIColor? = nil
                @objc public var width: CGFloat = 1
            }
            
            @objc public var inset: CGFloat = 15
            @objc public var spacing: CGFloat = 5
            @objc public var cornerRadius: CGFloat = 5
            @objc public var maxWidth: CGFloat = 210
            @objc public var color: UIColor = UIColor.clear {
                didSet {
                    gradientColors = [color]
                    gradientLocations = []
                }
            }
            @objc public var gradientLocations: [CGFloat] = [0.05, 1.0]
            @objc public var gradientColors: [UIColor] = [UIColor(red: 0.761, green: 0.914, blue: 0.984, alpha: 1.000), UIColor(red: 0.631, green: 0.769, blue: 0.992, alpha: 1.000)]
            @objc public var border: Border = Border()
        }
        
        @objc public class Title: NSObject {
            @objc public var font: UIFont = UIFont.systemFont(ofSize: 12, weight: .bold)
            @objc public var color: UIColor = .white
        }
        
        @objc public class Message: NSObject {
            @objc public var font: UIFont = UIFont.systemFont(ofSize: 12, weight: .regular)
            @objc public var color: UIColor = .white
        }
        
        @objc public class Button: NSObject {
            @objc public var font: UIFont = UIFont.systemFont(ofSize: 12, weight: .regular)
            @objc public var color: UIColor = .white
        }
        
        @objc public class Background: NSObject {
            @objc public var color: UIColor = UIColor.clear {
                didSet {
                    gradientColors = [UIColor.clear, color]
                }
            }
            @objc fileprivate var gradientLocations: [CGFloat] = [0.05, 1.0]
            @objc fileprivate var gradientColors: [UIColor] = [UIColor.clear, UIColor.black.withAlphaComponent(0.4)]
        }
        
        @objc public var arrow: Arrow = Arrow()
        @objc public var bubble: Bubble = Bubble()
        @objc public var title: Title = Title()
        @objc public var message: Message = Message()
        @objc public var button: Button = Button()
        @objc public var background: Background = Background()
    }
    
    @objc public class Animating: NSObject {
        @objc public var dismissTransform: CGAffineTransform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        @objc public var showInitialTransform: CGAffineTransform = CGAffineTransform(scaleX: 0, y: 0)
        @objc public var showFinalTransform: CGAffineTransform = .identity
        @objc public var springDamping: CGFloat = 0.7
        @objc public var springVelocity: CGFloat = 0.7
        @objc public var showInitialAlpha: CGFloat = 0
        @objc public var dismissFinalAlpha: CGFloat = 0
        @objc public var showDuration: TimeInterval = 0.7
        @objc public var dismissDuration: TimeInterval = 0.7
    }
    
    @objc public var drawing: Drawing = Drawing()
    @objc public var animating: Animating = Animating()
    
    @objc public override init() {}
    
}

// MARK: MKToolTip class implementation

open class MKToolTip: UIView {
    
    @objc public enum ArrowPosition: Int {
        case top
        case right
        case bottom
        case left
    }
    
    // MARK: Variables
    
    private var arrowPosition: ArrowPosition = .top
    private var bubbleFrame: CGRect = .zero
    
    private var containerWindow: UIWindow?
    private unowned var presentingView: UIView
    
    private var identifier: String
    private var title: String?
    private var message: String
    private var button: String?
    
    private weak var delegate: MKToolTipDelegate?
    
    private var viewDidAppearDate: Date = Date()
    
    private var preferences: ToolTipPreferences
    
    public static let toolTipWillAppearKeyNSNotification = NSNotification.Name("com.MKToolTip.WillAppear")
    public static let toolTipWillDissapearKeyNSNotification = NSNotification.Name("com.MKToolTip.WillDissapear")
    // MARK: Lazy variables
    
    private lazy var gradient: CGGradient = { [unowned self] in
        let colors = self.preferences.drawing.bubble.gradientColors.map { $0.cgColor } as CFArray
        let locations = self.preferences.drawing.bubble.gradientLocations
        return CGGradient(colorsSpace: nil, colors: colors, locations: locations)!
        }()
    
    private lazy var titleSize: CGSize = { [unowned self] in
        var attributes = [NSAttributedString.Key.font : self.preferences.drawing.title.font]
        
        var textSize = CGSize.zero
        if self.title != nil {
            textSize = self.title!.boundingRect(with: CGSize(width: self.preferences.drawing.bubble.maxWidth - self.preferences.drawing.bubble.inset * 2, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: attributes, context: nil).size
        }
        
        textSize.width = ceil(textSize.width)
        textSize.height = ceil(textSize.height)
        
        return textSize
        }()
    
    private lazy var preferredMessageSize: CGSize = { [unowned self] in
        let widthInset = self.preferences.drawing.bubble.inset * 2
        let width = preferredBubbleSize.width - widthInset
        let size = CGSize(width: width,
                          height: .greatestFiniteMagnitude)
        return size
    }()
    
    private lazy var messageSize: CGSize = { [unowned self] in
        var textSize = self.message.boundingRect(with: self.preferredMessageSize,
                                                 options: .usesLineFragmentOrigin,
                                                 attributes: self.messageAttributes,
                                                 context: nil).size
       
        textSize.width = ceil(textSize.width)
        textSize.height = ceil(textSize.height)
        return textSize
        }()
    
    private lazy var buttonSize: CGSize = { [unowned self] in
        var attributes = [NSAttributedString.Key.font : self.preferences.drawing.button.font]
        
        var textSize = CGSize.zero
        if self.button != nil {
            let size = CGSize(width: self.preferences.drawing.bubble.maxWidth - self.preferences.drawing.bubble.inset * 2,
                              height: .greatestFiniteMagnitude)
            textSize = self.button!.boundingRect(with: size,
                                                 options: .usesLineFragmentOrigin,
                                                 attributes: attributes,
                                                 context: nil).size
        }
        
        textSize.width = ceil(textSize.width)
        textSize.height = ceil(textSize.height)
        
        return textSize
        }()
    
    private lazy var preferredBubbleSize: CGSize = { [unowned self] in
        let widthInset = self.preferences.drawing.bubble.inset * 2
        let bounds = UIScreen.main.bounds
        let width = bounds.width - widthInset
        let size = CGSize(width: width,
                          height: self.preferences.drawing.bubble.inset)
        return size
    }()
    
    private lazy var bubbleSize: CGSize = { [unowned self] in
        var height = self.preferredBubbleSize.height
        let width = self.preferredBubbleSize.width
        
        if self.title != nil {
            height += self.titleSize.height + self.preferences.drawing.bubble.spacing
        }
        
        height += self.messageSize.height
        
        if self.button != nil {
            height += self.preferences.drawing.bubble.spacing + self.buttonSize.height
        }
        
        height += self.preferences.drawing.bubble.inset
        
        return CGSize(width: width, height: height)
        }()
    
    private lazy var contentSize: CGSize = { [unowned self] in
        var height: CGFloat = 0
        var width: CGFloat = 0
        
        switch self.arrowPosition {
        case .top, .bottom:
            height = self.preferences.drawing.arrow.size.height + self.bubbleSize.height
            width = self.bubbleSize.width
        case .right, .left:
            height = self.bubbleSize.height
            width = self.preferences.drawing.arrow.size.height + self.bubbleSize.width
        }
        
        return CGSize(width: width, height: height)
        }()
    
    // MARK: Initializer
    
    init(view: UIView, identifier: String, title: String? = nil, message: String, button: String? = nil, arrowPosition: ArrowPosition, preferences: ToolTipPreferences, delegate: MKToolTipDelegate? = nil) {
        self.presentingView = view
        self.identifier = identifier
        self.title = title
        self.message = message
        self.button = button
        self.arrowPosition = arrowPosition
        self.preferences = preferences
        self.delegate = delegate
        super.init(frame: .zero)
        self.backgroundColor = .clear
        
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self,
                                       selector: #selector(adjustForKeyboard),
                                       name: UIResponder.keyboardWillHideNotification,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(adjustForKeyboard),
                                       name: UIResponder.keyboardWillChangeFrameNotification,
                                       object: nil)
    }
    
    var keyboardHeight = 0.0
    
    @objc func adjustForKeyboard(notification: Notification) {

        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }

        keyboardHeight = keyboardFrame.height
        // Reset the frame of your UIView or its constraints here
        // For example:
//        self.frame.origin.y += keyboardHeight
        
//        let keyboardScreenEndFrame = keyboardValue.cgRectValue
//        let keyboardViewEndFrame = self.convert(keyboardScreenEndFrame,
//                                                from: self.window)
//
//        if notification.name == UIResponder.keyboardWillHideNotification {
//            script.contentInset = .zero
//        } else {
//            script.contentInset = UIEdgeInsets(top: 0,
//                                               left: 0,
//                                               bottom: keyboardViewEndFrame.height - self.safeAreaInsets.bottom,
//                                               right: 0)
//        }
//
//        script.scrollIndicatorInsets = script.contentInset
//
//        let selectedRange = script.selectedRange
//        script.scrollRangeToVisible(selectedRange)
    }
    
    @available(*, unavailable)
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Gesture methods
    
    @objc func handleTap() {
        dismissWithAnimation()
    }
    
    // MARK: Private methods
    
    fileprivate func frame(forArrowPosition arrowPosition: ArrowPosition) -> CGRect {
        let refViewFrame = presentingView.convert(presentingView.bounds,
                                                  to: UIApplication.shared.keyWindow)
        
        var xOrigin: CGFloat = 0
        var yOrigin: CGFloat = 0
        
        let spacingForBorder: CGFloat = (preferences.drawing.bubble.border.color != nil) ? preferences.drawing.bubble.border.width : 0
        
        switch arrowPosition {
        case .top:
            xOrigin = refViewFrame.center.x - contentSize.width / 2
            yOrigin = refViewFrame.y + refViewFrame.height
            preferences.drawing.arrow.tip = CGPoint(x: refViewFrame.center.x - xOrigin, y: 0)
            bubbleFrame = CGRect(x: spacingForBorder, y: preferences.drawing.arrow.size.height + spacingForBorder, width: bubbleSize.width, height: bubbleSize.height)
        case .right:
            xOrigin = refViewFrame.x - contentSize.width
            yOrigin = refViewFrame.center.y - contentSize.height / 2
            preferences.drawing.arrow.tip = CGPoint(x: bubbleSize.width + preferences.drawing.arrow.size.height + spacingForBorder, y: refViewFrame.center.y - yOrigin)
            bubbleFrame = CGRect(x: spacingForBorder, y: spacingForBorder, width: bubbleSize.width, height: bubbleSize.height)
        case .bottom:
            xOrigin = refViewFrame.center.x - contentSize.width / 2
            yOrigin = refViewFrame.y - contentSize.height
            preferences.drawing.arrow.tip = CGPoint(x: refViewFrame.center.x - xOrigin, y: bubbleSize.height + preferences.drawing.arrow.size.height)
            bubbleFrame = CGRect(x: spacingForBorder, y: spacingForBorder, width: bubbleSize.width, height: bubbleSize.height)
        case .left:
            xOrigin = refViewFrame.x + refViewFrame.width
            yOrigin = refViewFrame.center.y - contentSize.height / 2
            preferences.drawing.arrow.tip = CGPoint(x: spacingForBorder, y: refViewFrame.center.y - yOrigin)
            bubbleFrame = CGRect(x: preferences.drawing.arrow.size.height + spacingForBorder, y: spacingForBorder, width: bubbleSize.width, height: bubbleSize.height)
        }
        
        let calculatedFrame = CGRect(x: xOrigin, y: yOrigin, width: contentSize.width + spacingForBorder * 2, height: contentSize.height + spacingForBorder * 2)
        let frame = adjustFrame(calculatedFrame)
        
        return frame
    }
    
    fileprivate func calculateFrame() {
        frame = self.frame(forArrowPosition: arrowPosition)
    }
    
    private func adjustFrame(_ frame: CGRect) -> CGRect {
        let bounds = UIScreen.main.bounds
        let restrictedBounds = CGRect(x: bounds.x + preferences.drawing.bubble.inset, y: bounds.y + preferences.drawing.bubble.inset, width: bounds.width - preferences.drawing.bubble.inset * 2, height: bounds.height - preferences.drawing.bubble.inset * 2)
        
        if !restrictedBounds.contains(frame) {
            var newFrame = frame
            
            if frame.x < restrictedBounds.x {
                let diff = -frame.x + preferences.drawing.bubble.inset
                newFrame.x = frame.x + diff
                if arrowPosition == .top || arrowPosition == .bottom {
                    preferences.drawing.arrow.tip.x = max(preferences.drawing.arrow.size.width, preferences.drawing.arrow.tip.x - diff)
                }
            }
            
            if frame.x + frame.width > restrictedBounds.x + restrictedBounds.width {
                let diff = frame.x + frame.width - restrictedBounds.x - restrictedBounds.width
                newFrame.x = frame.x - diff
                if arrowPosition == .top || arrowPosition == .bottom {
                    preferences.drawing.arrow.tip.x = min(newFrame.width - preferences.drawing.arrow.size.width, preferences.drawing.arrow.tip.x + diff)
                }
            }
            
            return newFrame
        }
        
        return frame
    }
    
    fileprivate func show() {
        viewWillAppear()
        
        let viewController = UIViewController()
        viewController.view.alpha = 0
        viewController.view.addSubview(self)
        
        createWindow(with: viewController)
        addTapGesture(for: viewController)
        showWithAnimation()
    }
    
    private func createWindow(with viewController: UIViewController) {
        if #available(iOS 13.0, *) {
            if let currentWindowScene = UIApplication.shared.connectedScenes.first as?  UIWindowScene {
                self.containerWindow = UIWindow(windowScene: currentWindowScene)
            }
        } else {
            self.containerWindow = UIWindow(frame: UIScreen.main.bounds)
        }
        self.containerWindow!.rootViewController = viewController
        self.containerWindow!.windowLevel = UIWindow.Level.alert// + 1;
        self.containerWindow!.makeKeyAndVisible()
    }
    
    private func addTapGesture(for viewController: UIViewController) {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        viewController.view.addGestureRecognizer(tap)
    }
    
    private func showWithAnimation() {
        transform = preferences.animating.showInitialTransform
        alpha = preferences.animating.showInitialAlpha
        
        let frameY = self.frame.origin.y
        
        UIView.animate(withDuration: preferences.animating.showDuration,
                       delay: 0,
                       usingSpringWithDamping: preferences.animating.springDamping,
                       initialSpringVelocity: preferences.animating.springVelocity,
                       options: [.curveEaseInOut],
                       animations: {
            self.transform = self.preferences.animating.showFinalTransform
            self.alpha = 1
            self.containerWindow?.rootViewController?.view.alpha = 1
            
//            self.frame.origin.y = frameY + self.keyboardHeight
        },
                       completion: { (completed) in
            self.viewDidAppear()
        })
    }
    
    private func dismissWithAnimation() {
        self.viewWillDissapear()
        
        UIView.animate(withDuration: preferences.animating.dismissDuration, delay: 0, usingSpringWithDamping: preferences.animating.springDamping, initialSpringVelocity: preferences.animating.springVelocity, options: [.curveEaseInOut], animations: {
            self.transform = self.preferences.animating.dismissTransform
            self.alpha = self.preferences.animating.dismissFinalAlpha
            self.containerWindow?.rootViewController?.view.alpha = 0
        }) { (finished) -> Void in
            self.viewDidDisappear()
            self.removeFromSuperview()
            self.transform = CGAffineTransform.identity
            self.containerWindow?.resignKey()
            self.containerWindow = nil
        }
    }
    
    override open func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()!
        drawBackgroundLayer()
        drawBubble(context)
        drawTexts(to: context)
    }
    
    private func viewWillAppear() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardDidHide(_:)), name: UIResponder.keyboardDidHideNotification, object: nil)
        
        NotificationCenter.default.post(name: MKToolTip.toolTipWillAppearKeyNSNotification,
                                        object: nil)
    }
    
    private func viewWillDissapear() {
        NotificationCenter.default.post(name: MKToolTip.toolTipWillDissapearKeyNSNotification,
                                        object: nil)
        
        NotificationCenter.default.removeObserver(self)
    }
    
    private func viewDidAppear() {
        self.viewDidAppearDate = Date()
        self.delegate?.toolTipViewDidAppear(for: self.identifier)
    }
    
    private func viewDidDisappear() {
        let viewDidDisappearDate = Date()
        let timeInterval = viewDidDisappearDate.timeIntervalSince(self.viewDidAppearDate)
        self.delegate?.toolTipViewDidDisappear(for: self.identifier, with: timeInterval)
    }
    
    // MARK: Drawing methods
    
    private func drawBackgroundLayer() {
        if let view = self.containerWindow?.rootViewController?.view {
            let refViewFrame = presentingView.convert(presentingView.bounds, to: UIApplication.shared.keyWindow);
            let radius = refViewFrame.center.farCornerDistance()
            let frame = view.bounds
            let layer = RadialGradientBackgroundLayer(frame: frame, center: refViewFrame.center, radius: radius, locations: preferences.drawing.background.gradientLocations, colors: preferences.drawing.background.gradientColors)
            view.layer.insertSublayer(layer, at: 0)
        }
    }
    
    private func drawBubbleBorder(_ context: CGContext, path: CGMutablePath, borderColor: UIColor) {
        context.saveGState()
        context.addPath(path)
        context.setStrokeColor(borderColor.cgColor)
        context.setLineWidth(preferences.drawing.bubble.border.width)
        context.strokePath()
        context.restoreGState()
    }
    
    private func drawBubble(_ context: CGContext) {
        context.saveGState()
        let path = CGMutablePath()
        
        switch arrowPosition {
        case .top:
            let startingPoint = CGPoint(x: preferences.drawing.arrow.tip.x - preferences.drawing.arrow.size.width / 2, y: bubbleFrame.y)
            path.move(to: startingPoint)
            addTopArc(to: path)
            addLeftArc(to: path)
            addBottomArc(to: path)
            addRightArc(to: path)
            path.addLine(to: CGPoint(x: preferences.drawing.arrow.tip.x + preferences.drawing.arrow.size.width / 2, y: bubbleFrame.y))
            addArrowTipArc(with: startingPoint, to: path)
        case .right:
            let startingPoint = CGPoint(x: preferences.drawing.arrow.tip.x - preferences.drawing.arrow.size.height, y: preferences.drawing.arrow.tip.y - preferences.drawing.arrow.size.width / 2)
            path.move(to: startingPoint)
            addRightArc(to: path)
            addTopArc(to: path)
            addLeftArc(to: path)
            addBottomArc(to: path)
            path.addLine(to: CGPoint(x: preferences.drawing.arrow.tip.x - preferences.drawing.arrow.size.height, y: preferences.drawing.arrow.tip.y + preferences.drawing.arrow.size.width / 2))
            addArrowTipArc(with: startingPoint, to: path)
        case .bottom:
            let startingPoint = CGPoint(x: preferences.drawing.arrow.tip.x + preferences.drawing.arrow.size.width / 2, y: bubbleFrame.y + bubbleFrame.height)
            path.move(to: startingPoint)
            addBottomArc(to: path)
            addRightArc(to: path)
            addTopArc(to: path)
            addLeftArc(to: path)
            path.addLine(to: CGPoint(x: preferences.drawing.arrow.tip.x - preferences.drawing.arrow.size.width / 2, y: bubbleFrame.y + bubbleFrame.height))
            addArrowTipArc(with: startingPoint, to: path)
        case .left:
            let startingPoint = CGPoint(x: preferences.drawing.arrow.tip.x + preferences.drawing.arrow.size.height, y: preferences.drawing.arrow.tip.y + preferences.drawing.arrow.size.width / 2)
            path.move(to: startingPoint)
            addLeftArc(to: path)
            addBottomArc(to: path)
            addRightArc(to: path)
            addTopArc(to: path)
            path.addLine(to: CGPoint(x: preferences.drawing.arrow.tip.x + preferences.drawing.arrow.size.height, y: preferences.drawing.arrow.tip.y - preferences.drawing.arrow.size.width / 2))
            addArrowTipArc(with: startingPoint, to: path)
        }
        
        path.closeSubpath()
        
        context.addPath(path)
        context.clip()
        context.fillPath()
        context.drawLinearGradient(gradient, start: CGPoint.zero, end: CGPoint(x: 0, y: frame.height), options: [])
        context.restoreGState()
        
        if let borderColor = preferences.drawing.bubble.border.color {
            drawBubbleBorder(context, path: path, borderColor: borderColor)
        }
    }
    
    private func addTopArc(to path: CGMutablePath) {
        path.addArc(tangent1End: CGPoint(x: bubbleFrame.x, y:  bubbleFrame.y), tangent2End: CGPoint(x: bubbleFrame.x, y: bubbleFrame.y + bubbleFrame.height), radius: preferences.drawing.bubble.cornerRadius)
    }
    
    private func addRightArc(to path: CGMutablePath) {
        path.addArc(tangent1End: CGPoint(x: bubbleFrame.x + bubbleFrame.width, y: bubbleFrame.y), tangent2End: CGPoint(x: bubbleFrame.x, y: bubbleFrame.y), radius: preferences.drawing.bubble.cornerRadius)
    }
    
    private func addBottomArc(to path: CGMutablePath) {
        path.addArc(tangent1End: CGPoint(x: bubbleFrame.x + bubbleFrame.width, y: bubbleFrame.y + bubbleFrame.height), tangent2End: CGPoint(x: bubbleFrame.x + bubbleFrame.width, y: bubbleFrame.y), radius: preferences.drawing.bubble.cornerRadius)
    }
    
    private func addLeftArc(to path: CGMutablePath) {
        path.addArc(tangent1End: CGPoint(x: bubbleFrame.x, y: bubbleFrame.y + bubbleFrame.height), tangent2End: CGPoint(x: bubbleFrame.x + bubbleFrame.width, y: bubbleFrame.y + bubbleFrame.height), radius: preferences.drawing.bubble.cornerRadius)
    }
    
    private func addArrowTipArc(with startingPoint: CGPoint, to path: CGMutablePath) {
        path.addArc(tangent1End: preferences.drawing.arrow.tip, tangent2End: startingPoint, radius: preferences.drawing.arrow.tipCornerRadius)
    }
    
    private func drawTexts(to context: CGContext) {
        context.saveGState()
        
        let xOrigin = bubbleFrame.x + preferences.drawing.bubble.inset
        var yOrigin = bubbleFrame.y + preferences.drawing.bubble.inset
        
        if title != nil {
            let titleRect = CGRect(x: xOrigin, y: yOrigin, width: titleSize.width, height: titleSize.height)
            let attributes = [NSAttributedString.Key.font : preferences.drawing.title.font,
                              NSAttributedString.Key.foregroundColor : preferences.drawing.title.color,
                              NSAttributedString.Key.paragraphStyle : self.paragraphStyle]
            
            title!.draw(in: titleRect, withAttributes: attributes)
            
            yOrigin = titleRect.y + titleRect.height + preferences.drawing.bubble.spacing
        }
        
        let messageRect = CGRect(x: xOrigin,
                                 y: yOrigin,
                                 width: messageSize.width,
                                 height: messageSize.height)
        
        
        message.draw(in: messageRect, withAttributes: self.messageAttributes)
        
        if button != nil {
            yOrigin += messageRect.height + preferences.drawing.bubble.spacing
            let attributes = [NSAttributedString.Key.font : preferences.drawing.button.font,
                              NSAttributedString.Key.foregroundColor : preferences.drawing.button.color,
                              NSAttributedString.Key.paragraphStyle : self.paragraphStyle]
            let buttonRect = CGRect(x: xOrigin,
                                    y: yOrigin,
                                    width: buttonSize.width,
                                    height: buttonSize.height)
            button!.draw(in: buttonRect,
                         withAttributes: attributes)
        }
    }
    
    private var paragraphStyle: NSMutableParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
//        paragraphStyle.alignment = .left
//        paragraphStyle.lineBreakMode = NSLineBreakMode.byWordWrapping
        
        let bounds = UIScreen.main.bounds
        let tabLocation = preferredMessageSize.width - 80.0
//        paragraphStyle.defaultTabInterval = 200.0
        paragraphStyle.tabStops = [
            NSTextTab(textAlignment: .left, location: tabLocation, options: [:])
        ]
        
        return paragraphStyle
    }
    
    private var messageAttributes: [NSAttributedString.Key: Any] {
        
        let messagesAttributes = [NSAttributedString.Key.font : preferences.drawing.message.font,
                                  NSAttributedString.Key.foregroundColor : preferences.drawing.message.color,
                                  NSAttributedString.Key.paragraphStyle : self.paragraphStyle]
        
        return messagesAttributes
    }
    
    @objc internal func keyboardWillHide(_ notification: Notification?) {
        var animationCurve: UIView.AnimationOptions?
        var animationDuration: TimeInterval?
        var keyboardFrame: CGRect?
       
        let refViewFrame = presentingView.convert(presentingView.bounds,
                                                  to: UIApplication.shared.keyWindow)
        
        if let info = notification?.userInfo {

            if let kbFrame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardFrame = kbFrame
            }
            
            //  Getting keyboard animation.
            if let curve = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt {
                animationCurve = UIView.AnimationOptions(rawValue: curve).union(.beginFromCurrentState)
            } else {
                animationCurve = UIView.AnimationOptions.curveEaseOut.union(.beginFromCurrentState)
            }

            //  Getting keyboard animation duration
            animationDuration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0.25
        }
        
        var newY = self.frame(forArrowPosition: self.arrowPosition).origin.y
//        newY -= self.presentingView.frame.height
        
        UIView.animate(withDuration: animationDuration!,
                       delay: 0,
                       options: animationCurve!,
                       animations: { () -> Void in
            self.frame.y = newY
        })
    }

    @objc internal func keyboardDidHide(_ notification: Notification) {
    }
}

// MARK: RadialGradientBackgroundLayer

private class RadialGradientBackgroundLayer: CALayer {
    
    private var center: CGPoint = .zero
    private var radius: CGFloat = 0
    private var locations: [CGFloat] = [CGFloat]()
    private var colors: [UIColor] = [UIColor]()
    
    @available(*, unavailable)
    required override init(layer: Any) {
        super.init(layer: layer)
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(frame: CGRect, center: CGPoint, radius: CGFloat, locations: [CGFloat], colors: [UIColor]) {
        super.init()
        needsDisplayOnBoundsChange = true
        self.frame = frame
        self.center = center
        self.radius = radius
        self.locations = locations
        self.colors = colors
    }
    
    override func draw(in ctx: CGContext) {
        ctx.saveGState()
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = self.colors.map { $0.cgColor }
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations)
        ctx.drawRadialGradient(gradient!, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
        ctx.restoreGState()
    }
}

