
# Design Document: Dhisper Backend Canister

## Overview

**Dhisper** is a free-to-use decentralized social application built on the Internet Computer (IC) designed to empower users with content ownership, metadata-rich posting, permissioned file storage, and monetizable interactions. This document outlines the backend design for the Dhisper canister (`Canister`) which manages **posts, threads, versions, metadata, access control**, and **ICRC-2 fee-based interactions**.

---

## Architectural Components

### 🔹 Stable Storage Layout

```motoko
stable var metadata : RBTree<Text, Value.Type>
stable var posts : RBTree<PostId, Post2>
stable var threads : RBTree<ThreadId, RBTree<PostId, ()>>
stable var bumps : RBTree<PostId, ThreadId>
stable var post_id : Nat
```

* **`metadata`**: Global metadata for the canister.
* **`posts`**: Mapping from post ID to rich post object (`Post2`) with versioning.
* **`threads`**: Mapping from thread ID to set of post IDs (replies).
* **`bumps`**: Mapping from latest reply ID of the thread to the thread ID.
* **`post_id`**: Auto-incrementing post ID tracker.

---

## Data Models

### 1. **Post Model** (`Post2`)

```motoko
type Must2 = {
  authorization : Authorized;
  timestamp : Nat64;
};
public type Post2 = {
  thread : ?ThreadId;
  versions : RBTree.RBTree<VersionId, Must2>;
  content_versions : RBTree.RBTree<VersionId, Text>;
  files_versions : RBTree.RBTree<VersionId, RBTree.RBTree<Text, ()>>;
  owners_versions : RBTree.RBTree<VersionId, RBTree.RBTree<Identity, ()>>;
  metadata_versions : RBTree.RBTree<VersionId, Value.Metadata>;
  tips : RBTree.RBTree<TipId, ()>;
  report : ?ReportId;
};
```

* **`Must2`**: Stores the authorization and timestamp of each new version of the Post.
* **`Post2`**: Tracks each versioned properties, along with the thread it's replying to (if any), the tips it received (if any), and the report (if any). 

### 2. **Authorization Model** (`Authorization`, `Authorized`)

```motoko
type Authorization = {
	#ICRC_2 : { 
		subaccount : ?Blob; 
		canister_id : Principal;
		fee : ?Nat 
	};
	#None : { subaccount : ?Blob };
};
type Authorized = {
	#ICRC_2 : {
		owner : Principal;
		subaccount : ?Blob;
		canister_id : Principal;
		xfer : Nat; // transfer block id
	}; 
	#None : { owner : Principal; subaccount : ?Blob };
};
```
Authorization is enforced during mutating operations like `kay4_create`.

Caller will provide `Authorization`, and if it passed, then the canister will store the `Authorized`.

Used for fee payments (via `icrc2_transfer_from`), or ownership control in the future (via `icrc1_balance_of`).

Could support more variants in the future such as `#ICRC_7` to check if caller have a unit of an NFT collection.

### 3. **Identity Model**

```motoko
type Identity = { #ICRC_1 : { owner : Principal; subaccount : ?Blob } }
```

Supports user identities with optional subaccounting for fine-grained access. Could support more variants such as `#ICP : Blob` which is the Account ID Hex, or other identity variants that might exist in the future.

---

## Update Endpoints

### `shared func kay4_create(arg: CreatePostArg): async Result<Nat, CreatePostError>`

The `kay4_create` function allows users to create a new post (either a new thread or a reply to an existing one) in a decentralized forum-like application. It supports two types of access:

* **Free tier (`#None`)** with usage limits and cooldowns
* **Paid tier (`#ICRC_2`)** with configurable fees and bypasses some restrictions

---

#### Authorization Models

##### 1. `#None` (Free Tier)

* Identified by a principal and an optional subaccount.
* Must follow cooldown and character limit rules per metadata.
* Cannot bump threads.
* Metadata path: `authorizations.None.create`

##### 2. `#ICRC_2` (Paid Tier)

* User pays tokens using the ICRC-2 standard `icrc2_transfer_from`.
* Fee is calculated based on:

  * **Minimum amount**
  * **Additional cost** per extra character beyond defined limit
* Requires correct metadata and expected fee to be provided.
* Metadata path: `authorizations.ICRC_2.<canister_id>.create`
* Successful payments can bump threads and extend capabilities.

---

####  Input Structure: `CreatePostArg`

