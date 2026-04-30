import UIKit
import SwiftUI

// MARK: - RHTaskCell
// Concrete BasePageCollectionCell for RHTask cards. Programmatic layout, no XIB.

final class RHTaskCell: BasePageCollectionCell {

    private let titleLabel    = UILabel()
    private let subtitleLabel = UILabel()
    private let bgImageView   = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        // Front container (collapsed)
        let front = UIView()
        front.backgroundColor = UIColor(hex: "#1A0A05")
        front.layer.cornerRadius = 18
        front.clipsToBounds = true
        front.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(front)
        frontContainerView = front

        // Back container (expanded)
        let back = UIView()
        back.backgroundColor = UIColor(hex: "#2D1A0E")
        back.layer.cornerRadius = 18
        back.clipsToBounds = true
        back.translatesAutoresizingMaskIntoConstraints = false
        contentView.insertSubview(back, belowSubview: front)
        backContainerView = back

        let frontY = front.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        let backY  = back.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        frontConstraintY = frontY
        backConstraintY  = backY

        NSLayoutConstraint.activate([
            front.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            front.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            front.heightAnchor.constraint(equalTo: contentView.heightAnchor, multiplier: 0.55),
            frontY,
            back.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            back.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            back.heightAnchor.constraint(equalTo: contentView.heightAnchor, multiplier: 0.85),
            backY,
        ])

        // Background image
        bgImageView.contentMode = .scaleAspectFill
        bgImageView.clipsToBounds = true
        bgImageView.translatesAutoresizingMaskIntoConstraints = false
        front.addSubview(bgImageView)
        NSLayoutConstraint.activate([
            bgImageView.topAnchor.constraint(equalTo: front.topAnchor),
            bgImageView.leadingAnchor.constraint(equalTo: front.leadingAnchor),
            bgImageView.trailingAnchor.constraint(equalTo: front.trailingAnchor),
            bgImageView.bottomAnchor.constraint(equalTo: front.bottomAnchor),
        ])

        // Title
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        front.addSubview(titleLabel)

        // Subtitle
        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = UIColor(white: 0.8, alpha: 1)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        front.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: front.leadingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: front.trailingAnchor, constant: -14),
            titleLabel.bottomAnchor.constraint(equalTo: subtitleLabel.topAnchor, constant: -4),
            subtitleLabel.leadingAnchor.constraint(equalTo: front.leadingAnchor, constant: 14),
            subtitleLabel.bottomAnchor.constraint(equalTo: front.bottomAnchor, constant: -14),
        ])
    }

    func configure(with task: RHTask) {
        titleLabel.text = task.workflowName.isEmpty ? task.workflowType : task.workflowName
        subtitleLabel.text = task.workflowType

        let imageUrls = task.outputUrls.filter { url in
            !["mp4", "mov", "webm"].contains(url.split(separator: ".").last?.lowercased() ?? "")
        }
        guard let firstUrl = imageUrls.first else { bgImageView.image = nil; return }

        if let cached = RHImageCache.shared.image(for: firstUrl) {
            bgImageView.image = cached
        } else if let url = URL(string: firstUrl) {
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let data, let img = UIImage(data: data) else { return }
                RHImageCache.shared.store(img, for: firstUrl)
                DispatchQueue.main.async { self?.bgImageView.image = img }
            }.resume()
        }
    }
}

// MARK: - ExpandingTasksViewController
// Subclasses ExpandingViewController; overrides the data source / delegate methods.

final class ExpandingTasksViewController: ExpandingViewController {

    var tasks: [RHTask] = [] {
        didSet { collectionView?.reloadData() }
    }
    var onSelectTask: ((RHTask) -> Void)?

    private static let cellId = "RHTaskCell"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        itemSize = CGSize(width: 220, height: 300)
        // collectionView is created by super.commonInit via viewDidLoad → commonInit
        collectionView?.register(RHTaskCell.self, forCellWithReuseIdentifier: Self.cellId)
        collectionView?.backgroundColor = .clear
    }

    // MARK: - UICollectionViewDataSource overrides

    override func collectionView(_ collectionView: UICollectionView,
                                 numberOfItemsInSection section: Int) -> Int {
        tasks.count
    }

    override func collectionView(_ collectionView: UICollectionView,
                                 cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: Self.cellId, for: indexPath) as! RHTaskCell
        cell.configure(with: tasks[indexPath.item])
        return cell
    }

    // MARK: - UICollectionViewDelegate overrides

    override func collectionView(_ collectionView: UICollectionView,
                                 didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? BasePageCollectionCell else { return }
        if cell.isOpened {
            cell.cellIsOpen(false)
            onSelectTask?(tasks[indexPath.item])
        } else {
            cell.cellIsOpen(true)
        }
    }
}

// MARK: - SwiftUI Bridge

struct ExpandingTasksView: UIViewControllerRepresentable {
    let tasks: [RHTask]
    var onSelectTask: ((RHTask) -> Void)?

    func makeUIViewController(context: Context) -> ExpandingTasksViewController {
        let vc = ExpandingTasksViewController()
        vc.tasks = tasks
        vc.onSelectTask = onSelectTask
        return vc
    }

    func updateUIViewController(_ uiViewController: ExpandingTasksViewController, context: Context) {
        uiViewController.tasks = tasks
        uiViewController.onSelectTask = onSelectTask
    }
}
