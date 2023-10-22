import UIKit

class DatePickerView: UIView, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    private var days: [Day] = []
    private let collectionView: UICollectionView
    private let layout: UICollectionViewFlowLayout
    private var selectedDate: Date?
    
    private let monthLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = UIFont.boldSystemFont(ofSize: 18)
        return label
    }()
    
    private let separatorLine: UIView = {
        let view = UIView()
        view.backgroundColor = .gray
        return view
    }()

    
    override init(frame: CGRect) {
        layout = UICollectionViewFlowLayout()
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)
        
        collectionView.register(WeekdaysHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "WeekdaysHeaderViewID")
        
        setupCollectionView()
        setupCalendar()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCollectionView() {
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(DateCell.self, forCellWithReuseIdentifier: "DateCell")
        collectionView.backgroundColor = .clear
        
        let width = collectionView.frame.width / 7
            layout.itemSize = CGSize(width: width, height: width)
            layout.minimumInteritemSpacing = 0
            layout.minimumLineSpacing = 0
            layout.headerReferenceSize = CGSize(width: collectionView.frame.width, height: 50)
        
        
        [monthLabel, separatorLine, collectionView].forEach {
            addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            monthLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            monthLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            monthLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            separatorLine.topAnchor.constraint(equalTo: monthLabel.bottomAnchor, constant: 10),
            separatorLine.leadingAnchor.constraint(equalTo: leadingAnchor),
            separatorLine.trailingAnchor.constraint(equalTo: trailingAnchor),
            separatorLine.heightAnchor.constraint(equalToConstant: 1),
            
            collectionView.topAnchor.constraint(equalTo: separatorLine.bottomAnchor, constant: 10),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
    
    private func setupCalendar() {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        
        guard let startDate = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: startDate) else {
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ru_RU")
        let monthName = dateFormatter.standaloneMonthSymbols[components.month! - 1].capitalized
        if components.year == Calendar.current.component(.year, from: Date()) {
            monthLabel.text = monthName
        } else {
            monthLabel.text = "\(monthName) \(components.year!)"
        }

        
        let today = Date()
        for day in range {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: startDate) else { continue }
            
            let isCurrent = calendar.isDate(date, inSameDayAs: today)
            let isSelected = isCurrent
            let isPast: Bool
            if calendar.compare(date, to: today, toGranularity: .day) == .orderedAscending {
                isPast = true
            } else {
                isPast = false
            }
            
            let state = State(isSelected: isSelected, isCurrent: isCurrent, isPast: isPast)
            let dayItem = Day(date: date, state: state)
            
            days.append(dayItem)
        }
        
        collectionView.reloadData()
    }
    
    
    // MARK: - UICollectionView Methods
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return days.count + emptyDaysAtStart()
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "DateCell", for: indexPath) as! DateCell
            if isIndexPathEmpty(indexPath) {
                cell.configureAsEmpty()
            } else {
                let day = days[indexPath.row - emptyDaysAtStart()]
                cell.configure(with: day)
            }
            return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.bounds.width / 7
        return CGSize(width: width, height: width)
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case UICollectionView.elementKindSectionHeader:
            let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "WeekdaysHeaderViewID", for: indexPath) as! WeekdaysHeaderView
            return headerView
        default:
            assert(false, "Invalid element type")
        }
    }

    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if isIndexPathEmpty(indexPath) {
            return false
        }
        return !days[indexPath.row - emptyDaysAtStart()].state.isPast
    }

    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        let adjustedIndex = indexPath.row - emptyDaysAtStart()
        if adjustedIndex < 0 || adjustedIndex >= days.count {
            return
        }
        
        for (index, _) in days.enumerated() {
            days[index].state.isSelected = adjustedIndex == index
        }
        
        collectionView.reloadData()
    }
    
    // MARK: - Other methods
    
    private func emptyDaysAtStart() -> Int {
        let components = Calendar.current.dateComponents([.year, .month], from: Date())
            if let firstDateOfMonth = Calendar.current.date(from: components) {
                let weekday = Calendar.current.component(.weekday, from: firstDateOfMonth)
                return (weekday + 5) % 7
            }
            return 0
    }
    
    private func isIndexPathEmpty(_ indexPath: IndexPath) -> Bool {
        return indexPath.row < emptyDaysAtStart()
    }
}

