import UIKit
import SwiftUI

// MARK: - RHTaskCell (Liquid Glass)
// Concrete BasePageCollectionCell for RHTask cards — liquid glass reskin.

final class RHTaskCell: BasePageCollectionCell {

    private let titleLabel    = UILabel()
    private let subtitleLabel = UILabel()
    private let statusDot     = UIView()
    private let bgImageView   = UIImageView()
    private let glassOverlay  = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        // Front container (collapsed) — liquid glass
        let front = UIView()
        front.backgroundColor = UIColor(hex: "#111827").withAlphaComponent(0.78)
        front.layer.cornerRadius = 20
        front.layer.cornerCurve  = .continuous
        front.layer.borderColor  = UIColor(white: 1, alpha: 0.14).cgColor
        front.layer.borderWidth  = 1
        front.clipsToBounds = true
        front.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(front)
        frontContainerView = front

        // Back container (expanded) — deeper glass
        let back = UIView()
        back.backgroundColor = UIColor(hex: "#0D1220").withAlphaComponent(0.88)
        back.layer.cornerRadius = 20
        back.layer.cornerCurve  = .continuous
        back.layer.borderColor  = UIColor(hex: "#6C8EFF").withAlphaComponent(0.2).cgColor
        back.layer.borderWidth  = 1
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

        // Background image with gradient overlay
        bgImageView.contentMode = .scaleAspectFill
        bgImageView.clipsToBounds = true
        bgImageView.translatesAutoresizingMaskIntoConstraints = false
        front.addSubview(bgImageView)

        // Gradient overlay on image
        let gradientView = UIView()
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        front.addSubview(gradientView)

        NSLayoutConstraint.activate([
            bgImageView.topAnchor.constraint(equalTo: front.topAnchor),
            bgImageView.leadingAnchor.constraint(equalTo: front.leadingAnchor),
            bgImageView.trailingAnchor.constraint(equalTo: front.trailingAnchor),
            bgImageView.bottomAnchor.constraint(equalTo: front.bottomAnchor),
            gradientView.topAnchor.constraint(equalTo: front.topAnchor),
            gradientView.leadingAnchor.constraint(equalTo: front.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: front.trailingAnchor),
            gradientView.bottomAnchor.constraint(equalTo: front.bottomAnchor),
        ])

        DispatchQueue.main.async {
            let grad = CAGradientLayer()
            grad.colors = [UIColor.clear.cgColor, UIColor(hex: "#0A0E1A").withAlphaComponent(0.75).cgColor]
            grad.startPoint = CGPoint(x: 0.5, y: 0.3)
            grad.endPoint   = CGPoint(x: 0.5, y: 1.0)
            grad.frame = gradientView.bounds
            gradientView.layer.addSublayer(grad)
        }

        // Status dot
        statusDot.layer.cornerRadius = 4
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        front.addSubview(statusDot)

        // Title
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = UIColor(hex: "#F0F4FF")
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        front.addSubview(titleLabel)

        // Subtitle
        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = UIColor(hex: "#8B9CC8")
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        front.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            statusDot.leadingAnchor.constraint(equalTo: front.leadingAnchor, constant: 14),
            statusDot.bottomAnchor.constraint(equalTo: subtitleLabel.topAnchor, constant: -6),
            statusDot.widthAnchor.constraint(equalToConstant: 8),
            statusDot.heightAnchor.constraint(equalToConstant: 8),

            titleLabel.leadingAnchor.constraint(equalTo: front.leadingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: front.trailingAnchor, constant: -14),
            titleLabel.bottomAnchor.constraint(equalTo: subtitleLabel.topAnchor, constant: -3),

            subtitleLabel.leadingAnchor.constraint(equalTo: front.leadingAnchor, constant: 14),
            subtitleLabel.bottomAnchor.constraint(equalTo: front.bottomAnchor, constant: -14),
        ])

        // Glow shadow
        contentView.layer.shadowColor   = UIColor(hex: "#6C8EFF").cgColor
        contentView.layer.shadowOpacity = 0.12
        contentView.layer.shadowRadius  = 18
        contentView.layer.shadowOffset  = CGSize(width: 0, height: 6)
    }

    func configure(with task: RHTask) {
        titleLabel.text    = task.workflowName.isEmpty ? task.workflowType : task.workflowName
        subtitleLabel.text = task.workflowType
        statusDot.backgroundColor = task.status.uiColor

        let imageUrls = task.outputUrls.filter { url in
            !["mp4", "mov", "webm"].contains(url.split(separator: ".").last?.lowercased() ?? "")
        }
        guard let firstUrl = imageUrls.first else { bgImageView.image = nil; return }

        // Use AlamofireImage bridge for loading
        bgImageView.rh_setImage(withURL: firstUrl)
    }
}

// MARK: - ExpandingTasksViewController (unchanged logic, glass cell)

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
        collectionView?.register(RHTaskCell.self, forCellWithReuseIdentifier: Self.cellId)
        collectionView?.backgroundColor = .clear
    }

    override func collectionView(_ collectionView: UICollectionView,
                                 numberOfItemsInSection section: Int) -> Int { tasks.count }

    override func collectionView(_ collectionView: UICollectionView,
                                 cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: Self.cellId, for: indexPath) as! RHTaskCell
        cell.configure(with: tasks[indexPath.item])
        return cell
    }

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
