//
//  Created by Alex.M on 09.06.2022.
//

import Foundation
import Photos
import SwiftUI

// Comment out AllMediasProvider as GalleryPicker likely uses a simpler approach
/*
final class AllMediasProvider: BaseMediasProvider {

    override func reload() {
        PermissionsService.shared.requestPhotoLibraryPermission {
            DispatchQueue.main.async { [weak self] in
                self?.reloadInternal()
            }
        }
    }

    func reloadInternal() {
        isLoading = true
        defer {
            isLoading = false
        }
        let allPhotosOptions = PHFetchOptions()
        allPhotosOptions.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]
        let allPhotos = PHAsset.fetchAssets(with: allPhotosOptions)
        let assets = MediasProvider.map(fetchResult: allPhotos, mediaSelectionType: selectionParamsHolder.mediaType)
        filterAndPublish(assets: assets)
    }
}
*/
