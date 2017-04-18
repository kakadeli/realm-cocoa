////////////////////////////////////////////////////////////////////////////
//
// Copyright 2014 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

#import "RLMArray_Private.hpp"

#if 0
#import "RLMAccessor.hpp"
#import "RLMObjectSchema_Private.hpp"
#import "RLMObjectStore.h"
#import "RLMObject_Private.hpp"
#import "RLMObservation.hpp"
#import "RLMProperty_Private.h"
#import "RLMQueryUtil.hpp"
#import "RLMRealm_Private.hpp"
#import "RLMSchema.h"
#import "RLMThreadSafeReference_Private.hpp"
#import "RLMUtil.hpp"

#import "results.hpp"
#import "primitive_list.hpp"

#import <realm/table_view.hpp>
#import <objc/runtime.h>

[[gnu::noinline]]
[[noreturn]]
static void throwError() {
    try {
        throw;
    }
    catch (std::exception const& e) {
        @throw RLMException(e);
    }
}

template<typename Function>
static auto translateErrors(Function&& f) {
    try {
        return f();
    }
    catch (...) {
        throwError();
    }
}

@interface RLMArraySubTable () <RLMThreadConfined_Private>
@end

@implementation RLMArraySubTable {
@public
    realm::PrimitiveList _list;
    realm::TableRef _table;
    RLMRealm *_realm;
    RLMClassInfo *_ownerInfo;
    std::unique_ptr<RLMObservationInfo> _observationInfo;
}

- (RLMArraySubTable *)initWithTable:(realm::TableRef)table
                             realm:(__unsafe_unretained RLMRealm *const)realm
                        parentInfo:(RLMClassInfo *)parentInfo
                          property:(__unsafe_unretained RLMProperty *const)property {
    self = [self initWithObjectType:property.type optional:property.optional];
    if (self) {
        _realm = realm;
        _table = table;
        _ownerInfo = parentInfo;
        _key = property.name;
    }
    return self;
}

- (RLMArraySubTable *)initWithParent:(__unsafe_unretained RLMObjectBase *const)parentObject
                            property:(__unsafe_unretained RLMProperty *const)property {
    return [self initWithTable:parentObject->_row.get_subtable(parentObject->_info->tableColumn(property))
                        realm:parentObject->_realm
                   parentInfo:parentObject->_info
                     property:property];
}

template<typename IndexSetFactory>
static void changeArray(__unsafe_unretained RLMArraySubTable *const ar,
                        NSKeyValueChange kind, dispatch_block_t f, IndexSetFactory&& is) {
    RLMObservationInfo *info = RLMGetObservationInfo(ar->_observationInfo.get(),
                                                     ar->_list.get_origin_row_index(),
                                                     *ar->_ownerInfo);
    if (info) {
        NSIndexSet *indexes = is();
        info->willChange(ar->_key, kind, indexes);
        try {
            f();
        }
        catch (...) {
            info->didChange(ar->_key, kind, indexes);
            throwError();
        }
        info->didChange(ar->_key, kind, indexes);
    }
    else {
        translateErrors([&] { f(); });
    }
}

static void changeArray(__unsafe_unretained RLMArraySubTable *const ar,
                        NSKeyValueChange kind, NSUInteger index, dispatch_block_t f) {
    changeArray(ar, kind, f, [=] { return [NSIndexSet indexSetWithIndex:index]; });
}

static void changeArray(__unsafe_unretained RLMArraySubTable *const ar,
                        NSKeyValueChange kind, NSRange range, dispatch_block_t f) {
    changeArray(ar, kind, f, [=] { return [NSIndexSet indexSetWithIndexesInRange:range]; });
}

static void changeArray(__unsafe_unretained RLMArraySubTable *const ar,
                        NSKeyValueChange kind, NSIndexSet *is, dispatch_block_t f) {
    changeArray(ar, kind, f, [=] { return is; });
}

- (RLMRealm *)realm {
    return _realm;
}

- (NSUInteger)count {
    return _list.size();
}

- (BOOL)isInvalidated {
    return !_list.is_valid();
}

- (BOOL)isEqual:(id)object {
    if (auto array = RLMDynamicCast<RLMArraySubTable>(object)) {
        return array->_table == _table;
    }
    return NO;
}

- (NSUInteger)hash {
    // FIXME: verify that this is valid
    return std::hash<void *>()(_table.get());
}

- (NSUInteger)countByEnumeratingWithState:(__unused NSFastEnumerationState *)state
                                    count:(__unused NSUInteger)len {
    return 0;
}

- (id)objectAtIndex:(NSUInteger)index {
    RLMAccessorContext context(_realm, *_ownerInfo);
    return _list.get(context, index);
}

static void insertValue(RLMArraySubTable *ar, id value, NSUInteger index) {
    if (index == NSUIntegerMax) {
        index = ar->_list.size();
    }
    else if (index > ar->_list.size()) {
        @throw RLMException(@"bad");
    }

    changeArray(ar, NSKeyValueChangeInsertion, index, ^{
        RLMAccessorContext context(ar->_realm, *ar->_ownerInfo);
        ar->_list.insert(context, index, value);
    });
}

- (void)addObject:(id)object {
    insertValue(self, object, NSUIntegerMax);
}

- (void)insertObject:(id)object atIndex:(NSUInteger)index {
    insertValue(self, object, index);
}