```motoko
type CreatePostArg = {
  thread: ?Nat,                 // Optional thread ID for replies
  content: Text,                // Main text content of the post
  owners: [Identity],      // Must be empty for now
  metadata: [(Text, Value.Type)], // Must be empty for now
  authorization: Authorization, // Either None or ICRC_2
}
```

---

####  Output

```motoko
Result.Type<Nat, CreatePostError>
```

Returns:

* `#Ok(post_id)` on success
* `#Err(error)` on failure

---

####  Core Validation Flow

1. **Early Checks**

   * Reject if `owners`, `metadata`, or `files` are non-empty
   * Require non-empty `content`

2. **Authorization Validation**

   * **Free tier**: Check cooldown & character limit

     * Enforces time-based posting limits using previous post timestamps
   * **Paid tier**:

     * Calculates required fee
     * Validates via `icrc2_transfer_from`
     * Fails if fee mismatch or transfer error

3. **Thread Handling**

   * If replying:

     * Validate thread exists
     * Prevent reply if thread hit max replies
     * Apply cooldown based on previous `#None` or `#ICRC_2` post
   * If new thread:

     * Use `post_id` as new thread ID
     * Mark it bumpable if allowed

4. **Bump Logic**

   * Only paid posts can bump threads
   * Bumps are removed and re-added if user pays again

5. **Post Creation**

   * Compose post using timestamp, content, owner, and authorization
   * Insert into global posts tree
   * Increment `post_id`

---

####  Metadata-Driven Configurations

All limits and rules (e.g., cooldowns, fees, character limits) are stored and accessed dynamically from the provided `metadata`.

* **Structure**:

  ```
  authorizations
    ├── None
    │     └── create
    │           ├── reply_character_limit
    │           ├── reply_cooldown
    │           ├── thread_character_limit
    │           └── thread_cooldown
    └── ICRC_2
          └── <canister_id>
                └── create
                      ├── reply_character_limit
                      ├── reply_minimum_amount
                      ├── reply_additional_amount_numerator
                      ├── reply_additional_character_denominator
                      ├── thread_character_limit
                      ├── thread_minimum_amount
                      ├── thread_additional_amount_numerator
                      └── thread_additional_character_denominator
  ```

---

####  Error Handling

##### Common Error Cases

* `#ContentTooLarge`
* `#TemporarilyUnavailable` (due to cooldown)
* `#UnknownThread`
* `#Unauthorized` (fee mismatch, bad canister, transfer failure)
* `#GenericError` (unexpected runtime error)

---

####  Extensibility

Future support planned:

* File upload system (`arg.files`)
* Multiple owners
* More flexible metadata/authorization schemas

---

Sure! Here's the high-level design description in markdown, starting with the appropriate heading:

---

### `shared func kay4_delete(arg : DeletePostArg) : async Result.Type<(), DeletePostError> `

The `kay4_delete` function allows authorized users to delete a previously created post (either a thread or a reply). Only **free-tier posts** (`#None` authorization) can be deleted, and only under specific ownership rules.

---

#### Authorization Rules

* Only supports `#None` authorization as deletion is free.
* Caller must be the **post owner** to delete their own posts OR
* Caller must be the **owner of the paid thread** to delete any free replies within their threads.

---

#### Input Type: `DeletePostArg`

```motoko
type DeletePostArg = {
  id: Nat;                          // ID of the post to delete
  authorization: Authorization; // Only #None is supported
};
```

---

#### Output Type: `Result.Type<(), DeletePostError>`

```motoko
type DeletePostError = {
  #GenericError : Error.Type;
  #UnknownPost;
  #Unauthorized : Unauthorized;
};
```

---

#### Execution Flow

1. **Check Availability**

   * Uses shared `Kay1.isAvailable(metadata)` to ensure service is active.
   * Returns a `GenericError` if the service is unavailable.

2. **Post Lookup**

   * Fetches the post from posts tree using the given `id`.
   * Returns `#UnknownPost` if it doesn't exist.

3. **Authorization Validation**

   * Only `#None` authorization is supported; other types are rejected.
   * Verifies if the caller is the owner of the post via `getOwners`.

   **If caller is not the post owner:**

   * If it's a **reply**, and caller owns the **thread**, deletion is allowed **only if** the thread was **paid (`#ICRC_2`)**.
   * Otherwise, the call fails with a relevant error:

     * `"Free thread owners cannot delete other posts"` or
     * `"Caller is not the post owner"`

4. **Duplicate Delete Check**

   * If the post content is already empty (`""`), the post is considered already deleted.

