
# Design Document: Dhisper Backend Canister

## Overview

**Dhisper** is a decentralized social platform built on the Internet Computer (IC) designed to empower users with content ownership, metadata-rich posting, permissioned file storage, and monetizable interactions. This document outlines the backend design for the Dhisper canister (`Canister`) which manages **posts, threads, versions, metadata, access control**, and **ICRC-2 fee-based interactions**.

---

## Architectural Components

### 🔹 Initialization

```motoko
type Kay4.Init
```

The canister is initialized with configurable parameters:

* `max_threads_size`, `max_replies_size`, `max_content_size`: Controls for pagination and content length limits.
* `create_fee_rates`: Customizable fee structures based on content and asset size.
* `default_take_value`, `max_take_value`, `max_query_batch_size`: Defaults and ceilings for pagination in queries.

The canister supports `#Upgrade` deployment which retains `stable` storage and skips re-initialization.

```motoko
switch deploy {
  case (#Init init) => metadata := Kay4.init(...);
  case _ => ();
}
```

### 🔹 Stable Storage Layout

```motoko
stable var metadata : RBTree<Text, Value.Type>
stable var posts : RBTree<PostId, Kay4.Post>
stable var threads : RBTree<ThreadId, RBTree<PostId, ()>>
stable var post_id : Nat
```

* **`metadata`**: Global metadata for the canister.
* **`posts`**: Mapping from post ID to rich post object (`Kay4.Post`) with versioning.
* **`threads`**: Mapping from thread ID to set of post IDs (replies).
* **`post_id`**: Auto-incrementing post ID tracker.

---

## Data Models

### 1. **Post Model** (`Kay4.Post`)

```motoko
type Must = {
	authorization : Kay2.Authorized;
	timestamp : Nat64;
	phash : ?Blob; // hash of previous version, 1st version is null
};
public type Post = {
	thread : ?Nat;
	versions : RBTree<Nat, Must>;
	content_versions : RBTree<Nat, Text>;
	files_versions : RBTree<Nat, RBTree<Text, ()>>;
	owners_versions : RBTree<Nat, RBTree<Kay2.Identity, ()>>;
	metadata_versions : RBTree<Nat, RBTree<Text, Value.Type>>;
	hash : Blob; // integrity of current version
};
```

A post may belong to a thread and supports:

* **Versioning**: All fields are versioned via `RBTree<VersionId, T>`.
* **Content**: Text body stored in `content_versions`.
* **Files**: Associated named assets with binary chunks.
* **Owners**: Multiple identities with version tracking.
* **Metadata**: Arbitrary metadata for semantic extensibility (tips, nested threads, etc.).
* **Hash**: Used for integrity verification and history linkage.

### 2. **Authorization Model** (`Kay2.Authorization`, `Kay2.Authorized`)

```motoko
type Authorization = {
	#ICRC_1 : { 
		subaccount : ?Blob; 
		canister_id : Principal 
	}; 
	#ICRC_2 : { 
		subaccount : ?Blob; 
		canister_id : Principal;
		fee : ?Nat 
	};
	#None : { subaccount : ?Blob };
};
type Authorized = {
	#ICRC_1 : {
		owner : Principal;
		subaccount : ?Blob;
		canister_id : Principal;
		minimum_balance : Nat;
	};
	#ICRC_2 : {
		owner : Principal;
		subaccount : ?Blob;
		canister_id : Principal;
		xfer : Nat; // transfer block id
	}; 
	#None : Account.Pair;
};
```
Authorization is enforced during mutating operations like `kay4_create`.

Caller will provide `Authorization`, and if it passed, then the canister will store the `Authorized`.

Used for:

* **Fee payments** (via `icrc2_transfer_from`), or
* **Ownership control** (via `icrc1_balance_of`).

Could support more variants in the future such as `#ICRC_7` to check if caller have a unit of an NFT collection.

### 3. **Identity Model**

```motoko
type Kay2.Identity = { #ICRC_1 : Account.Pair }
```

Supports user identities with optional subaccounting for fine-grained access. Could support more variants such as `#ICP` which is the Account ID Hash, or other identity variants that might exist in the future.

---

## Core Functions

### `shared func kay4_create(arg: Kay4.CreatePostArg): async Result<Nat, Kay4.CreatePostError>`

#### Purpose

