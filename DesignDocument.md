
# Design Document: Dhisper Backend Canister (ICP Smart Contract)

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
* `fee_collectors`: Principals authorized to collect fees from canister's balance.
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

Caller will provide `Authorization`, then the canister will store the `Authorized` if the authorization process passed.

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

Creates a new **post** (optionally within a thread), **validates authorization**, **charges fees**, and stores the post with an auto-incrementing ID and initial content version.

#### Detailed Execution Flow

##### 1. **Thread Existence & Capacity Check**

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

* If `arg.thread` is present:
  * Check if thread exists.
  * Enforce `max_replies` from metadata.
* Else, a **new thread** is implied.

##### 2. **Content Cleanup & Size Check**

```motoko
let content = Kay4.cleanText(arg.content);
if (Text.size(content) == 0) return Error.text("Content cannot be empty");
let content_max = Value.getNat(metadata, Kay4.MAX_CONTENT, 0);
```

* Content is normalized (whitespace-trimmed).
* Empty content is rejected.
* `MAX_CONTENT` is retrieved for later fee calculation.

##### 3. **File Attachments (TODO)**

```motoko
if (arg.files.size() > 0) return Error.text("File system not implemented yet.");
```

* Early rejection for file uploads (planned for future implementation).

##### 4. **Authorization & Fee Charging**

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

* Validates caller's `ICRC-2` authorization.
* Retrieves required fee from metadata (`CREATE_FEE_RATES`).
* Transfers fee using `icrc2_transfer_from`.
* If the transfer fails, returns a `#Unauthorized` error with reason.

##### 5. **Thread Handling**

```motoko
let (thread_id, thread_replies) = switch (arg.thread) {
  case (?op_id) switch (RBTree.get(threads, ...)) {
    case (?replies) (op_id, RBTree.insert(...));
    case _ (new_post_id, RBTree.empty());
  };
  case _ (new_post_id, RBTree.empty());
};
```

* If post is a reply and the thread exists, append it.
* If thread disappeared after fee payment, fallback: create new thread with same `PostId`.

##### 6. **Post Creation and Insertion**

```motoko
threads := RBTree.insert(...);
let new_post = Kay4.createPost(...);
posts := RBTree.insert(...);
post_id += 1;
#Ok new_post_id;
```

* Post is constructed using `Kay4.createPost` helper.
* Stored into `posts` with current `post_id`.
* Thread is updated with the new post.
* `post_id` counter is incremented.

---

#### Inputs

##### `Kay4.CreatePostArg`

| Field           | Description                                 |
| --------------- | ------------------------------------------- |
| `thread`        | Optional ID of the thread to reply to       |
| `content`       | Text content to post                        |
| `files`         | Attached files (currently disallowed)       |
| `owners`        | Future ownership configuration (disallowed) |
| `metadata`      | Additional metadata (disallowed)            |
| `authorization` | Authorization object (must be `ICRC_2` for now)     |

---

#### Outputs

* **Success**: `#Ok(Nat)` – the ID of the newly created post.
* **Failure**: `#Err(Kay4.CreatePostError)` – specific error enum.

---

#### Possible Errors

| Variant                          | Description                                   |
| -------------------------------- | --------------------------------------------- |
| `#GenericError`                  | Wraps internal failures or text errors        |
| `#UnknownThread`                 | Supplied `thread` ID doesn't exist            |
| `#ContentTooLarge`               | Not currently triggered, but may be in future |
| `#Unauthorized`                  | Fee validation or Transfer failed             |
| `#Locked`, `#FileTooLarge`, etc. | Reserved for future (e.g., file features)     |

---

#### State Mutations

| Variable  | Change                         |
| --------- | ------------------------------ |
| `posts`   | New post inserted at `post_id` |
| `threads` | Thread ID updated or created   |
| `post_id` | Incremented by one             |

### `func getFee({ canister_id : Principal; fee : ?Nat; content_size : Nat; content_max : Nat; fee_key : Text; }) : Result.Type<Nat, { #Unauthorized : Kay2.Unauthorized; #GenericError : Error.Type }>`

#### Purpose

This function computes the expected fee for posting content based on the size of the content and metadata configuration. It ensures the caller-provided fee matches the expected value based on system-defined parameters.

#### Inputs

* `canister_id`: The ICRC-2 token canister used for fee payment.
* `fee`: The fee amount provided by the user (optional).
* `content_size`: Actual content length (in bytes).
* `content_max`: Maximum size allowed before overage fees apply.
* `fee_key`: Key used to retrieve fee configuration metadata from the system.

#### Outputs

* `#Ok expected_fee`: If the fee is valid and acceptable.
* `#Err`: If the fee is incorrect or the configuration is missing or unauthorized.

#### Logic

1. Fetch fee rate metadata for the specified `fee_key` (e.g., `"kay4:create_fee_rates"`).
2. Extract the ICRC-2-specific fee configuration using the `ICRC_2_KEY` ("ICRC-2").
3. Validate that the provided `canister_id` is authorized.
4. Extract:

   * `minimum_amount`: The minimum base fee.
   * Optionally, `additional_amount_numerator` and `additional_byte_denominator` for overage fee calculations if `content_size > content_max`.
5. Compute the `expected_fee`:

   * `expected_fee = minimum_amount + (excess_bytes * additional_amount_numerator / additional_byte_denominator)`
6. If a fee was provided by the caller, verify it matches `expected_fee`.

#### Example Metadata Structure

```json
{ "kay4:create_fee_rates": 
  { "ICRC-2": 
    { "ryjl3-tyaaa-aaaaa-aaaba-cai": 
      { "minimum_amount": 100000,
        "additional_amount_numerator": 1,
        "additional_byte_denominator": 1 }}}}
```

#### Failure Cases

* Missing metadata keys (`minimum_amount`, etc.)
* Unrecognized token canister ID
* Mismatched fee values

#### Design Notes

* Content size overages are billed proportionally using the `additional_amount_numerator` per `additional_byte_denominator`.
* This mechanism supports flexible, metadata-driven fee strategies without hardcoding values in logic.
* Supports future extension to other token standards or dynamic pricing models.

---

### `public func Kay4.createPost({ thread : ?ThreadId; content : Text; authorization : Kay2.Authorized; timestamp : Nat64; owner : Kay2.Identity; }) : Kay4.Post`

#### Purpose

Constructs a `Kay4.Post` object with:

* **Thread association**, **content**, **authorization**, and **ownership** initialization,
* Support for **versioning** (via RBTree),
* An **integrity hash** over all relevant fields.

---

#### Security Implications

* The use of hashed identity and auth ensures **tamper-proofing** of creator info.
* Each component (auth, content, owners) is **individually hashed** and then globally hashed.
* Enables cryptographic proof or audit trail of post history.

---

#### Design Takeaway

This `createPost` architecture lays the groundwork for:

* **Immutability** via versioning.
* **Auditability** with precise hash tracking.

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
