//
//  ImojiSDKUI
//
//  Created by Alex Hoang
//  Copyright (C) 2015 Imoji
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

import UIKit

enum IMCreateArtmojiViewSliderType: Int {
    case Color
    case BrushWidth
}

enum IMCreateArtmojiViewButtonType: Int {
    case Back
    case Cancel
    case Collection
    case Delete
    case Done
    case Draw
    case Flip
    case Undo
}

@objc public protocol IMCreateArtmojiViewDelegate {
    optional func userDidCancelCreateArtmojiView(view: IMCreateArtmojiView)
    optional func userDidFinishCreatingArtmoji(artmoji: UIImage, view: IMCreateArtmojiView)
    optional func userDidSelectImojiCollectionButtonFromArtmojiView(view: IMCreateArtmojiView)
    optional func artmojiView(view: IMCreateArtmojiView, didFinishLoadingImoji imoji: IMImojiObject)
}

public class IMCreateArtmojiView: UIView {

    // Required init properties
    public var sourceImage: UIImage!
    public var imageBundle: NSBundle
    private var session: IMImojiSession!

    // Transform variables
    private var touchCenter: CGPoint?
    private var rotationCenter: CGPoint?
    private var scaleCenter: CGPoint?
    private var lastPoint: CGPoint?

    // Artmoji Views
    private var backgroundView: UIImageView!
    private var backgroundGestureView: UIView!

    // Selected Imoji Views
    private var selectedImojiPreview: UIImageView!
    private var selectedImojis: [IMCreateArtmojiSelectedImojiView]

    private var _selectedImojiView: IMCreateArtmojiSelectedImojiView! {
        didSet {
            if _selectedImojiView != nil {
                _selectedImojiView.selected = true
                _selectedImojiView.showBorder = true

                session.renderImoji(_selectedImojiView.imoji!,
                        options: IMImojiObjectRenderingOptions(renderSize: IMImojiObjectRenderSize.Thumbnail)) { (image, error) -> Void in
                    if error == nil {
                        self.selectedImojiPreview.image = image
                        self.updateFlipImageButtonForSelectedImoji()
                    }
                }
            }

            // Hide imoji edit buttons when there isn't a selectedImoji i.e. when selectedImojis.count is 0
            flipImojiButton.hidden = selectedImojiView == nil
            selectedImojiPreview.hidden = selectedImojiView == nil
        }
    }

    private var selectedImojiView: IMCreateArtmojiSelectedImojiView! {
        get {
            return _selectedImojiView
        }
        set {
            if _selectedImojiView != newValue {
                if(_selectedImojiView != nil) {
                    _selectedImojiView.selected = false
                    _selectedImojiView.showBorder = false
                }

                _selectedImojiView = newValue
            }
        }
    }

    // Drawing
    private var brushPreview: UIImageView!
    private var drawingCanvasView: UIImageView!
    private var drawingActionsBar: IMToolbar!
    private var backButton: UIButton!
    private var undoButton: UIButton!
    private var brushSlider: UISlider!
    private var colorSlider: IMColorSlider!
    private var drawnImages: [UIImage]
    private var hue: CGFloat
    private var brushWidth: CGFloat
    private var drawing: Bool
    private var swiped: Bool

    // Top toolbar
    private var navigationBar: IMToolbar!
    private var navigationTitle: UIButton!
    private var cancelButton: UIButton!
    private var flipImojiButton: UIButton!

    // Bottom toolbar
    private var bottomBar: IMToolbar!
    private var doneButton: UIButton!
    private var imojiCollectionButton: UIButton!
    private var deleteImojiButton: UIButton!
    private var drawButton: UIButton!
    
    public var photoExtension: Bool? {
        didSet {
            cancelButton.hidden = photoExtension ?? false
            doneButton.hidden = photoExtension ?? false
        }
    }

    // Delegate object
    public var delegate: IMCreateArtmojiViewDelegate?