Creates a new **post** (optionally within a thread), validates **authorization**, charges **fees**, and stores the post with a unique ID and content versioning.

---

#### Execution Flow

##### 1. Thread Validation and Capacity Enforcement

```motoko
switch (arg.thread) {
  case (?op_id) switch (RBTree.get(threads, Nat.compare, op_id)) {
    case (?thread_replies) {
      let max_replies = Value.getNat(metadata, Kay4.MAX_REPLIES, 0);
      if (max_replies > 0 and RBTree.size(thread_replies) >= max_replies)
        return Error.text("Cannot reply anymore; thread has entered read-only mode");
    };
    case _ return #Err(#UnknownThread);
  };
  case _ ();
};
```

* If a thread ID is provided:

  * Verify the thread exists.
  * Enforce maximum replies limit from metadata (`MAX_REPLIES`).
* Otherwise, the post starts a new thread.

---

##### 2. Content Normalization and Validation

```motoko
let content = Kay4.cleanText(arg.content);
if (Text.size(content) == 0) return Error.text("Content cannot be empty");
let content_max = Value.getNat(metadata, Kay4.MAX_CONTENT, 0);
```

* Trims/normalizes content.
* Rejects empty content.
* Retrieves content size limit (`MAX_CONTENT`) for fee calculation.

---

##### 3. File Attachment Restriction (Placeholder)

```motoko
if (arg.files.size() > 0) return Error.text("Dhisper is text-only for now. File system is not ready yet.");
```

* File attachments are currently not supported.

---

##### 4. Authorization and Fee Processing

```motoko
let (authorized, identity) = switch (arg.authorization) {
  case (#ICRC_2 auth) {
    let user = { owner = caller; subaccount = auth.subaccount };
    let expected_fee = switch (getFee({ 
      auth with content_size; content_max; 
      fee_key = Kay4.CREATE_FEE_RATES })) {
      case (#Ok ok) ok;
      case (#Err err) return #Err err;
    };
    let token = ICRC_2.genActor(auth.canister_id);
    let transfer_from_args = {
      amount = expected_fee;
      from = user;
      to = dhisper_account;
      ...
    };
    let transfer_from_id = switch (await token.icrc2_transfer_from(transfer_from_args)) {
      case (#Err err) return #Err(#Unauthorized(#ICRC_2(#TransferFromFailed err)));
      case (#Ok ok) ok;
    };
    (#ICRC_2 { auth with owner = caller; xfer = transfer_from_id }, #ICRC_1 user);
  };
  case _ return Error.text("Other authorizations are not implemented yet");
};
```

* Validates authorization (only `ICRC_2` supported for now).
* Retrieves expected fee using `getFee` (detailed below).
* Charges fee via `icrc2_transfer_from`.
* Returns #Error if fee transfer fails.

---

##### 5. Thread Update or Initialization

```motoko
let (thread_id, thread_replies) = switch (arg.thread) {
  case (?op_id) switch (RBTree.get(threads, ...)) {
    case (?replies) (op_id, RBTree.insert(...));
    case _ (new_post_id, RBTree.empty());
  };
  case _ (new_post_id, RBTree.empty());
};
```

* If replying to an existing thread, append the replies.
* If original thread was deleted after fee payment, fallback to create this post as a new thread.

---

##### 6. Post Construction and Registration

```motoko
threads := RBTree.insert(...);
let new_post = Kay4.createPost(...);
posts := RBTree.insert(...);
post_id += 1;
#Ok new_post_id;
```

* Post is created & hashed via `Kay4.createPost` (detailed below).
* Added to `posts` and `threads`.
* Global `post_id` counter is incremented.

---

#### Inputs: `Kay4.CreatePostArg`

| Field           | Description                                |
| --------------- | ------------------------------------------ |
| `thread: ?Nat`        | Optional ID of thread being replied to     |
| `content: Text`       | Text content to post                       |
| `files: [Kay3.CreateArg]`         | File attachments (currently disallowed)    |
| `owners: [Kay2.Identity]`        | Future ownership config (currently unused) |
| `metadata: [(Text, Value.Type)]`      | Additional metadata (currently unused)     |
| `authorization: Kay2.Authorization` | Authorization data (must be `ICRC_2` for now)      |

---

#### Outputs

* `#Ok(Nat)`: ID of the newly created post.
* `#Err(Kay4.CreatePostError)`: Specific error variant.

---

