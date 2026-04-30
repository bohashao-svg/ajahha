import UIKit
import SwiftUI

// MARK: - Liquid Glass Action Cell
final class LiquidActionCell: UICollectionViewCell {
    let titleLabel = UILabel()
    let iconImageView = UIImageView()
    let separatorLine = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        backgroundColor = .clear

        let glassBg = UIView()
        glassBg.backgroundColor = UIColor(white: 1, alpha: 0.06)
        glassBg.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(glassBg)

        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = UIColor(hex: "#6C8EFF")
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconImageView)

        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = UIColor(hex: "#F0F4FF")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        separatorLine.backgroundColor = UIColor(white: 1, alpha: 0.07)
        separatorLine.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(separatorLine)

        NSLayoutConstraint.activate([
            glassBg.topAnchor.constraint(equalTo: contentView.topAnchor),
            glassBg.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            glassBg.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            glassBg.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 22),
            iconImageView.heightAnchor.constraint(equalToConstant: 22),

            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            separatorLine.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            separatorLine.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separatorLine.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separatorLine.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.15) {
                self.contentView.alpha = self.isHighlighted ? 0.6 : 1.0
                self.contentView.transform = self.isHighlighted
                    ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }
    }
}

// MARK: - Liquid Glass Action Controller

typealias LiquidActionData = ActionData

final class LiquidGlassActionController: ActionController<LiquidActionCell, LiquidActionData, UICollectionReusableView, Void, UICollectionReusableView, Void> {

    override init(nibName: String? = nil, bundle: Bundle? = nil) {
        super.init(nibName: nibName, bundle: bundle)
        commonInit()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func commonInit() {
        cellSpec = .cellClass(height: { _ in 56 })
        settings.animation.scale = nil
        settings.animation.present.duration = 0.38
        settings.animation.dismiss.duration = 0.28
        settings.behavior.hideOnScrollDown = false
        settings.behavior.scrollEnabled = false
        settings.cancelView.showCancel = true
        settings.cancelView.title = "取消"
        settings.cancelView.height = 56
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        let blur = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let blurView = UIVisualEffectView(effect: blur)
        blurView.frame = view.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(blurView, at: 0)

        let dim = UIView(frame: view.bounds)
        dim.backgroundColor = UIColor(hex: "#0A0E1A").withAlphaComponent(0.55)
        dim.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(dim, at: 0)
    }

    override func collectionView(_ collectionView: UICollectionView,
                                 cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: String(describing: LiquidActionCell.self),
            for: indexPath) as! LiquidActionCell

        let act = self.action(at: indexPath)
        cell.titleLabel.text = act?.data?.title
        if let iconName = act?.data?.subtitle, !iconName.isEmpty {
            cell.iconImageView.image = UIImage(systemName: iconName)
        } else {
            cell.iconImageView.image = nil
        }

        if act?.style == .destructive {
            cell.titleLabel.textColor = UIColor(hex: "#FF6B6B")
            cell.iconImageView.tintColor = UIColor(hex: "#FF6B6B")
        } else if act?.style == .cancel {
            cell.titleLabel.textColor = UIColor(hex: "#8B9CC8")
            cell.iconImageView.tintColor = UIColor(hex: "#8B9CC8")
        } else {
            cell.titleLabel.textColor = UIColor(hex: "#F0F4FF")
            cell.iconImageView.tintColor = UIColor(hex: "#6C8EFF")
        }

        // Hide separator on last visible item
        let total = collectionView.numberOfItems(inSection: indexPath.section)
        cell.separatorLine.isHidden = indexPath.item == total - 1
        return cell
    }
}

// MARK: - SwiftUI Bridge

struct LiquidActionSheet: UIViewControllerRepresentable {
    struct SheetAction {
        let title: String
        let icon: String
        let style: ActionStyle
        let handler: () -> Void
    }

    let title: String?
    let actions: [SheetAction]
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard isPresented, uiViewController.presentedViewController == nil else { return }
        let controller = LiquidGlassActionController()
        for action in actions {
            let data = ActionData(title: action.title, subtitle: action.icon)
            controller.addAction(Action(data, style: action.style) { [weak controller] _ in
                controller?.dismiss(animated: true)
                action.handler()
                DispatchQueue.main.async { isPresented = false }
            })
        }
        controller.addAction(Action(ActionData(title: "取消", subtitle: "xmark"), style: .cancel) { [weak controller] _ in
            controller?.dismiss(animated: true)
            DispatchQueue.main.async { isPresented = false }
        })
        uiViewController.present(controller, animated: true)
    }
}

extension View {
    func liquidActionSheet(
        isPresented: Binding<Bool>,
        title: String? = nil,
        actions: [LiquidActionSheet.SheetAction]
    ) -> some View {
        self.background(
            LiquidActionSheet(title: title, actions: actions, isPresented: isPresented)
                .frame(width: 0, height: 0)
        )
    }
}
