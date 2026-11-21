//
//  ReaderToolbarView.swift
//  Aidoku (iOS)
//
//  Created by Skitty on 8/15/22.
//

import Combine
import UIKit

class ReaderToolbarView: UIView {
    var currentPageValue: Int? {
        didSet {
            if oldValue != currentPageValue {
                let feedbackGenerator = UISelectionFeedbackGenerator()
                feedbackGenerator.selectionChanged()
            }
        }
    }
    var currentPage: Int? {
        didSet { updatePageLabels() }
    }
    var totalPages: Int? {
        didSet { updatePageLabels() }
    }

    /// Tapped when the bottom-left chapter button is used.
    var onChapterListTap: (() -> Void)?
    /// Tapped when the bottom "previous chapter" button is used.
    var onPreviousChapterTap: (() -> Void)?
    /// Tapped when the bottom "next chapter" button is used.
    var onNextChapterTap: (() -> Void)?

    var hasPreviousChapter: Bool = true {
        didSet { updateChapterButtonStates() }
    }
    var hasNextChapter: Bool = true {
        didSet { updateChapterButtonStates() }
    }
    /// True while a chapter switch started from these buttons is still
    /// loading its page list: the buttons stay disabled so a second tap
    /// cannot queue up another switch (and skip a chapter) before the
    /// first one lands.
    var isSwitchingChapter: Bool = false {
        didSet { updateChapterButtonStates() }
    }

    private func updateChapterButtonStates() {
        previousChapterButton.isEnabled = hasPreviousChapter && !isSwitchingChapter
        nextChapterButton.isEnabled = hasNextChapter && !isSwitchingChapter
    }

    let sliderView = ReaderSliderView()
    private let incognitoModeLabel = UILabel()
    private let currentPageLabel = UILabel()

    private lazy var chapterButton: UIButton = {
        // Icon only, no text: the list icon is the chapter list button.
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "list.bullet")
        configuration.contentInsets = .init(top: 0, leading: 4, bottom: 0, trailing: 4)
        let button = UIButton(configuration: configuration)
        button.accessibilityLabel = NSLocalizedString("CHAPTER")
        button.addTarget(self, action: #selector(chapterButtonTapped), for: .touchUpInside)
        return button
    }()

