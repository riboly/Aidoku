//
//  SourceImageView.swift
//  Aidoku
//
//  Created by Skitty on 4/26/25.
//

import AidokuRunner
import Nuke
import NukeUI
import SwiftUI

struct SourceImageView: View {
    var source: AidokuRunner.Source?

    let imageUrl: String
    var width: CGFloat?
    var height: CGFloat?
    var downsampleWidth: CGFloat?
    var contentMode: ContentMode = .fill
    var placeholder = "MangaPlaceholder"

    @State private var imageRequest: ImageRequest?
    /// Failed remote cover loads are retried (see scheduleCoverRetry).
    @State private var retryCount = 0
    @State private var retryTask: Task<Void, Never>?

    private var processors: [ImageProcessing] {
        var processors: [ImageProcessing] = []
        if let downsampleWidth {
            processors.append(DownsampleProcessor(width: downsampleWidth))
        }
        if let source, source.features.processesCovers {
            processors.append(CoverInterceptorProcessor(source: source))
        }
        return processors
    }

    var body: some View {
        LazyImage(
            request: imageRequest,
            transaction: .init(animation: .default)
        ) { state in
            if state.imageContainer?.type == .gif, let data = state.imageContainer?.data {
                GIFImage(
                    data: data,
                    contentMode: contentMode
                )
                    .frame(width: width, height: height)
                    .id(state.image != nil ? imageUrl : "placeholder") // ensures only opacity is animated
            } else {
                let result = if let image = state.image {
                    image
                } else {
                    Image(placeholder)
                }
                result
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .frame(width: width, height: height)
                    .id(state.image != nil ? imageUrl : "placeholder") // ensures only opacity is animated
            }
        }
        .processors(processors)
        .onCompletion { result in
            switch result {
            case .success:
                retryCount = 0
            case .failure:
                scheduleCoverRetry()
            }
        }
        .onAppear {
            guard imageRequest == nil else { return }
            Task {
                await loadImageRequest(url: imageUrl)
            }
        }
        .onChange(of: imageUrl) { newValue in
            retryTask?.cancel()
            retryTask = nil
            retryCount = 0
            imageRequest = nil
            Task {
                await loadImageRequest(url: newValue)
            }
        }
        .onDisappear {
            retryTask?.cancel()
            retryTask = nil
        }
    }

    /// Retry a failed remote cover fetch up to 3 times, 5 seconds apart.
    /// Local covers (aidoku-image://, file URLs) are not retried: if the
    /// file is missing, retrying cannot bring it back.
    private func scheduleCoverRetry() {
        guard imageUrl.hasPrefix("http"), retryCount < 3 else { return }
        retryTask?.cancel()
        retryCount += 1
        retryTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            // Re-issue the request: clear it first so LazyImage reloads
            // the same URL instead of reusing the failed result. The
            // Nuke cache is still consulted first, so a cover that has
            // since been cached loads without hitting the network.
            imageRequest = nil
            await loadImageRequest(url: imageUrl)
        }
    }

    func loadImageRequest(url: String) async {
        let url = URL(string: url)
        if let fileUrl = url?.toAidokuFileUrl() {
            imageRequest = ImageRequest(url: fileUrl)
            return
        }
        guard let source, let url, !url.isFileURL else {
            imageRequest = ImageRequest(url: url)
            return
        }
        imageRequest = ImageRequest(
            urlRequest: await source.getModifiedImageRequest(url: url, context: nil),
            userInfo: [.processesKey: source.features.processesCovers]
        )
    }
}
