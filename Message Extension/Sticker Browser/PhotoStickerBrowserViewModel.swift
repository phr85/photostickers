//
//  PhotoStickerBrowserViewModel.swift
//  PhotoStickers
//
//  Created by Jochen Pfeiffer on 30/12/2016.
//  Copyright © 2016 Jochen Pfeiffer. All rights reserved.
//

import Foundation
import Log
import Messages
import RealmSwift
import RxCocoa
import RxRealm
import RxSwift

protocol PhotoStickerBrowserViewModelType {
    var editButtonDidTap: PublishSubject<Void> { get }
    var currentPresentationStyle: PublishSubject<MSMessagesAppPresentationStyle> { get }

    var sectionItems: Observable<[StickerSectionItem]> { get }
    var requestPresentationStyle: Driver<MSMessagesAppPresentationStyle> { get }
    var navigationBarHidden: Driver<Bool> { get }

    func editStickerViewModel(for sticker: Sticker) -> EditStickerViewModelType
    func addStickerViewModel() -> EditStickerViewModelType
    func stickerBrowserButtonViewModel() -> StickerBrowserButtonViewModelType
}

class PhotoStickerBrowserViewModel: BaseViewModel, PhotoStickerBrowserViewModelType {
    // MARK: Dependencies

    let extensionContext: NSExtensionContext?
    let stickerService: StickerServiceType
    let imageStoreService: ImageStoreServiceType
    fileprivate let stickerRenderService: StickerRenderServiceType

    // MARK: Input

    let editButtonDidTap = PublishSubject<Void>()
    let currentPresentationStyle = PublishSubject<MSMessagesAppPresentationStyle>()

    // MARK: Output

    let sectionItems: Observable<[StickerSectionItem]>
    let requestPresentationStyle: Driver<MSMessagesAppPresentationStyle>
    let navigationBarHidden: Driver<Bool>

    init(stickerService: StickerServiceType,
         imageStoreService: ImageStoreServiceType,
         stickerRenderService: StickerRenderServiceType,
         extensionContext: NSExtensionContext?) {
        self.stickerService = stickerService
        self.imageStoreService = imageStoreService
        self.stickerRenderService = stickerRenderService
        self.extensionContext = extensionContext

        let isEditing = editButtonDidTap
            .scan(false) { previous, _ in !previous }
            .startWith(false)
            .asDriver(onErrorJustReturn: false)

        navigationBarHidden = currentPresentationStyle
            .map { $0 != .expanded }
            .startWith(true)
            .asDriver(onErrorJustReturn: true)

        let predicate = NSPredicate(format: "\(StickerProperty.hasRenderedImage.rawValue) == true")
        sectionItems = stickerService
            .fetchStickers(withPredicate: predicate)
            .map { allStickers in
                var items = allStickers.map { sticker -> StickerSectionItem in
                    let cellViewModel: StickerBrowserCellViewModelType = StickerBrowserCellViewModel(sticker: sticker,
                                                                                                     editing: isEditing,
                                                                                                     imageStore: imageStoreService)
                    return StickerSectionItem.stickerItem(viewModel: cellViewModel)
                }
                items.append(StickerSectionItem.openAppItem)
                return items
            }

        requestPresentationStyle = editButtonDidTap
            .map { .expanded }
            .asDriver(onErrorDriveWith: Driver.empty())

        super.init()
    }

    // MARK: - View Models

    func editStickerViewModel(for sticker: Sticker) -> EditStickerViewModelType {
        return EditStickerViewModel(sticker: sticker,
                                    imageStoreService: imageStoreService,
                                    stickerService: stickerService,
                                    stickerRenderService: stickerRenderService)
    }

    func addStickerViewModel() -> EditStickerViewModelType {
        return editStickerViewModel(for: Sticker.newSticker())
    }

    func stickerBrowserButtonViewModel() -> StickerBrowserButtonViewModelType {
        return StickerBrowserButtonViewModel(editButtonDidTap: editButtonDidTap)
    }
}
