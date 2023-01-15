//
//  ViewController.swift
//  ExNestedScrolling
//
//  Created by 김종권 on 2023/01/15.
//

import UIKit
import Then
import SnapKit

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
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // more, less 스크롤 방향의 기준: 새로운 콘텐츠로 스크롤링하면 more, 이전 콘텐츠로 스크롤링하면 less
        // ex) more scroll 한다는 의미: 손가락을 아래에서 위로 올려서 새로운 콘텐츠를 확인한다
        
        // less 스크롤
        let lessScroll = scrollView.panGestureRecognizer.translation(in: scrollView).y < 0
        
        // outer scroll이 스크롤 할 수 있는 최대값 (이 값을 sticky header 뷰가 있다면 그 뷰의 frame.maxY와 같은 값으로 사용해도 가능)
        let outerScrollMaxOffsetY = outerScrollView.contentSize.height - outerScrollView.frame.height
        
        if lessScroll {
            // inner scroll를 잡아서 less 스크롤하는 경우, 만약 inner scroll의 less scroll 다 했다면 outer scroll을 less 스크롤 시키기
            if scrollView == innerScrollView {
                
                // outer scroll을 제어해야하는 경우 (단, inner scroll이 parent 때문에 스크롤 되는 경우는 무시)
                guard
                    outerScrollView.contentOffset.y < outerScrollMaxOffsetY
                        && !innerScrollingDownDueToOuterScroll
                else { return }
                
                // outer scroll를 less 스크롤
                let minOffetY = min(outerScrollView.contentOffset.y + innerScrollView.contentOffset.y, outerScrollMaxOffsetY)
                let offsetY = max(minOffetY, 0)
                outerScrollView.contentOffset.y = offsetY
                
                // inner scroll은 스크롤 되지 않아야 하므로 0으로 고정
                innerScrollView.contentOffset.y = 0
            }
        } else { // more 스크롤
            if scrollView == innerScrollView {
                // inner scroll 뷰를 최대한 올린 경우, outer scroll를 올려주기
                if innerScrollView.contentOffset.y < 0 && outerScrollView.contentOffset.y > 0 {
                    outerScrollView.contentOffset.y = max(outerScrollView.contentOffset.y - abs(innerScrollView.contentOffset.y), 0)
                }
            }
            
            // outer scroll을 less 스크롤 하는데, inner scroll이 아직 less scroll이 끝나지 않은 경우, outer scroll은 maxOffsetY로 고정해놓고 inner scroll을 less scroll 시도
            if scrollView == outerScrollView {
                if innerScrollView.contentOffset.y > 0 && outerScrollView.contentOffset.y < outerScrollMaxOffsetY {
                    innerScrollingDownDueToOuterScroll = true
                    
                    // outer scroll에서 스크롤한 만큼 inner scroll에 적용
                    innerScrollView.contentOffset.y = max(innerScrollView.contentOffset.y - (outerScrollMaxOffsetY - outerScrollView.contentOffset.y), 0)
                    
                    // outer scroll은 스크롤 되지 않고 고정
                    outerScrollView.contentOffset.y = outerScrollMaxOffsetY
                    
                    innerScrollingDownDueToOuterScroll = false
                }
            }
        }
    }
}