    // MARK: - Object lifecycle
    public init(session: IMImojiSession, sourceImage: UIImage, imageBundle: NSBundle) {
        self.session = session
        self.sourceImage = sourceImage
        self.imageBundle = imageBundle

        selectedImojis = [IMCreateArtmojiSelectedImojiView]()

        // Drawing
        drawnImages = [UIImage]()
        drawing = false
        swiped = false
        hue = 0
        brushWidth = 10.0

        super.init(frame: CGRectZero)

        setup()
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View lifecycle
    func setup() {
        backgroundColor = UIColor(red: 48.0 / 255.0, green: 48.0 / 255.0, blue: 48.0 / 255.0, alpha: 1.0)

        // Set up navigationBar buttons
        let buttonItemFrame = CGRectMake(0, 0, IMArtmojiConstants.ButtonItemWidthHeight, IMArtmojiConstants.ButtonItemWidthHeight)
        cancelButton = UIButton(type: UIButtonType.Custom)
        cancelButton.setImage(UIImage(named: "Artmoji-Cancel"), forState: UIControlState.Normal)
        cancelButton.addTarget(self, action: "toolbarButtonTapped:", forControlEvents: UIControlEvents.TouchUpInside)
        cancelButton.tag = IMCreateArtmojiViewButtonType.Cancel.rawValue
        cancelButton.frame = buttonItemFrame

        drawButton = UIButton(type: UIButtonType.Custom)
        drawButton.setImage(UIImage(named: "Artmoji-Draw"), forState: UIControlState.Normal)
        drawButton.addTarget(self, action: "toolbarButtonTapped:", forControlEvents: UIControlEvents.TouchUpInside)
        drawButton.tag = IMCreateArtmojiViewButtonType.Draw.rawValue
        drawButton.frame = buttonItemFrame

        flipImojiButton = UIButton(type: UIButtonType.Custom)
        flipImojiButton.setImage(UIImage(named: "Artmoji-Flip-Imoji"), forState: UIControlState.Normal)
        flipImojiButton.addTarget(self, action: "toolbarButtonTapped:", forControlEvents: UIControlEvents.TouchUpInside)
        flipImojiButton.tag = IMCreateArtmojiViewButtonType.Flip.rawValue
        flipImojiButton.frame = buttonItemFrame
        flipImojiButton.hidden = true

        // Preview of currently selected imoji
        selectedImojiPreview = UIImageView(frame: buttonItemFrame)
        selectedImojiPreview.contentMode = UIViewContentMode.ScaleAspectFit
        selectedImojiPreview.hidden = true

        // Set up bottomBar buttons
        deleteImojiButton = UIButton(type: UIButtonType.Custom)
        deleteImojiButton.setImage(UIImage(named: "Artmoji-Delete-Imoji"), forState: UIControlState.Normal)
        deleteImojiButton.addTarget(self, action: "toolbarButtonTapped:", forControlEvents: UIControlEvents.TouchUpInside)
        deleteImojiButton.tag = IMCreateArtmojiViewButtonType.Delete.rawValue
        deleteImojiButton.frame = buttonItemFrame

        doneButton = UIButton(type: UIButtonType.Custom)
        doneButton.setImage(IMCreateImojiUITheme().trimScreenFinishTraceButtonImage, forState: UIControlState.Normal)
        doneButton.addTarget(self, action: "toolbarButtonTapped:", forControlEvents: UIControlEvents.TouchUpInside)
        doneButton.tag = IMCreateArtmojiViewButtonType.Done.rawValue
        doneButton.frame = buttonItemFrame

        imojiCollectionButton = UIButton(type: UIButtonType.Custom)
        imojiCollectionButton.setImage(UIImage(named: "toolbar_reactions_on", inBundle: imageBundle, compatibleWithTraitCollection: nil), forState: UIControlState.Normal)
        imojiCollectionButton.addTarget(self, action: "toolbarButtonTapped:", forControlEvents: UIControlEvents.TouchUpInside)
        imojiCollectionButton.tag = IMCreateArtmojiViewButtonType.Collection.rawValue
        imojiCollectionButton.frame = buttonItemFrame

        // Set up drawingActionsBar buttons
        backButton = UIButton(type: UIButtonType.Custom)
        backButton.setImage(IMCreateImojiUITheme().tagScreenBackButtonImage, forState: UIControlState.Normal)
        backButton.addTarget(self, action: "toolbarButtonTapped:", forControlEvents: UIControlEvents.TouchUpInside)
        backButton.tag = IMCreateArtmojiViewButtonType.Back.rawValue
        backButton.frame = buttonItemFrame

        undoButton = UIButton(type: UIButtonType.Custom)
        undoButton.setImage(IMCreateImojiUITheme().trimScreenUndoButtonImage, forState: UIControlState.Normal)
        undoButton.addTarget(self, action: "toolbarButtonTapped:", forControlEvents: UIControlEvents.TouchUpInside)
        undoButton.tag = IMCreateArtmojiViewButtonType.Undo.rawValue
        undoButton.frame = buttonItemFrame

        brushPreview = UIImageView(frame: buttonItemFrame)

        // Set up navigationBar
        navigationBar = IMToolbar()
        navigationBar.clipsToBounds = true
        navigationBar.setBackgroundImage(UIImage(), forToolbarPosition: UIBarPosition.Any, barMetrics: UIBarMetrics.Default)
        navigationBar.tintColor = UIColor.whiteColor()
        navigationBar.barTintColor = UIColor.clearColor()

        navigationBar.addBarButton(UIBarButtonItem(customView: cancelButton))
        navigationBar.addFlexibleSpace()
        navigationBar.addBarButton(UIBarButtonItem(customView: flipImojiButton))
        navigationBar.addFlexibleSpace()
        navigationBar.addBarButton(UIBarButtonItem(customView: selectedImojiPreview))
        navigationBar.addFlexibleSpace()
        navigationBar.addBarButton(UIBarButtonItem(customView: drawButton))

        // Set up bottomBar
        bottomBar = IMToolbar()
        bottomBar.clipsToBounds = true
        bottomBar.setBackgroundImage(UIImage(), forToolbarPosition: UIBarPosition.Any, barMetrics: UIBarMetrics.Default)
        bottomBar.barTintColor = UIColor.clearColor()

        bottomBar.addBarButton(UIBarButtonItem(customView: deleteImojiButton))
        bottomBar.addFlexibleSpace()
        bottomBar.addBarButton(UIBarButtonItem(customView: doneButton))
        bottomBar.addFlexibleSpace()
        bottomBar.addBarButton(UIBarButtonItem(customView: imojiCollectionButton))

        // Set up drawingActionsBar
        drawingActionsBar = IMToolbar()
        drawingActionsBar.clipsToBounds = true
        drawingActionsBar.setBackgroundImage(UIImage(), forToolbarPosition: UIBarPosition.Any, barMetrics: UIBarMetrics.Default)
        drawingActionsBar.barTintColor = UIColor.clearColor()

        drawingActionsBar.addBarButton(UIBarButtonItem(customView: backButton))
        drawingActionsBar.addFlexibleSpace()
        drawingActionsBar.addBarButton(UIBarButtonItem(customView: undoButton))
        drawingActionsBar.addBarButton(UIBarButtonItem(customView: brushPreview))
        drawingActionsBar.hidden = true

        // Artmoji view
        backgroundView = UIImageView(image: sourceImage)
        backgroundView.contentMode = UIViewContentMode.ScaleAspectFill
        backgroundView.userInteractionEnabled = true

        // Background gestures
        backgroundGestureView = UIView()
        backgroundGestureView.userInteractionEnabled = true

        // Drawing view
        drawingCanvasView = UIImageView()

        brushSlider = UISlider()
        brushSlider.minimumValue = 1.0
        brushSlider.maximumValue = 40.0
        brushSlider.value = Float(brushWidth)
        brushSlider.transform = CGAffineTransformMakeRotation(CGFloat(M_PI_2))
        brushSlider.addTarget(self, action: "sliderValueChanged:", forControlEvents: UIControlEvents.ValueChanged)
        brushSlider.tag = IMCreateArtmojiViewSliderType.BrushWidth.rawValue
        brushSlider.hidden = true

        colorSlider = IMColorSlider()
        colorSlider.addTarget(self, action: "sliderValueChanged:", forControlEvents: UIControlEvents.ValueChanged)
        colorSlider.tag = IMCreateArtmojiViewSliderType.Color.rawValue
        colorSlider.vertical = true
        colorSlider.hidden = true

        // Add subviews
        addSubview(backgroundView)
        addSubview(backgroundGestureView)
        addSubview(drawingCanvasView)
        addSubview(drawingActionsBar)
        addSubview(brushSlider)
        addSubview(colorSlider)
        addSubview(navigationBar)
        addSubview(bottomBar)

        // Constraints
        backgroundView.mas_makeConstraints { make in
            make.edges.equalTo()(self)
        }

        backgroundGestureView.mas_makeConstraints { make in
            make.edges.equalTo()(self)
        }

        drawingCanvasView.mas_makeConstraints { make in
            make.edges.equalTo()(self)
        }

        navigationBar.mas_makeConstraints { make in
            make.top.equalTo()(self)
            make.left.equalTo()(self)
            make.right.equalTo()(self)
            make.height.equalTo()(IMArtmojiConstants.NavigationBarHeight)
        }

        bottomBar.mas_makeConstraints { make in
            make.bottom.equalTo()(self)
            make.left.equalTo()(self)
            make.right.equalTo()(self)
            make.height.equalTo()(IMArtmojiConstants.BottomBarHeight)
        }

        drawingActionsBar.mas_makeConstraints { make in
            make.top.equalTo()(self)
            make.left.equalTo()(self)
            make.right.equalTo()(self)
            make.height.equalTo()(IMArtmojiConstants.NavigationBarHeight)
        }

        colorSlider.mas_makeConstraints { make in
            make.top.equalTo()(self.drawingActionsBar.mas_bottom).offset()(75)
            make.right.equalTo()(self).offset()(50)
            make.width.equalTo()(IMArtmojiConstants.SliderWidth)
        }

        brushSlider.mas_makeConstraints { make in
            make.top.equalTo()(self.colorSlider.mas_bottom).offset()(CGFloat(IMArtmojiConstants.SliderWidth))
            make.right.equalTo()(self).offset()(50)
            make.width.equalTo()(IMArtmojiConstants.SliderWidth)
        }

        setupGestureRecognizers()
    }

    func setupGestureRecognizers() {
        let panRecognizer = UIPanGestureRecognizer(target: self, action: "imojiPanned:")
        panRecognizer.cancelsTouchesInView = false
        panRecognizer.delegate = self

        let rotationRecognizer = UIRotationGestureRecognizer(target: self, action: "imojiRotated:")
        rotationRecognizer.cancelsTouchesInView = false
        rotationRecognizer.delegate = self

        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: "imojiPinched:")
        pinchRecognizer.cancelsTouchesInView = false
        pinchRecognizer.delegate = self

        backgroundGestureView.addGestureRecognizer(panRecognizer)
        backgroundGestureView.addGestureRecognizer(rotationRecognizer)
        backgroundGestureView.addGestureRecognizer(pinchRecognizer)
    }

