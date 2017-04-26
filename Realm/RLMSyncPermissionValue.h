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

#import <Foundation/Foundation.h>

/**
 Access levels which can be granted to Realm Mobile Platform users
 for specific synchronized Realms, using the permissions APIs.

 Note that each permission level implies all the permissions that
 are present within previous permission levels. Specifically,
 users with write permissions for a Realm can always read from
 that Realm, and users with administrative permissions can always
 read or write from the Realm. It is not possible to, for example,
 specify that a user can administer and read from a Realm but not
 write to it.
 */
typedef NS_ENUM(NSUInteger, RLMSyncAccessLevel) {
    /// No permissions whatsoever.
    RLMSyncAccessLevelNone,
    /// User can only read the contents of the Realm.
    RLMSyncAccessLevelRead,
    /// User can read and write the contents of the Realm.
    RLMSyncAccessLevelWrite,
    /// User can read, write, and administer the Realm, including
    /// granting permissions to other users.
    RLMSyncAccessLevelAdmin,
};

NS_ASSUME_NONNULL_BEGIN

/**
 A value representing a permission granted to one or more users with respect to a particular Realm.

 `RLMSyncPermissionValue` is immutable and thread-safe.
 */
@interface RLMSyncPermissionValue : NSObject

/**
 The path to the Realm to which this permission applies.
 */
@property (nonatomic, readonly) NSString *path;

/**
 The access level described by this permission.
 */
@property (nonatomic, readonly) RLMSyncAccessLevel accessLevel;

/// Whether the access level allows the user to read from the Realm.
@property (nonatomic, readonly) BOOL mayRead;

/// Whether the access level allows the user to write to the Realm.
@property (nonatomic, readonly) BOOL mayWrite;

/// Whether the access level allows the user to administer the Realm.
@property (nonatomic, readonly) BOOL mayManage;

/**
 Create a new sync permission value, for use with permission APIs.

 @param path            The path to the Realm whose permission should be modified (e.g. "/path/to/realm")
 @param userID          The user ID of the user who should be granted access to the Realm at `path`
 @param accessLevel     What access level to grant
 */
- (instancetype)initWithRealmPath:(NSString *)path
                           userID:(NSString *)userID
                      accessLevel:(RLMSyncAccessLevel)accessLevel;

/**
 The user ID of the user to whom these permissions are granted.
 */
@property (nullable, nonatomic, readonly) NSString *userId;

/// :nodoc:
- (instancetype)init __attribute__((unavailable("Use the designated initializer")));

/// :nodoc:
+ (instancetype)new __attribute__((unavailable("Use the designated initializer")));

@end

NS_ASSUME_NONNULL_END