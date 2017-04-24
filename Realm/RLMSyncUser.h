////////////////////////////////////////////////////////////////////////////
//
// Copyright 2016 Realm Inc.
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

@class RLMSyncUser, RLMSyncCredentials, RLMSyncPermissionValue, RLMSyncPermissionResults, RLMSyncSession, RLMRealm;

/**
 The state of the user object.
 */
typedef NS_ENUM(NSUInteger, RLMSyncUserState) {
    /// The user is logged out. Call `logInWithCredentials:...` with valid credentials to log the user back in.
    RLMSyncUserStateLoggedOut,
    /// The user is logged in, and any Realms associated with it are syncing with the Realm Object Server.
    RLMSyncUserStateActive,
    /// The user has encountered a fatal error state, and cannot be used.
    RLMSyncUserStateError,
};

/// A block type used for APIs which asynchronously vend an `RLMSyncUser`.
typedef void(^RLMUserCompletionBlock)(RLMSyncUser * _Nullable, NSError * _Nullable);

/// A block type used to report the progress of a permissions set operation.
/// If the `NSError` argument is nil, the operation succeeded.
typedef void(^RLMPermissionStatusBlock)(NSError * _Nullable);

/// A block type used to asynchronously report results of a permissions get operation.
/// Exactly one of the two arguments will be populated.
typedef void(^RLMPermissionResultsBlock)(RLMSyncPermissionResults * _Nullable, NSError * _Nullable);


NS_ASSUME_NONNULL_BEGIN

/**
 A `RLMSyncUser` instance represents a single Realm Object Server user account.

 A user may have one or more credentials associated with it. These credentials
 uniquely identify the user to the authentication provider, and are used to sign
 into a Realm Object Server user account.

 Note that user objects are only vended out via SDK APIs, and cannot be directly
 initialized. User objects can be accessed from any thread.
 */
@interface RLMSyncUser : NSObject

/**
 A dictionary of all valid, logged-in user identities corresponding to their user objects.
 */
+ (NSDictionary<NSString *, RLMSyncUser *> *)allUsers NS_REFINED_FOR_SWIFT;

/**
 The logged-in user. `nil` if none exists.

 @warning Throws an exception if more than one logged-in user exists.
 */
+ (nullable RLMSyncUser *)currentUser NS_REFINED_FOR_SWIFT;

/**
 The unique Realm Object Server user ID string identifying this user.
 */
@property (nullable, nonatomic, readonly) NSString *identity;

/**
 The URL of the authentication server this user will communicate with.
 */
@property (nullable, nonatomic, readonly) NSURL *authenticationServer;

/**
 Whether the user is a Realm Object Server administrator. Value reflects the
 state at the time of the last successful login of this user.
 */
@property (nonatomic, readonly) BOOL isAdmin;

/**
 The current state of the user.
 */
@property (nonatomic, readonly) RLMSyncUserState state;

#pragma mark - Lifecycle

/**
 Create, log in, and asynchronously return a new user object, specifying a custom timeout for the network request.
 Credentials identifying the user must be passed in. The user becomes available in the completion block, at which point
 it is ready for use.
 */
+ (void)logInWithCredentials:(RLMSyncCredentials *)credentials
               authServerURL:(NSURL *)authServerURL
                     timeout:(NSTimeInterval)timeout
                onCompletion:(RLMUserCompletionBlock)completion NS_REFINED_FOR_SWIFT;

/**
 Create, log in, and asynchronously return a new user object. Credentials identifying the user must be passed in. The
 user becomes available in the completion block, at which point it is ready for use.
 */
+ (void)logInWithCredentials:(RLMSyncCredentials *)credentials
               authServerURL:(NSURL *)authServerURL
                onCompletion:(RLMUserCompletionBlock)completion
NS_SWIFT_UNAVAILABLE("Use the full version of this API.");

/**
 Log a user out, destroying their server state, unregistering them from the SDK,
 and removing any synced Realms associated with them from on-disk storage on
 next app launch. If the user is already logged out or in an error state, this
 method does nothing.

 This method should be called whenever the application is committed to not using
 a user again unless they are recreated.
 Failing to call this method may result in unused files and metadata needlessly
 taking up space.
 */
- (void)logOut;

#pragma mark - Sessions

/**
 Retrieve a valid session object belonging to this user for a given URL, or `nil` if no such object exists.
 */
- (nullable RLMSyncSession *)sessionForURL:(NSURL *)url;

/**
 Retrieve all the valid sessions belonging to this user.
 */
- (NSArray<RLMSyncSession *> *)allSessions;

// This set of permissions APIs uses immutable `RLMSyncPermissionValue` objects to
// get and set permissions, using a simplified API. Either this API or the Realm
// Object based API can be used to work with permissions.
#pragma mark - Value-based Permissions API

/**
 Asynchronously retrieve all permissions associated with the given user.

 The results will be returned through the callback block, or an error if the operation fails.
 */
- (void)retrievePermissionsWithCallback:(RLMPermissionResultsBlock)callback;

/**
 Apply a given permission.

 The operation will take place asynchronously, and the callback will be used to report whether
 the permission change succeeded or failed. The user upon which this method is called must have
 the right to grant the given permission, or else the oepration will fail.

 @see `RLMSyncPermissionValue`
 */
- (void)applyPermission:(RLMSyncPermissionValue *)permission callback:(RLMPermissionStatusBlock)callback;

/**
 Revoke a given permission.

 The operation will take place asynchronously, and the callback will be used to report whether
 the permission change succeeded or failed. The user upon which this method is called must have
 the right to grant the given permission, or else the oepration will fail.

 @see `RLMSyncPermissionValue`
 */
- (void)revokePermission:(RLMSyncPermissionValue *)permission callback:(RLMPermissionStatusBlock)callback;

// This set of permissions APIs uses a set of Realms and Realm model objects
// representing various permission states and actions, as well as standard
// Realm affordances, to work with permissions. Either this API or the Realm
// Object based API can be used to work with permissions.
#pragma mark - Realm Object-based Permissions API

/**
 Returns an instance of the Management Realm owned by the user.

 This Realm can be used to control access permissions for Realms managed by the user.
 This includes granting other users access to Realms.
 */
- (RLMRealm *)managementRealmWithError:(NSError **)error NS_REFINED_FOR_SWIFT;

/**
 Returns an instance of the Permission Realm owned by the user.

 This read-only Realm contains `RLMSyncPermission` objects reflecting the
 synchronized Realms and permission details this user has access to.
 */
- (RLMRealm *)permissionRealmWithError:(NSError **)error NS_REFINED_FOR_SWIFT;

#pragma mark - Miscellaneous

/// :nodoc:
- (instancetype)init __attribute__((unavailable("RLMSyncUser cannot be created directly")));

/// :nodoc:
+ (instancetype)new __attribute__((unavailable("RLMSyncUser cannot be created directly")));

NS_ASSUME_NONNULL_END

@end