    // MARK: - Artmoji editor button logic
    func toolbarButtonTapped(sender: UIButton) {
        switch sender.tag {
            case IMCreateArtmojiViewButtonType.Back.rawValue, IMCreateArtmojiViewButtonType.Draw.rawValue:
                lastPoint = CGPointZero

                // Set to drawing mode
                drawing = !drawing

                // Show/Hide toolbars/sliders
                brushSlider.hidden = !drawing
                colorSlider.hidden = !drawing
                drawingActionsBar.hidden = !drawing
                navigationBar.hidden = drawing
                bottomBar.hidden = drawing

                // Show/Hide the background gesture view to avoid manipulating both the brush and the imoji
                backgroundGestureView.hidden = drawing

                for imoji in selectedImojis {
                    imoji.userInteractionEnabled = !drawing
                }

                if brushPreview.image == nil {
                    drawBrushPreview()
                }
                break
            case IMCreateArtmojiViewButtonType.Cancel.rawValue:
                delegate?.userDidCancelCreateArtmojiView?(self)
                break
            case IMCreateArtmojiViewButtonType.Collection.rawValue:
                delegate?.userDidSelectImojiCollectionButtonFromArtmojiView?(self)
                break
            case IMCreateArtmojiViewButtonType.Delete.rawValue:
                if selectedImojiView != nil {
                    selectedImojiView.removeFromSuperview()

                    let index = selectedImojis.indexOf(selectedImojiView)!
                    selectedImojis.removeAtIndex(index)
                    selectedImojiView = selectedImojis.last
                }
                break
            case IMCreateArtmojiViewButtonType.Done.rawValue:
                let image = drawCompositionImage()
                delegate?.userDidFinishCreatingArtmoji?(image, view: self)
                break
            case IMCreateArtmojiViewButtonType.Flip.rawValue:
                if selectedImojiView != nil {
                    selectedImojiView.flipHorizontal()
                    updateFlipImageButtonForSelectedImoji()
                }
                break
            case IMCreateArtmojiViewButtonType.Undo.rawValue:
                drawnImages.popLast()
                drawingCanvasView.image = drawnImages.last
                break
            default:
                break
        }
    }

