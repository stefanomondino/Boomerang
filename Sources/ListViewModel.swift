//
//  ViewModelList.swift
//  Boomerang
//
//  Created by Stefano Mondino on 10/11/16.
//
//

import Foundation
//import ReactiveSwift
//import Result
import RxSwift
import Action
import RxCocoa


let defaultListIdentifier = "default_list_identifier"

extension String : ListIdentifier {
    public var name : String {
        return self
    }
    public var type: String? {
        return nil
    }
}
public protocol ListIdentifier {
    var name : String {get }
    var type : String? {get }
}


public protocol ResultRangeType {
    var start:IndexPath {get set}
    var end:IndexPath {get set}
}




extension IndexPath : SelectionInput {}
public protocol ListDataHolderType : class {
//    var viewModels:MutableProperty<[IndexPath:ItemViewModelType]> {get set}
    var viewModels:Variable<[IndexPath:ItemViewModelType]> {get set}
    //var resultsCount:MutableProperty<Int> {get set}
    var resultsCount:Variable<Int> {get set}
//    var newDataAvailable:MutableProperty<ResultRangeType?> {get set}
    var newDataAvailable:Variable<ResultRangeType?> {get set}
//    var models:MutableProperty<ModelStructure> {get set}
    var models : Variable<ModelStructure> {get set}
//    var reloadAction:Action<ResultRangeType?,ModelStructure,Error> {get set}
    //var dataProducer:SignalProducer<ModelStructure,Error> {get set}
    var reloadAction:Action<ResultRangeType?,ModelStructure> {get set}
    var data:Observable<ModelStructure> {get set}
    func reload()
    init()
}
extension ListDataHolderType {

    public static var empty:ListDataHolderType { return Self.init(data: Observable.just(ModelStructure.empty)) }
    public func reload() {
        self.reloadAction.execute(nil)

    }
    public init(data:Observable<ModelStructure>) {
        self.init()
        self.data = data
        self.reloadAction = Action { range in
            return data.flatMapLatest { (s:ModelStructure?) -> Observable<ModelStructure> in
                let result = (s ?? ModelStructure.empty)
                return Observable.just(result)
            }
        }
        
        _ = reloadAction.executionObservables.switchLatest().bindTo(self.models)//.addDisposableTo(bag)
        _ = self.models.asObservable().map{_ in return [IndexPath:ItemViewModelType]()}.bindTo(viewModels)//.addDisposableTo(bag)
         _ = self.models.asObservable().map { return $0.count}.bindTo(resultsCount)//.addDisposableTo(bag)
        
    }
}
public final class ListDataHolder : ListDataHolderType {
    
    
    public var reloadAction: Action<ResultRangeType?, ModelStructure> = Action {_ in return Observable.just(ModelStructure.empty)}
    public var models:Variable<ModelStructure> = Variable(ModelStructure.empty)
    public var viewModels:Variable = Variable([IndexPath:ItemViewModelType]())
    public var resultsCount:Variable<Int> = Variable(0)
    public var newDataAvailable:Variable<ResultRangeType?> = Variable(nil)
    public var data:Observable<ModelStructure>
    public init() {
        self.data = .just(ModelStructure.empty)
    }
    
}
public protocol ListViewModelType : ViewModelType {
    var dataHolder:ListDataHolderType {get set}
    func identifierAtIndex(_ index:IndexPath) -> ListIdentifier?
    func modelAtIndex (_ index:IndexPath) -> ModelType?
    func itemViewModel(_ model:ModelType) -> ItemViewModelType?
    func listIdentifiers() -> [ListIdentifier]
    
    func reload()
    init()
}


public protocol ListViewModelTypeHeaderable : ListViewModelType {
    func headerIdentifiers() -> [ListIdentifier]
}
public extension ListViewModelType  {
    
    var isEmpty:Observable<Bool> {
        return self.dataHolder.resultsCount.asObservable().map {$0 == 0}
    }
    
    public func identifierAtIndex(_ index:IndexPath) -> ListIdentifier? {
        return self.viewModelAtIndex(index)?.itemIdentifier
    }
    public func viewModelAtIndex (_ index:IndexPath) -> ItemViewModelType? {
        
        var d = self.dataHolder.viewModels.value
        let vm = d[index]
        if (vm == nil) {
            let item =  self.itemViewModel(self.modelAtIndex(index)!)
            d[index] = item
            self.dataHolder.viewModels.value = d
            return item
        }
        return vm
    }
    public func itemViewModel(_ model:ModelType) -> ItemViewModelType? {
        if (model is ItemViewModelType) {
            return model as? ItemViewModelType
        }
        return nil
    }
    init(data:Observable<ModelStructure>) {
        self.init()
        self.dataHolder = ListDataHolder(data:data)
    }
    
    //    init() {
    //        self.dataHolder = ListDataHolder(dataProducer:SignalProducer(value:ModelStructure.empty))
    //    }
}

public extension ListViewModelType {
    public func modelAtIndex (_ index:IndexPath) -> ModelType? {
        return self.dataHolder.models.value.modelAtIndex(index)
        
    }
    public func reload() {
        self.dataHolder.reload()
    }
}

public extension ListViewModelType where Self :  ViewModelTypeFailable {
    var fail:Observable<ActionError> { return self.dataHolder.reloadAction.errors }
}
public extension ListViewModelType where Self :  ViewModelTypeLoadable {
    var loading:Observable<Bool> { return self.dataHolder.reloadAction.executing }
}
public extension ListViewModelType where Self :  ViewModelTypeLoadable , Self: ViewModelTypeSelectable {
    var loading:Observable<Bool> {
        return Observable.combineLatest(self.dataHolder.reloadAction.executing, self.selection.executing, resultSelector: { $0 || $1})
        
//        return self.dataHolder.reloadAction.isExecuting.signal.combineLatest(with: (self.selection.isExecuting.signal ?? Signal<Bool,NoError>.empty) ).map {return $0 || $1}
    
    
    }
}
public extension ListViewModelType where Self :  ViewModelTypeFailable , Self: ViewModelTypeSelectable {
    var fail:Observable<ActionError> {
        return Observable.from([self.dataHolder.reloadAction.errors, self.selection.errors], scheduler: MainScheduler.instance).switchLatest()
    }
}

