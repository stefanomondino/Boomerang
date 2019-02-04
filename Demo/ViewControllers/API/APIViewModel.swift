//
//  APIViewModel.swift
//  Demo
//
//  Created by Stefano Mondino on 27/01/2019.
//  Copyright © 2019 Synesthesia. All rights reserved.
//

import Foundation
import Boomerang
import RxSwift

struct APIViewModel: ListViewModel {
    
    func group(_ observable: Observable<[Show]>) -> Observable<DataGroup> {
        return observable.map { DataGroup($0, supplementaryData: [0: [
            UICollectionView.elementKindSectionHeader: "Header",
            UICollectionView.elementKindSectionFooter: "Footer"
            ]]) }
    }
    
    var dataHolder: DataHolder = DataHolder()
    
    func convert(model: ModelType, at indexPath: IndexPath, for type: String?) -> IdentifiableViewModelType? {
        switch model {
        case let title as String: return HeaderItemViewModel(title: title)
        case let model as Show: return ShowItemViewModel(model: model)
        default: return nil
        }
    }
    
    init() {
        
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let decoder =  JSONDecoder()
        let apiCall = session.rx
            .data(request: URLRequest(url: URL(string: "https://api.tvmaze.com/schedule")!))
            .map {
            try decoder.decode([Show.Episode].self, from: $0)
            }
            .map { $0.map { $0.show } }
        
        dataHolder = DataHolder(data: self.group(apiCall))
    }
    
}