#### Errors

| Variant            | Meaning                                            |
| ------------------ | -------------------------------------------------- |
| `#GenericError`    | Catch-all for internal errors or validation issues |
| `#UnknownThread`   | Thread does not exist                              |
| `#Unauthorized`    | Fee transfer failed or bad authorization           |
| `#ContentTooLarge` | (Planned) Content exceeds allowed size             |
| `#Locked`, etc.    | Reserved for future use (files, locking, etc.)     |

---

#### State Mutations

| Variable  | Update Description                     |
| --------- | -------------------------------------- |
| `posts`   | Adds the newly created post            |
| `threads` | Updates existing thread or creates new |
| `post_id` | Auto-incremented to assign new post ID |

---

### `func getFee(...)`

```motoko
func getFee({ ... }) : Result.Type<Nat, { #Unauthorized : Kay2.Unauthorized; #GenericError : Error.Type }>
```

#### Purpose

Validates and calculates the expected fee for a post based on system metadata and content size. Ensures the user-supplied fee matches expected logic.

---

#### Inputs

| Parameter      | Description                                                            |
| -------------- | ---------------------------------------------------------------------- |
| `canister_id: Principal`  | ICRC-2 token canister ID for fee transfer                              |
| `fee: ?Nat`          | User-supplied fee amount (optional)                                    |
| `content_size: Nat` | Size of the content in bytes                                           |
| `content_max: Nat`  | Max content length before overage fees apply                           |
| `fee_key: Text`      | Metadata key used to look up fee rules (e.g., `kay4:create_fee_rates`) |

---

#### Outputs

* `#Ok(expected_fee)`: Correct fee calculated from rules.
* `#Err(...)`: Unauthorized, incorrect fee, or metadata issue.

---

#### Logic

1. Load fee rates from metadata using `fee_key`.
2. Extract `ICRC-2`-specific fee mapping.
3. Validate the `canister_id` is allowed.
4. Extract:

   * `minimum_amount`: Flat base fee
   * `additional_amount_numerator` / `additional_byte_denominator`: Overage parameters
5. Calculate:

   * `overage = (content_size - content_max)`
   * `expected_fee = minimum_amount + (overage * numerator / denominator)`
6. If a `fee` is provided, ensure it matches `expected_fee`.

---

#### Example Fee Rate Metadata

```json
{
  "kay4:create_fee_rates": {
    "ICRC-2": {
      "ryjl3-tyaaa-aaaaa-aaaba-cai": {
        "minimum_amount": 100000,
        "additional_amount_numerator": 1,
        "additional_byte_denominator": 1
      }
    }
  }
}
```

---

#### Failure Conditions

* Fee metadata missing or misconfigured
* `canister_id` not authorized
* Mismatched provided fee

---

#### Design Considerations

* Flexible, metadata-driven fee logic
* Supports overage-based pricing
* Future-ready for supporting other standards or other tokens

---

### `public func Kay4.createPost(...) : Kay4.Post`

#### Purpose

Constructs and returns a fully-formed `Kay4.Post`:

* Includes thread ID, content, ownership, timestamp
* Supports multiple versioned fields (auth, content, etc.)
* Produces a final cryptographic hash over post components

---

#### Hash Design

* Uses `Hasher.sha256` on each component (`authorization`, `content`, `owners`)
* Combines hashes into a unified tree and computes final post hash
* Enables integrity checking and tamper detection

---

#### Versioning Strategy

Each component (e.g., content, authorization) is stored in its own `RBTree`, allowing:

* Future updates with full version history
* Deterministic and hashable state evolution

---

## Queries

### `func kay4_threads(prev: ?ThreadId, take: ?Nat): async [ThreadId]`

Paginated listing of thread IDs, sorted from newest to oldest.

### `func kay4_replies_of(thread_id: ThreadId, prev: ?PostId, take: ?Nat): async [PostId]`

Replies (posts) under a thread, with pagination.

### `func kay4_timestamps_of(post_ids: [PostId]): async [?Timestamp]`

Timestamps for given post IDs, with pagination.

### `func kay4_contents_of(post_ids: [PostId]): async [?Text]`

Textual contents for given post IDs, with pagination.

### `func kay4_owners_of(post_id: PostId, prev: ?Kay2.Identity, take: ?Nat): async [Kay2.Identity]`

Owners of a post, with pagination.

---