5. **Post Deletion**

   * Calls `deletePost()` to create a new version of the post marked as deleted.
   * Updates the posts tree with the deleted version using the same post ID.


---

#### Error Conditions

* `#UnknownPost`: Post ID not found.
* `#Unauthorized`: Caller doesn't have permission based on ownership rules.
* `"Free thread owners cannot delete other posts"`: Special rule against free-tier thread owners deleting replies.
* `"This post is already deleted"`: Prevents double-deletion.

---

#### Extensibility

This design can later be extended to:

* Add role-based deletion (e.g., moderators or DAO-controlled authority).

---

## Query Endpoints

### `shared query func kay4_metadata`

Returns the entire metadata map as an array of key-value pairs.

#### Output

```motoko
async [(Text, Value.Type)]
```

#### Use Case

Retrieve all configuration constants and system-level settings currently stored in metadata.

---

### `shared query func kay4_max_threads_size`

Gets the configured maximum size limit for threads.

#### Output

```motoko
async ?Nat
```

#### Use Case

Used by frontends or paginators to understand thread limits set in metadata.

---

### `shared query func kay4_max_replies_size`

Fetches the maximum number of replies allowed per thread from metadata.

#### Output

```motoko
async ?Nat
```

#### Use Case

Helps enforce limits on reply creation from the client or server.

---

### `shared query func kay4_authorizations`

Returns the map of authorization settings currently stored.

#### Output

```motoko
async [(Text, Value.Type)]
```

#### Use Case

View system-wide authorization policies and settings (e.g., token fees, allowed actions).

---

### `shared query func kay4_default_take_value`

Returns the default number of items to take when paginating (if `take` not specified).

#### Output

```motoko
async ?Nat
```

#### Use Case

Standard pagination helper for endpoints like `threads`, `replies_of`, etc.

---

### `shared query func kay4_max_take_value`

Returns the maximum number of items allowed in a pagination `take` parameter.

#### Output

```motoko
async ?Nat
```

#### Use Case

Client-side validation of paging limits to prevent abuse or overload.

---

### `shared query func kay4_max_query_batch_size`

Returns the maximum number of items allowed in a query batch request (e.g. `post_ids` arrays).

#### Output

```motoko
async ?Nat
```

#### Use Case

Used for validating batch API inputs (like in `kay4_authorizations_of`).

---

### `shared query func kay4_threads(prev : ?Nat, take : ?Nat)`

Returns a paginated list of thread IDs, ordered from newly created to old.

#### Input

* `prev`: optional starting point for pagination
* `take`: optional limit of how many IDs to return

#### Output

```motoko
async [Nat]
```

#### Use Case

Display threads in reverse order for feeds, with pagination support.

---

### `shared query func kay4_replies_of(thread_id : Nat, prev : ?Nat, take : ?Nat)`

Returns paginated reply IDs belonging to a given thread, ordered chronologically.

#### Input

* `thread_id`: ID of the thread
* `prev`: optional key for pagination
* `take`: optional limit

#### Output

```motoko
async [Nat]
```

#### Use Case

Used when displaying replies under a thread, with support for pagination.

---

### `shared query func kay4_bumps(prev : ?Nat, take : ?Nat)`

Returns bumped thread IDs, ordered from newly bumped.

#### Input

* `prev`: optional key for pagination
* `take`: optional limit

#### Output

```motoko
async [Nat]
```

#### Use Case

Used to show a “recently active” thread list, for real-time or trending views.

---

### `shared query func kay4_authorizations_of(post_ids : [Nat])`

Batch fetches the authorization type for a list of post IDs.

#### Input

* `post_ids`: list of post IDs

#### Output

```motoko
async [?Authorized]
```

#### Use Case

Helps clients determine if specific posts are free or paid and who can modify/delete them.

---

### `shared query func kay4_timestamps_of(post_ids : [Nat])`

Batch fetches the timestamp for each post in the list.

#### Input

* `post_ids`: array of post IDs

#### Output

```motoko
async [?Nat64]
```

#### Use Case

Useful for rendering creation times of posts without querying them individually.

---

### `shared query func kay4_owners_of(post_id : Nat, prev : ?Identity, take : ?Nat)`

Paginated fetch of all owners associated with a given post.

#### Input

* `post_id`: target post
* `prev`: optional cursor for pagination
* `take`: optional limit

#### Output

```motoko
async [Identity]
```

#### Use Case

Used in user interfaces to show who owns or co-owns a post.

---
