//
//  ViewController.swift
//  ExNestedScrolling
//
//  Created by 김종권 on 2023/01/15.
//

import UIKit
import Then
import SnapKit
import RxSwift
import RxCocoa

class ViewController: UIViewController {
    private let outerScrollView = UIScrollView()
    private let stackView = UIStackView().then {
        $0.axis = .vertical
        $0.spacing = 20
    }
    private let headerView = UIView().then {
        $0.backgroundColor = .systemGreen
    }
    private let titleLabel = UILabel().then {
        $0.numberOfLines = 0
        $0.font = .systemFont(ofSize: 22, weight: .regular)
        $0.textColor = .black
        $0.text = text1
    }
    private let tableView = UITableView(frame: .zero).then {
        $0.allowsSelection = false
        $0.backgroundColor = UIColor.clear
        $0.bounces = true
        $0.showsVerticalScrollIndicator = true
        $0.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }
    var innerScrollView: UIScrollView {
        tableView
    }
    
    let items = (0...31).map(String.init)
    var innerScrollingDownDueToOuterScroll = false
    private let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(outerScrollView)
        outerScrollView.addSubview(stackView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(tableView)
        
        outerScrollView.snp.makeConstraints {
            $0.edges.equalTo(view.safeAreaLayoutGuide)
        }
        stackView.snp.makeConstraints {
            $0.edges.width.equalToSuperview()
        }
        tableView.snp.makeConstraints {
            $0.height.equalTo(400)
        }
        
        outerScrollView.delegate = self
        tableView.delegate = self
        tableView.dataSource = self
    }
}

extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = "#\(indexPath.row)"
        cell.detailTextLabel?.text = items[indexPath.row]
        return cell
    }
}

extension ViewController: UITableViewDelegate {
    private enum Policy {
        static let velocityConstant = 1.5
        static let floatingPointTolerance = 0.1
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // more, less 스크롤 방향의 기준: 새로운 콘텐츠로 스크롤링하면 more, 이전 콘텐츠로 스크롤링하면 less
        // ex) more scroll 한다는 의미: 손가락을 아래에서 위로 올려서 새로운 콘텐츠를 확인한다
        
        let outerScroll = outerScrollView == scrollView
        let innerScroll = !outerScroll
        let moreScroll = scrollView.panGestureRecognizer.translation(in: scrollView).y < 0
        let lessScroll = !moreScroll
        
        // outer scroll이 스크롤 할 수 있는 최대값 (이 값을 sticky header 뷰가 있다면 그 뷰의 frame.maxY와 같은 값으로 사용해도 가능)
        let outerScrollMaxOffsetY = outerScrollView.contentSize.height - outerScrollView.frame.height
        
        // 1. outer scroll을 more 스크롤
        // 만약 outer scroll을 more scroll 다 했으면, child scroll을 more scroll
        if outerScroll && moreScroll {
            guard outerScrollMaxOffsetY < outerScrollView.contentOffset.y + Policy.floatingPointTolerance else { return }
            innerScrollingDownDueToOuterScroll = true
            
            innerScrollView.contentOffset.y = innerScrollView.contentOffset.y + outerScrollView.contentOffset.y - outerScrollMaxOffsetY
            outerScrollView.contentOffset.y = outerScrollMaxOffsetY
            
            innerScrollingDownDueToOuterScroll = false
        }
        
        // 2. outer scroll을 less 스크롤
        // 만약 inner scroll이 less 스크롤 할게 남아 있다면 inner scroll을 less 스크롤
        if outerScroll && lessScroll {
            guard innerScrollView.contentOffset.y > 0 && outerScrollView.contentOffset.y < outerScrollMaxOffsetY else { return }
            innerScrollingDownDueToOuterScroll = true
            
            // outer scroll에서 스크롤한 만큼 inner scroll에 적용
            innerScrollView.contentOffset.y = max(innerScrollView.contentOffset.y - (outerScrollMaxOffsetY - outerScrollView.contentOffset.y), 0)
            
            // outer scroll은 스크롤 되지 않고 고정
            outerScrollView.contentOffset.y = outerScrollMaxOffsetY
            
            innerScrollingDownDueToOuterScroll = false
        }
        
        // 3. inner scroll을 less 스크롤
        // inner scroll을 모두 less scroll한 경우, outer scroll을 less scroll
        if innerScroll && lessScroll {
            defer { innerScrollView.lastOffsetY = innerScrollView.contentOffset.y }
            guard innerScrollView.contentOffset.y < 0 && outerScrollView.contentOffset.y > 0 else { return }
            
            // innerScrollView의 bounces에 의하여 다시 outerScrollView가 당겨질수 있으므로 bounces로 다시 되돌아가는 offset 방지
            guard innerScrollView.lastOffsetY > innerScrollView.contentOffset.y else { return }
            let moveOffset = outerScrollMaxOffsetY - abs(innerScrollView.contentOffset.y) * Policy.velocityConstant
            outerScrollView.contentOffset.y = max(moveOffset, 0)
        }
        
        // 4. inner scroll을 more 스크롤
        // outer scroll이 아직 more 스크롤할게 남아 있다면, innerScroll을 그대로 두고 outer scroll을 more 스크롤
        if innerScroll && moreScroll {
            guard
                outerScrollView.contentOffset.y + Policy.floatingPointTolerance < outerScrollMaxOffsetY,
                !innerScrollingDownDueToOuterScroll
            else { return }
            // outer scroll를 more 스크롤
            let minOffetY = min(outerScrollView.contentOffset.y + innerScrollView.contentOffset.y, outerScrollMaxOffsetY)
            let offsetY = max(minOffetY, 0)
            outerScrollView.contentOffset.y = offsetY
            
            // inner scroll은 스크롤 되지 않아야 하므로 0으로 고정
            innerScrollView.contentOffset.y = 0
        }
    }
}

private struct AssociatedKeys {
    static var lastOffsetY = "lastOffsetY"
}

extension UIScrollView {
    var lastOffsetY: CGFloat {
        get {
            (objc_getAssociatedObject(self, &AssociatedKeys.lastOffsetY) as? CGFloat) ?? contentOffset.y
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.lastOffsetY, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