    func updateFlipImageButtonForSelectedImoji() {
        var image = UIImage(named: "Artmoji-Flip-Imoji")!
        if selectedImojiView.flipped {
            UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
            let context = UIGraphicsGetCurrentContext()

            CGContextTranslateCTM(context, image.size.width, 0)
            CGContextScaleCTM(context, -1, 1)
            image.drawInRect(CGRectMake(0, 0, image.size.width, image.size.height))

            image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
        }

        flipImojiButton.setImage(image, forState: UIControlState.Normal)
    }

    // MARK: - Drawing slider logic
    func sliderValueChanged(sender: UISlider) {
        switch sender.tag {
            case IMCreateArtmojiViewSliderType.BrushWidth.rawValue:
                brushWidth = CGFloat(sender.value)
                break
            case IMCreateArtmojiViewSliderType.Color.rawValue:
                hue = CGFloat(sender.value)
                break
            default:
                break
        }

        drawBrushPreview()
    }

    // MARK: - Touch overrides
    func handleTouches(touches: Set<UITouch>) {
        self.touchCenter = CGPointZero
        if touches.count < 2 {
            return
        }

        for touch in touches {
            let viewForGesture = selectedImojiView ?? touch.view
            let touchLocation = touch.locationInView(viewForGesture)
            self.touchCenter = CGPointMake(self.touchCenter!.x + touchLocation.x, self.touchCenter!.y + touchLocation.y)
        }

        self.touchCenter = CGPointMake(self.touchCenter!.x / CGFloat(touches.count), self.touchCenter!.y / CGFloat(touches.count))
    }