- (void)insertObjects:(id<NSFastEnumeration>)objects atIndexes:(NSIndexSet *)indexes {
    changeArray(self, NSKeyValueChangeInsertion, indexes, ^{
        RLMAccessorContext context(_realm, *_ownerInfo);
        NSUInteger index = [indexes firstIndex];
        for (id obj in objects) {
            _list.set(context, index, obj);
            index = [indexes indexGreaterThanIndex:index];
        }
    });
}


- (void)removeObjectAtIndex:(NSUInteger)index {
    changeArray(self, NSKeyValueChangeRemoval, index, ^{
        _list.remove(index);
    });
}

- (void)removeObjectsAtIndexes:(NSIndexSet *)indexes {
    changeArray(self, NSKeyValueChangeRemoval, indexes, ^{
        [indexes enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger idx, BOOL *) {
            _list.remove(idx);
        }];
    });
}

- (void)addObjectsFromArray:(NSArray *)array {
    changeArray(self, NSKeyValueChangeInsertion, NSMakeRange(self.count, array.count), ^{
        RLMAccessorContext context(_realm, *_ownerInfo);
        for (id obj in array) {
            _list.add(context, obj);
        }
    });
}

- (void)removeAllObjects {
    changeArray(self, NSKeyValueChangeRemoval, NSMakeRange(0, self.count), ^{
        _list.remove_all();
    });
}

- (void)replaceObjectAtIndex:(NSUInteger)index withObject:(id)object {
    changeArray(self, NSKeyValueChangeReplacement, index, ^{
        RLMAccessorContext context(_realm, *_ownerInfo);
        _list.set(context, index, object);
    });
}

- (void)exchangeObjectAtIndex:(NSUInteger)index1 withObjectAtIndex:(NSUInteger)index2 {
    changeArray(self, NSKeyValueChangeReplacement, ^{
        _list.swap(index1, index2);
    }, [=] {
        NSMutableIndexSet *set = [[NSMutableIndexSet alloc] initWithIndex:index1];
        [set addIndex:index2];
        return set;
    });
}

- (NSUInteger)indexOfObject:(id)object {
    RLMAccessorContext context(_realm, *_ownerInfo);
    return _list.find(context, object);
}

- (id)valueForKeyPath:(NSString *)keyPath {
    return [super valueForKeyPath:keyPath];
}

- (id)valueForKey:(NSString *)key {
    return [super valueForKey:key];
}

- (void)setValue:(id)value forKey:(NSString *)key {
    // FIXME: does supporting anything other than self make sense here?
    if (![key isEqualToString:@"self"]) {
        [self setValue:value forUndefinedKey:key]; // throws
        return; // unreachable barring shenanigans
    }

    RLMAccessorContext context(_realm, *_ownerInfo);
    for (size_t i = 0, count = _list.size(); i < count; ++i) {
        _list.set(context, i, value);
    }
}

#if 0
- (RLMResults *)sortedResultsUsingDescriptors:(NSArray<RLMSortDescriptor *> *)properties {
    if (properties.count == 0) {
        auto results = translateErrors([&] { return _backingList.filter({}); });
        return [RLMResults resultsWithObjectInfo:*_objectInfo results:std::move(results)];
    }

    auto order = RLMSortDescriptorFromDescriptors(*_objectInfo, properties);
    auto results = translateErrors([&] { return _backingList.sort(std::move(order)); });
    return [RLMResults resultsWithObjectInfo:*_objectInfo results:std::move(results)];
}

- (RLMResults *)objectsWithPredicate:(NSPredicate *)predicate {
    auto query = RLMPredicateToQuery(predicate, _objectInfo->rlmObjectSchema, _realm.schema, _realm.group);
    auto results = translateErrors([&] { return _backingList.filter(std::move(query)); });
    return [RLMResults resultsWithObjectInfo:*_objectInfo results:std::move(results)];
}

- (NSUInteger)indexOfObjectWithPredicate:(NSPredicate *)predicate {
    auto query = translateErrors([&] { return _backingList.get_query(); });
    query.and_query(RLMPredicateToQuery(predicate, _objectInfo->rlmObjectSchema,
                                        _realm.schema, _realm.group));
    auto indexInTable = query.find();
    if (indexInTable == realm::not_found) {
        return NSNotFound;
    }
    auto row = query.get_table()->get(indexInTable);
    return _backingList.find(row);
}
#endif

- (NSArray *)objectsAtIndexes:(__unused NSIndexSet *)indexes {
    // FIXME: this is called by KVO when array changes are made. It's not clear
    // why, and returning nil seems to work fine.
    return nil;
}

- (void)addObserver:(id)observer
         forKeyPath:(NSString *)keyPath
            options:(NSKeyValueObservingOptions)options
            context:(void *)context {
    RLMEnsureArrayObservationInfo(_observationInfo, keyPath, self, self);
    [super addObserver:observer forKeyPath:keyPath options:options context:context];
}

// The compiler complains about the method's argument type not matching due to
// it not having the generic type attached, but it doesn't seem to be possible
// to actually include the generic type
// http://www.openradar.me/radar?id=6135653276319744
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wmismatched-parameter-types"
- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMArray *, RLMCollectionChange *, NSError *))block {
    [_realm verifyNotificationsAreSupported];
//    return RLMAddNotificationBlock(self, _backingList, block);
    return nil;
}
#pragma clang diagnostic pop

@end

#endif