    private lazy var previousChapterButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.title = NSLocalizedString("PREVIOUS_CHAPTER")
        configuration.contentInsets = .init(top: 0, leading: 4, bottom: 0, trailing: 4)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 13, weight: .medium)
            return outgoing
        }
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: #selector(previousChapterButtonTapped), for: .touchUpInside)
        return button
    }()

    private lazy var nextChapterButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.title = NSLocalizedString("NEXT_CHAPTER")
        configuration.contentInsets = .init(top: 0, leading: 4, bottom: 0, trailing: 4)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 13, weight: .medium)
            return outgoing
        }
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: #selector(nextChapterButtonTapped), for: .touchUpInside)
        return button
    }()

    private var cancellables: [AnyCancellable] = []

    init() {
        super.init(frame: .zero)
        configure()
        constrain()
        observe()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure() {
        incognitoModeLabel.font = .systemFont(ofSize: 10)
        incognitoModeLabel.textColor = .secondaryLabel
        incognitoModeLabel.textAlignment = .left
        incognitoModeLabel.isHidden = !AppSettings.general.incognitoMode.get()
        addSubview(incognitoModeLabel)

        currentPageLabel.font = .systemFont(ofSize: 10)
        currentPageLabel.textAlignment = .center
        currentPageLabel.sizeToFit()
        // Let the page count give way first on narrow screens, so the
        // chapter buttons never get pushed off the bar.
        currentPageLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(currentPageLabel)

        sliderView.semanticContentAttribute = .playback // for rtl languages
        addSubview(sliderView)

        addSubview(chapterButton)
        addSubview(previousChapterButton)
        addSubview(nextChapterButton)
    }

    func constrain() {
        incognitoModeLabel.translatesAutoresizingMaskIntoConstraints = false
        currentPageLabel.translatesAutoresizingMaskIntoConstraints = false
        chapterButton.translatesAutoresizingMaskIntoConstraints = false
        previousChapterButton.translatesAutoresizingMaskIntoConstraints = false
        nextChapterButton.translatesAutoresizingMaskIntoConstraints = false
        sliderView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            incognitoModeLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            incognitoModeLabel.centerYAnchor.constraint(equalTo: bottomAnchor, constant: -19),

            // Bottom row, all vertically centered on the same line:
            // chapter icon at the leading edge, page count centered,
            // and previous/next chapter grouped together at the trailing
            // edge. The row is anchored 19pt above this view's bottom,
            // i.e. at the same on-screen position as before: this view
            // is 96pt tall and the toolbar adds the home-indicator safe
            // area below it (~34pt), so the bar is ~130pt. The extra
            // height goes entirely between the slider and the row, not
            // under the row.
            chapterButton.leadingAnchor.constraint(equalTo: incognitoModeLabel.trailingAnchor, constant: 8),
            chapterButton.centerYAnchor.constraint(equalTo: bottomAnchor, constant: -19),

            previousChapterButton.trailingAnchor.constraint(equalTo: nextChapterButton.leadingAnchor, constant: -28),
            previousChapterButton.centerYAnchor.constraint(equalTo: bottomAnchor, constant: -19),

            currentPageLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            currentPageLabel.centerYAnchor.constraint(equalTo: bottomAnchor, constant: -19),

            nextChapterButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            nextChapterButton.centerYAnchor.constraint(equalTo: bottomAnchor, constant: -19),

            sliderView.heightAnchor.constraint(equalToConstant: 12),
            // Centered between the top of the bar and the button row:
            // the bar is 96pt, the row sits at 77pt from the top, so
            // the slider center is at ~38pt (top +32).
            sliderView.topAnchor.constraint(equalTo: topAnchor, constant: 32),
            sliderView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            sliderView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12)
        ])
    }

    func observe() {
        NotificationCenter.default.publisher(for: .init(AppSettings.general.incognitoMode.key))
            .sink { [weak self] _ in
                guard let self else { return }
                self.incognitoModeLabel.isHidden = !AppSettings.general.incognitoMode.get()
                // Keep the label zero-width while hidden so the chapter
                // button stays at the leading edge.
                self.incognitoModeLabel.text = AppSettings.general.incognitoMode.get()
                    ? NSLocalizedString("INCOGNITO_MODE")
                    : nil
            }
            .store(in: &cancellables)
    }

    // allow slider thumb to be touched outside bounds
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for subview in subviews where subview is ReaderSliderView {
            if subview.subviews.contains(where: { $0.bounds.contains(convert(point, to: $0)) }) {
                return subview
            }
        }
        return super.hitTest(point, with: event)
    }

    @objc private func chapterButtonTapped() {
        animateTap(on: chapterButton)
        onChapterListTap?()
    }

    @objc private func previousChapterButtonTapped() {
        animateTap(on: previousChapterButton)
        onPreviousChapterTap?()
    }

    @objc private func nextChapterButtonTapped() {
        animateTap(on: nextChapterButton)
        onNextChapterTap?()
    }

    /// Brief press effect so a tap reads as acknowledged at once, even
    /// while the next chapter is still loading its pages.
    private func animateTap(on button: UIButton) {
        UIView.animate(withDuration: 0.08, animations: {
            button.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }, completion: { _ in
            UIView.animate(withDuration: 0.12) {
                button.transform = .identity
            }
        })
    }

    func displayPage(_ page: Int) {
        guard let totalPages = totalPages else {
            return
        }
        var page = page
        if page > totalPages {
            page = totalPages
        } else if page < 1 {
            page = 1
        }
        currentPageLabel.text = String(format: NSLocalizedString("%i_OF_%i"), page, totalPages)
        currentPageValue = page
    }

    func updatePageLabels() {
        guard var currentPage = currentPage, let totalPages = totalPages else {
            currentPageLabel.text = nil
            return
        }

        if currentPage > totalPages {
            currentPage = totalPages
        } else if currentPage < 1 {
            currentPage = 1
        }
        currentPageLabel.text = String(format: NSLocalizedString("%i_OF_%i"), currentPage, totalPages)
        incognitoModeLabel.text = AppSettings.general.incognitoMode.get()
            ? NSLocalizedString("INCOGNITO_MODE")
            : nil
    }

    func updateSliderPosition() {
        guard let currentPage = currentPage, let totalPages = totalPages else { return }
        sliderView.move(toValue: CGFloat(currentPage - 1) / max(CGFloat(totalPages - 1), 1))
    }
}
