//
//  ScrollViews.swift
//  ExNestedScrolling
//
//  Created by 김종권 on 2023/01/15.
//

import UIKit

/**
 UIScrollView's default panGesture is disabled.
 */
class ScrollDisabledScrollView: UIScrollView {
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let result = super.gestureRecognizerShouldBegin(gestureRecognizer)
        
        if gestureRecognizer === panGestureRecognizer{
            return false
        }
        
        return result
    }
}

/**
 Main outer scrollview managing a single inner scrollview
 */
final class OuterScroll: ScrollDisabledScrollView{
    
    enum Reference{
        /// Static reference to the inner (nested) scrollview
        static weak var iScroll: InnerScroll?
    }
    
    /// Stores Y Content Offsets for outer and inner scrollview
    private struct FinalOffsetCalculation{
        var outerFinalOffset: CGFloat
        var innerFinalOffset: CGFloat
        init(_ outer: CGFloat, _ inner: CGFloat){
            self.outerFinalOffset = outer
            self.innerFinalOffset = inner
        }
        
        static func current(_ outer: UIScrollView) -> FinalOffsetCalculation{
            return FinalOffsetCalculation(
                outer.contentOffset.y,
                Reference.iScroll!.contentOffset.y
            )
        }
    }
    
    private var initialContentOffset: CGPoint = CGPoint(x: 0, y: 0)
    private var initialChildContentOffset: CGPoint = CGPoint(x: 0, y: 0)
    /// If true, outer scroll view is not scrolled.
    private var innerScrollLock: Bool = false
    private var animator = ScrollViewScrollAnimator()
    
    private weak var customPan: UIPanGestureRecognizer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        internalInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        internalInit()
    }
    
    private func internalInit(){
        setupOwnPanGesture()
    }
    
    private func setupOwnPanGesture(){
        let pan = UIPanGestureRecognizer(target: self, action: #selector(customPanGesturePanned(_:)))
        self.addGestureRecognizer(pan)
        
        self.customPan = pan
    }
    
    @objc private func customPanGesturePanned(_ sender: UIPanGestureRecognizer){
        let translation = sender.translation(in: self)
        let velocity = sender.velocity(in: self)
        
        switch(sender.state){
        case .began:
            animator.stop()
            updateInitials()
            handleContentOffset(translation.y)
            
        case .changed:
            handleContentOffset(translation.y)
            
        case .cancelled:
            handleContentOffset(translation.y)
            animateVelocity(translation, velocity)
            
        case .ended:
            handleContentOffset(translation.y)
            animateVelocity(translation, velocity)
        default:
            break;
            
        }
    }
    
    private func updateInitials(){
        guard let iScroll = Reference.iScroll else { return }
        initialContentOffset = contentOffset
        initialChildContentOffset = iScroll.contentOffset
    }
    
    private func animateVelocity(_ translation: CGPoint, _ velocity: CGPoint){
        guard let iScroll = Reference.iScroll else { return }
        
        let deceleration = decelerationRate.rawValue * 1000.0
        let sign = translation.y / abs(translation.y)
        
        // print("animateVelocity:", "Deceleration rate =", deceleration)
        
        
        updateInitials()
        animator.start(sign / abs(sign), velocity, deceleration) { [weak self] (newTranslation, animator) in
            guard let s = self else { return }
            
            s.handleContentOffset(newTranslation)
            
            if s.contentOffset.y <= 0{
                animator.stop()
            }
            else if iScroll.contentOffset.y >= iScroll.contentSize.height - iScroll.frame.height{
                animator.stop()
            }
        }
    }
    
    /**
     Calculate the contentOffset changes for __BOTH__ scrollviews
     by using a given pan gesture translation.
     */
    private func calculateContentOffset(_ translation: CGFloat) -> FinalOffsetCalculation{
        guard let iScroll = Reference.iScroll else { fatalError() }
        
        // invert value so that it can be used as content offset
        let t = -translation
        let iOffset = initialContentOffset.y
        let newContentOffset = iOffset + t + initialChildContentOffset.y
        
        var forceHandleScrollUp: Bool = false
        
        var result = FinalOffsetCalculation(contentOffset.y, iScroll.contentOffset.y)
        
        if contentOffset.y >= iScroll.frame.minY || innerScrollLock{
            let relativeOffset = max(0, newContentOffset - iScroll.frame.minY)
            let clamped = min(relativeOffset, iScroll.contentSize.height - iScroll.frame.height)
            
            result.innerFinalOffset = clamped
            
            innerScrollLock = true
            
            if relativeOffset <= 0{
                innerScrollLock = false
                forceHandleScrollUp = true
            }
        }
        
        
        if (contentOffset.y < iScroll.frame.minY && !innerScrollLock) || forceHandleScrollUp {
            let actualOffset = newContentOffset/* + dampening*/
            let clamped = min(max(actualOffset, 0), contentSize.height - frame.height)
            let clamped2 = min(clamped, iScroll.frame.minY)
            result.outerFinalOffset = clamped2
        }
        
        return result
    }
    
    private func handleContentOffset(_ translation: CGFloat){
        // print("handleContentOffset inputTranslation = \(-translation)")
        
        let calculation = calculateContentOffset(translation)
        
        contentOffset = CGPoint(x: 0, y: calculation.outerFinalOffset)
        Reference.iScroll?.contentOffset = CGPoint(x: 0, y: calculation.innerFinalOffset)
    }
}

final class InnerScroll: ScrollDisabledScrollView{}

/**
 This class animates the scroll after the user
 lifts their finger up.
 */
final fileprivate class ScrollViewScrollAnimator{
    
    typealias Handler = ((_ translation: CGFloat, _ animator: ScrollViewScrollAnimator) -> Void)
    
    private var link: CADisplayLink!
    private var startTime: TimeInterval!
    
    private var sign: CGFloat = 1.0
    private var startVelocity: CGPoint = .zero
    private var deceleration: CGFloat = .zero
    private var handler: Handler? = nil
    
    init(){}
    
    func start(_ sign: CGFloat, _ startVelocity: CGPoint, _ deceleration: CGFloat, _ handler: @escaping Handler){
        self.sign = sign
        self.startVelocity = startVelocity
        self.deceleration = deceleration
        self.handler = handler
        
        self.startTime = CACurrentMediaTime()
        
        link = CADisplayLink(target: self, selector: #selector(linkTicked))
        link!.add(to: .main, forMode: .common)
    }
    
    func stop(){
        link?.invalidate()
        link = nil
    }
    
    @objc private func linkTicked(){
        // v = u + at AND s = ut + ½at²
        let t = CGFloat(CACurrentMediaTime() - self.startTime)
        let unsignedNextVelocity = abs(startVelocity.y) - deceleration * t
        let unsignedDisplacement = abs(startVelocity.y * t) - (0.5 * deceleration * pow(t, 2.0))
        let signedDisplacement = sign * unsignedDisplacement
        
        handler?(signedDisplacement, self)
        
        if (unsignedDisplacement <= 0.0 || unsignedNextVelocity <= 0.0) && link != nil{
            stop()
        }
    }
    
}