    override public func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if drawing {
            swiped = false
            if let touch = touches.first {
                lastPoint = touch.locationInView(self)
            }
        } else {
            handleTouches(event!.allTouches()!)
        }
    }

    override public func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if drawing {
            swiped = true
            if let touch = touches.first {
                let currentPoint = touch.locationInView(self)
                drawLine(lastPoint!, toPoint: currentPoint)
                lastPoint = currentPoint
            }
        } else {
            handleTouches(event!.allTouches()!)
        }
    }

    override public func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if drawing {
            if !swiped {
                drawLine(lastPoint!, toPoint: lastPoint!)
            }

            drawnImages.append(drawingCanvasView.image!)
        } else {
            handleTouches(event!.allTouches()!)
        }
    }

    // MARK: - Gestures
    func imojiTapped(recognizer: UITapGestureRecognizer) {
        if recognizer.view!.isKindOfClass(IMCreateArtmojiSelectedImojiView) {
            insertSubview(recognizer.view!, belowSubview: navigationBar)
            selectedImojiView = recognizer.view as! IMCreateArtmojiSelectedImojiView
        }
    }

    func imojiPanned(recognizer: UIPanGestureRecognizer) {
        // when the user pans an imoji they are selecting it for editing
        if recognizer.view!.isKindOfClass(IMCreateArtmojiSelectedImojiView) {
            insertSubview(recognizer.view!, belowSubview: navigationBar)
            selectedImojiView = recognizer.view as! IMCreateArtmojiSelectedImojiView
        }

        if let viewForGesture = selectedImojiView {
            let translation = recognizer.translationInView(viewForGesture)
            let transform = CGAffineTransformTranslate(viewForGesture.transform, translation.x, translation.y)
            viewForGesture.transform = transform
            recognizer.setTranslation(CGPointZero, inView: viewForGesture)
        }
    }

    func imojiRotated(recognizer: UIRotationGestureRecognizer) {
        if let viewForGesture = selectedImojiView {
            if recognizer.state == UIGestureRecognizerState.Began {
                self.rotationCenter = self.touchCenter
            }

            let deltaX = self.rotationCenter!.x - viewForGesture.bounds.size.width / 2
            let deltaY = self.rotationCenter!.y - viewForGesture.bounds.size.height / 2

            var transform = CGAffineTransformTranslate(viewForGesture.transform, deltaX, deltaY)
            transform = CGAffineTransformRotate(transform, recognizer.rotation)
            transform = CGAffineTransformTranslate(transform, -deltaX, -deltaY)
            viewForGesture.transform = transform
            recognizer.rotation = 0
        }
    }

    func imojiPinched(recognizer: UIPinchGestureRecognizer) {
        if let viewForGesture = selectedImojiView {
            if recognizer.state == UIGestureRecognizerState.Began {
                self.scaleCenter = self.touchCenter
            }

            let deltaX = self.scaleCenter!.x - viewForGesture.bounds.size.width / 2.0
            let deltaY = self.scaleCenter!.y - viewForGesture.bounds.size.height / 2.0

            var transform = CGAffineTransformTranslate(viewForGesture.transform, deltaX, deltaY)
            transform = CGAffineTransformScale(transform, recognizer.scale, recognizer.scale)
            transform = CGAffineTransformTranslate(transform, -deltaX, -deltaY)
            viewForGesture.transform = transform

            recognizer.scale = 1
        }
    }

    // MARK: - Image & Imoji logic
    func addImoji(imoji: IMImojiObject) {
        let selectedImojiView = IMCreateArtmojiSelectedImojiView(imoji: imoji, session: self.session)

        if selectedImojis.count == 0 {
            insertSubview(selectedImojiView, aboveSubview: backgroundGestureView)
        } else {
            insertSubview(selectedImojiView, aboveSubview: selectedImojis.last!)
        }

        self.selectedImojiView = selectedImojiView

        let panRecognizer = UIPanGestureRecognizer(target: self, action: "imojiPanned:")
        panRecognizer.cancelsTouchesInView = false
        panRecognizer.delegate = self

        let rotationRecognizer = UIRotationGestureRecognizer(target: self, action: "imojiRotated:")
        rotationRecognizer.cancelsTouchesInView = false
        rotationRecognizer.delegate = self

        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: "imojiPinched:")
        pinchRecognizer.cancelsTouchesInView = false
        pinchRecognizer.delegate = self

        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: "imojiTapped:")
        tapGestureRecognizer.cancelsTouchesInView = false
        tapGestureRecognizer.delegate = self

        selectedImojiView.userInteractionEnabled = true
        selectedImojiView.addGestureRecognizer(panRecognizer)
        selectedImojiView.addGestureRecognizer(rotationRecognizer)
        selectedImojiView.addGestureRecognizer(pinchRecognizer)
        selectedImojiView.addGestureRecognizer(tapGestureRecognizer)

        selectedImojis.append(selectedImojiView)

        delegate?.artmojiView?(self, didFinishLoadingImoji: imoji)
    }

    func drawCompositionImage() -> UIImage {
        let imageSize = CGSizeMake(backgroundView.bounds.size.width, backgroundView.bounds.size.height)
        UIGraphicsBeginImageContextWithOptions(imageSize, false, 0.0)
        let context = UIGraphicsGetCurrentContext()

        // Save background image
        CGContextSaveGState(context)
        CGContextTranslateCTM(context, backgroundView.center.x, backgroundView.center.y)
        CGContextConcatCTM(context, backgroundView.transform)
        CGContextTranslateCTM(context,
                -backgroundView.bounds.size.width * backgroundView.layer.anchorPoint.x,
                -backgroundView.bounds.size.height * backgroundView.layer.anchorPoint.y)
        backgroundView.layer.renderInContext(context!)
        CGContextRestoreGState(context)

        // Save all imojis added to the backgroundView
        for imoji in selectedImojis {
            CGContextSaveGState(context)
            CGContextTranslateCTM(context, imoji.center.x, imoji.center.y)
            CGContextConcatCTM(context, imoji.transform)
            CGContextTranslateCTM(context, -imoji.bounds.size.width * imoji.layer.anchorPoint.x, -imoji.bounds.size.height * imoji.layer.anchorPoint.y)
            imoji.layer.renderInContext(context!)
            CGContextRestoreGState(context)
        }

        // Save drawing
        CGContextSaveGState(context)
        CGContextTranslateCTM(context, drawingCanvasView.center.x, drawingCanvasView.center.y)
        CGContextConcatCTM(context, drawingCanvasView.transform)
        CGContextTranslateCTM(context,
                -drawingCanvasView.bounds.size.width * drawingCanvasView.layer.anchorPoint.x,
                -drawingCanvasView.bounds.size.height * drawingCanvasView.layer.anchorPoint.y)
        drawingCanvasView.layer.renderInContext(context!)
        CGContextRestoreGState(context)


        let watermarkImage = UIImage(named:"Artmoji-Share-Watermark")!
        watermarkImage.drawInRect(CGRectMake(imageSize.width - watermarkImage.size.width, imageSize.height - watermarkImage.size.height, watermarkImage.size.width, watermarkImage.size.height))

        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img
    }

    func drawLine(fromPoint: CGPoint, toPoint: CGPoint) {
        UIGraphicsBeginImageContext(frame.size)
        let context = UIGraphicsGetCurrentContext()
        drawingCanvasView.image?.drawInRect(CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height))

        CGContextMoveToPoint(context, fromPoint.x, fromPoint.y)
        CGContextAddLineToPoint(context, toPoint.x, toPoint.y)
        CGContextSetLineCap(context, CGLineCap.Round)
        CGContextSetLineWidth(context, brushWidth)
        CGContextSetStrokeColorWithColor(context, UIColor(hue: self.hue, saturation: 1.0, brightness: 1.0, alpha: 1.0).CGColor)
        CGContextSetBlendMode(context, CGBlendMode.Normal)
        CGContextStrokePath(context)

        drawingCanvasView.image = UIGraphicsGetImageFromCurrentImageContext()
        drawingCanvasView.alpha = 1.0
        UIGraphicsEndImageContext()
    }

    // Renders the current color and size of the brush
    func drawBrushPreview() {
        UIGraphicsBeginImageContext(brushPreview.frame.size)
        let context = UIGraphicsGetCurrentContext()

        CGContextMoveToPoint(context, 20.0, 20.0)
        CGContextAddLineToPoint(context, 20.0, 20.0)
        CGContextSetLineCap(context, CGLineCap.Round)
        CGContextSetLineWidth(context, brushWidth)
        CGContextSetStrokeColorWithColor(context, UIColor(hue: self.hue, saturation: 1.0, brightness: 1.0, alpha: 1.0).CGColor)
        CGContextStrokePath(context)

        brushPreview.image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
    }
}

// MARK: - UIGestureRecognizerDelegate
extension IMCreateArtmojiView: UIGestureRecognizerDelegate {
    public func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}