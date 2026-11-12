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
        didSet { previousChapterButton.isEnabled = hasPreviousChapter }
    }
    var hasNextChapter: Bool = true {
        didSet { nextChapterButton.isEnabled = hasNextChapter }
    }

    let sliderView = ReaderSliderView()
    private let incognitoModeLabel = UILabel()
    private let currentPageLabel = UILabel()

    private lazy var chapterButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "list.bullet")
        configuration.title = NSLocalizedString("CHAPTER")
        configuration.imagePlacement = .leading
        configuration.imagePadding = 4
        configuration.contentInsets = .init(top: 0, leading: 0, bottom: 0, trailing: 0)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 13, weight: .medium)
            return outgoing
        }
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: #selector(chapterButtonTapped), for: .touchUpInside)
        return button
    }()

    private lazy var previousChapterButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.title = NSLocalizedString("PREVIOUS_CHAPTER")
        configuration.contentInsets = .init(top: 0, leading: 0, bottom: 0, trailing: 0)
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
        configuration.contentInsets = .init(top: 0, leading: 0, bottom: 0, trailing: 0)
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
            incognitoModeLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            incognitoModeLabel.bottomAnchor.constraint(equalTo: bottomAnchor),

            // Bottom row, left to right: chapter list, previous chapter,
            // current page, next chapter. The "pages left" label was removed:
            // it is redundant with the "2 / 46" page count, and its spot is
            // now the next-chapter button.
            chapterButton.leadingAnchor.constraint(equalTo: incognitoModeLabel.trailingAnchor, constant: 8),
            chapterButton.bottomAnchor.constraint(equalTo: bottomAnchor),

            previousChapterButton.leadingAnchor.constraint(equalTo: chapterButton.trailingAnchor, constant: 8),
            previousChapterButton.bottomAnchor.constraint(equalTo: bottomAnchor),

            currentPageLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            currentPageLabel.bottomAnchor.constraint(equalTo: bottomAnchor),

            nextChapterButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            nextChapterButton.bottomAnchor.constraint(equalTo: bottomAnchor),

            sliderView.heightAnchor.constraint(equalToConstant: 12),
            sliderView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
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
        onChapterListTap?()
    }

    @objc private func previousChapterButtonTapped() {
        onPreviousChapterTap?()
    }

    @objc private func nextChapterButtonTapped() {
        onNextChapterTap?()
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
