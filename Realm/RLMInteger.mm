////////////////////////////////////////////////////////////////////////////
//
// Copyright 2017 Realm Inc.
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

#import "RLMInteger_Private.hpp"

#import "RLMProperty.h"
#import "RLMRealm_Private.h"
#import "RLMUtil.hpp"

template<typename T> static inline void verifyAttached(__unsafe_unretained T const obj) {
    if (!obj->_row.is_attached()) {
        @throw RLMException(@"Integer has been deleted or invalidated.");
    }
    [obj->_realm verifyThread];
}

template<typename T> static inline void verifyInWriteTransaction(__unsafe_unretained T const obj) {
    verifyAttached(obj);
    if (!obj->_realm.inWriteTransaction) {
        @throw RLMException(@"Attempting to modify integer outside of a write transaction - call beginWriteTransaction on an RLMRealm instance first.");
    }
}

@implementation RLMInteger

- (instancetype)init {
    if (self = [super init]) {
        _value = 0;
    }
    return self;
}

- (instancetype)initWithValue:(NSInteger)value {
    if (self = [super init]) {
        _value = value;
    }
    return self;
}

- (void)incrementValueBy:(NSInteger)delta {
    _value += delta;
}

- (NSNumber<RLMInt> *)boxedValue {
    return @(self.value);
}

@end

@implementation RLMNullableInteger

- (instancetype)init {
    if (self = [super init]) {
        _value = nil;
    }
    return self;
}

- (instancetype)initWithValue:(NSNumber<RLMInt> *)value {
    if (self = [super init]) {
        _value = value;
    }
    return self;
}

- (void)incrementValueBy:(NSInteger)delta {
    if (!_value) {
        @throw RLMException(@"Cannot increment a RLMNullableInteger property whose value is nil. Set its value first.");
    }
    _value = @(_value.integerValue + delta);
}

- (NSNumber<RLMInt> *)boxedValue {
    return self.value;
}

@end

@interface RLMIntegerView () {
    @public
    RLMRealm *_realm;
    realm::Row _row;
    size_t _colIndex;
}
@end

@implementation RLMIntegerView

- (instancetype)initWithValue:(__unused NSInteger)value {
    @throw RLMException(@"Cannot initialize a RLMIntegerView using initWithValue:");
    return nil;
}

- (instancetype)initWithRow:(realm::Row)row columnIndex:(size_t)colIndex realm:(RLMRealm *)realm {
    if (self = [super init]) {
        _row = row;
        _colIndex = colIndex;
        _realm = realm;
    }
    return self;
}

- (void)setValue:(NSInteger)value {
    verifyInWriteTransaction(self);
    _row.get_table()->set_int(_colIndex, _row.get_index(), value, false);
}

- (NSInteger)value {
    verifyAttached(self);
    return _row.get_table()->get_int(_colIndex, _row.get_index());
}

- (void)incrementValueBy:(NSInteger)delta {
    verifyInWriteTransaction(self);
    _row.get_table()->add_int(_colIndex, _row.get_index(), delta);
}

@end

@interface RLMNullableIntegerView () {
    @public
    RLMRealm *_realm;
    realm::Row _row;
    size_t _colIndex;
}
@end

@implementation RLMNullableIntegerView

- (instancetype)initWithValue:(__unused NSNumber<RLMInt> *)value {
    @throw RLMException(@"Cannot initialize a RLMNullableIntegerView using initWithValue:");
    return nil;
}

- (instancetype)initWithRow:(realm::Row)row columnIndex:(size_t)colIndex realm:(RLMRealm *)realm {
    if (self = [super init]) {
        _row = row;
        _colIndex = colIndex;
        _realm = realm;
    }
    return self;
}

- (void)setValue:(NSNumber<RLMInt> *)value {
    verifyInWriteTransaction(self);
    if (value) {
        _row.get_table()->set_int(_colIndex, _row.get_index(), value.longLongValue, false);
    } else {
        _row.get_table()->set_null(_colIndex, _row.get_index());
    }
}

- (NSNumber<RLMInt> *)value {
    verifyAttached(self);
    auto table = _row.get_table();
    if (table->is_null(_colIndex, _row.get_index())) {
        return nil;
    }
    return @(_row.get_table()->get_int(_colIndex, _row.get_index()));
}

- (void)incrementValueBy:(NSInteger)delta {
    verifyInWriteTransaction(self);
    auto table = _row.get_table();
    if (table->is_null(_colIndex, _row.get_index())) {
        @throw RLMException(@"Cannot increment a RLMNullableInteger property whose value is nil. Set its value first.");
    }
    table->add_int(_colIndex, _row.get_index(), delta);
}

@end
