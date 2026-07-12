# S3 - Simple Storage Service

AWS gives us 3 main storage services:

1. **EBS** - Elastic Block Store
2. **EFS** - Elastic File System
3. **S3** - Simple Storage Service

**EBS** — gives us a raw disk, like a plain HDD/SSD:
- We have to format it and create a file system on it before we can use it.
- We can pick whichever file system suits our OS, then mount it to the instance.
- So EBS is 2 steps: create the file system (format), then mount.
- Can be attached to only one instance at a time, within its AZ.
- An external HDD/SSD is the perfect example.

**EFS** — a managed NFS (Network File System):
- The file system is already decided by AWS — it is always NFS.
- We don't format anything, we just mount it.
- So EFS is a single step: mount.
- Can be attached to multiple systems at a time.
- Microsoft One Drive is the perfect example.

**S3** — completely different, this is object storage:
- We don't worry about file systems or mounting at all.
- We simply create, read, update and delete files through an HTTP/HTTPS API.
- It is like storing a bag in a cloak room — we don't really care where they keep it.
- We get a token when we hand over the bag, and we get the bag back when we hand over the token.

## Quick comparison

| | EBS | EFS | S3 |
|---|---|---|---|
| **Full name** | Elastic Block Store | Elastic File System | Simple Storage Service |
| **Type** | Block storage | File storage | Object storage |
| **File system** | You create it (format + choose type) | Already NFS (AWS decides) | None — there is no file system |
| **Steps to use** | Format + mount (2 steps) | Mount only (1 step) | Nothing to mount — just API calls |
| **Size / capacity** | Provisioned — you pick a fixed size upfront | Grows and shrinks automatically | Effectively unlimited, no provisioning |
| **Who can attach** | One instance at a time, within its AZ | Many instances at once | Anyone with permission, over HTTP/HTTPS |
| **Real-world example** | External HDD/SSD | Shared network drive (OneDrive) | Cloak room (token in, bag out) |

## What makes S3 special

* Not a filesystem — there are no real folders. Even when we see something that looks like a folder, AWS treats the whole path as a single key. It is like dumping all the objects into one big bucket, with no folders inside.
* No provisioning — you never declare a size; it just grows, and you pay only for what you store.
* Eleven 9s durability (99.999999999%) — every object auto-replicated across ≥3 Availability Zones.
* No 3X charge for that durability — to give us eleven 9s, AWS keeps more than 3 copies across those AZs, but it does not charge us 3 times. If we store 100 GB, we pay for 100 GB, not 300 GB. The extra copies are AWS's cost to bear; we are just buying the durability.
* Regional data, global namespace — data lives in one region across AZs, but bucket names are globally unique.
* Strong read-after-write consistency — since Dec 2020, a successful PUT is immediately readable.
* The glue of AWS — Terraform state, CloudTrail logs, ALB access logs, backups, data lakes all land in S3.

## Storage Classes
AWS charges us both to store an object and to retrieve it. Storage classes let us choose which one we optimise for — storage cost or retrieval cost — to bring the bill down. Durability stays the same (eleven 9s) across nearly all classes.

| Storage class | Designed for | AZs | Min duration | Min object size | DevOps example |
|---|---|---|---|---|---|
| **Standard** | Frequent access, ms | ≥3 | – | – | Terraform state, app configs, product images, CDN origin |
| **Intelligent-Tiering** | Changing/unknown access | ≥3 | – | – | User uploads with unpredictable access |
| **Standard-IA** | Infrequent, needs instant access | ≥3 | 30 days | 128 KB | DB backups, infra backups, monthly reports |
| **One Zone-IA** | Infrequent + **re-creatable** | **1** | 30 days | 128 KB | Re-generatable build artifacts, cached/transcoded copies |
| **Glacier Instant Retrieval** | Archive, ~quarterly, ms retrieval | ≥3 | 90 days | 128 KB | Security/compliance logs rarely read but needed instantly |
| **Glacier Flexible Retrieval** | Archive, ~yearly, min–hrs | ≥3 | 90 days | – | Older audit logs you can wait minutes/hours for |
| **Glacier Deep Archive** | Cold archive, <once/year, hrs | ≥3 | 180 days | – | 7-year compliance logs you'll likely never open |

* **The cost flips.** Storage gets cheaper going down; retrieval gets slower and more expensive.
* Minimum duration is a real bill. Delete from Standard-IA after 5 days → still billed for 30. Deep Archive bills 180 days minimum.

### Restore vs no restore (the "Glacier" naming trap)

The deciding word is "Instant."

| Glacier class | Restore needed? | How you read it |
|---|---|---|
| **Glacier Instant Retrieval** | **No** | Direct `GET` — milliseconds, like Standard |
| **Glacier Flexible Retrieval** | **Yes** | `restore-object`, then `GET` (min–hrs) |
| **Glacier Deep Archive** | **Yes** | `restore-object`, then `GET` (12–48 hrs) |
 
> "No restore" != "free to read." Glacier IR still charges a per-GB retrieval fee ($0.03/GB) — it just skips the wait.

### Pricing

| Storage class | Storage /GB-month | Retrieval fee | Retrieval time |
|---|---|---|---|
| **Standard** | $0.023 | Free | Instant (ms) |
| **Intelligent-Tiering** | $0.023 → $0.00099 (auto) | Free¹ | Instant (ms) |
| **Standard-IA** | $0.0125 | $0.01/GB | Instant (ms) |
| **One Zone-IA** | ~$0.01 | $0.01/GB | Instant (ms) |
| **Glacier Instant Retrieval** | $0.004 | $0.03/GB | Instant (ms) |
| **Glacier Flexible Retrieval** | $0.0036 | Bulk: free / Std: $0.01/GB / Expedited: $0.03/GB | 5–12 hrs / 3–5 hrs / 1–5 min |
| **Glacier Deep Archive** | $0.00099 | $0.02/GB (Std) / $0.0025/GB (Bulk) | 12 hrs / 48 hrs |

¹ Intelligent-Tiering charges a monitoring fee of ~$0.0025 per 1,000 objects instead of retrieval fees.

### Example — 10 GB across all classes

Let us say we store **10 GB** for one month, and then pull **all 10 GB back once**. Storage = 10 × storage rate. Retrieval = 10 × retrieval rate (using the Standard retrieval tier for Glacier).

| Storage class | Store 10 GB / month | Retrieve 10 GB once | Total |
|---|---|---|---|
| **Standard** | $0.23 | Free | **$0.23** |
| **Intelligent-Tiering** | $0.23 | Free | **$0.23** |
| **Standard-IA** | $0.125 | $0.10 | **$0.225** |
| **One Zone-IA** | $0.10 | $0.10 | **$0.20** |
| **Glacier Instant Retrieval** | $0.04 | $0.30 | **$0.34** |
| **Glacier Flexible Retrieval** | $0.036 | $0.10 | **$0.136** |
| **Glacier Deep Archive** | $0.0099 | $0.20 | **$0.21** |

**The lesson:** look at storage alone and Glacier IR ($0.04) looks 5× cheaper than Standard ($0.23). But once we retrieve, Glacier IR total ($0.34) is actually **more expensive** than Standard ($0.23) — the retrieval fee flips it. Cheap-to-store classes only win when we rarely touch the data. If we read it often, Standard is the cheaper choice.

### Retrieve from Glacier

```bash
# 1. Kick off the thaw, means restore (does NOT download; runs in background up to 12h)
aws s3api restore-object \
  --bucket my-bucket \
  --key path/to/object \
  --restore-request Days=3,GlacierJobParameters={Tier=Standard}

# 2. Poll until ready — look for ongoing-request="false"
aws s3api head-object --bucket my-bucket --key path/to/object

# 3. Only AFTER the thaw completes, download
aws s3 cp s3://my-bucket/path/to/object ./object
```

If we want to change the tier back to standard:

```bash
aws s3 cp \
  s3://<state-bucket>/remote-state.tfstate \
  s3://<state-bucket>/remote-state.tfstate \
  --storage-class STANDARD \
  --force-glacier-transfer
```

## Versioning

With versioning on, every overwrite or delete **keeps the old copy**. Protects against accidental overwrite, deletion, and ransomware.
 
### Key facts
- **Each version is a complete, independent copy** — not a diff or a layer. 5 terraform applies on a tfstate = 5 full copies, each retrievable by its own `VersionId`.
- **Unlimited versions** — S3 imposes no cap. There is **no "max versions" bucket setting**.
- **Unlimited versions = unlimited billing** — every version is billed like a separate object. Nothing is ever truly deleted; it just becomes *noncurrent* and keeps costing money.
- The only way to cap versions is a **lifecycle rule** (see below).

### Current vs noncurrent
```
Upload v1   → v1 is CURRENT
Upload v2   → v1 becomes NONCURRENT, v2 is CURRENT
```
 
Versioning protects against overwrite/delete — but it is **not a backup by itself**. Everything still lives in one bucket in one region. For region/bucket failure, you need **replication**.

### Examples
- **Config / source files** — roll back a broken `app-config.json` instantly.
- **Static website files** — recover a bad `index.html` push.
- **Backups bucket + ransomware** — attacker overwrites/deletes; noncurrent versions survive (pairs with MFA Delete).
- **Data pipelines** — a bad ETL overwrites a clean dataset; pre-corruption copy is preserved.

### Delete Markers
 
**With versioning on, a normal delete doesn't delete — it hides.** S3 adds a **delete marker** as the new current version, hiding everything underneath. The object vanishes from `aws s3 ls` but all real versions remain.
 
```
Before delete:          After delete:
  v3 (current)            delete marker (current)  ← hides everything
  v2                      v3
  v1                      v2
                          v1   ← all still here, just hidden
```
 
| Action | What happens | Recoverable? |
|---|---|---|
| `delete-object` (no version ID) | Adds delete marker, **hides** object | ✅ Yes — remove the marker |
| `delete-object --version-id <id>` | **Permanently destroys** that version | ❌ No |
 
#### Recovering a "deleted" object
```bash
aws s3api list-object-versions --bucket my-bucket --prefix data.zip
aws s3api delete-object --bucket my-bucket --key data.zip --version-id <DELETE_MARKER_ID>
```
 
#### Permanently deleting a specific version
Targeting a `VersionId` is **irreversible**. When you permanently delete the **current** version, the **next-most-recent version is promoted back to current** (a clean rollback technique).
 
```
Before:                  After deleting v3 by VersionId:
  v3 (current)  ←delete     v2 (current)  ← v2 promoted back
  v2                         v1
  v1
```

## Lifecycle Rules
 
Automate moving data down the tiers as it cools, and deleting it when it's worthless. Two rule types:
 
| | **Transition** | **Expiration** |
|---|---|---|
| **Does** | Moves to a cheaper class | Deletes entirely |
| **Answers** | "How do I store this cheaper?" | "When is this safe to throw away?" |
 
### Transition example (logs cooling down)
```
Day 0    → Standard
Day 30   → Standard-IA
Day 90   → Glacier
Day 2555 → DELETE  (7-year retention over — the expiration half)
```
 
### Expiration examples
1. **Logs past retention** — delete after 90 days (or 7 years for compliance).
2. **Abandoned incomplete multipart uploads** — the hidden cost. Failed uploads leave billed-but-invisible parts. Abort after 7 days. *AWS recommends this on every bucket.*
3. **Temp/scratch data** — delete objects in `tmp/` after 1 day.
4. **Nightly exports** — delete `exports/` after 7 days.
5. **Old noncurrent versions** — see below.
6. **Expired delete markers** — lifecycle can clean up markers sitting on nothing.

### Two expiration *types*
- **Expire current objects by age** — logs, temp files, failed uploads.
- **Expire noncurrent versions** — the tfstate version-cleanup case.

### Capping versions (the tfstate case)
There is no "max versions" setting — you enforce it with lifecycle:
 
```json
{
  "NoncurrentVersionExpiration": {
    "NoncurrentDays": 30,
    "NewerNoncurrentVersions": 10
  }
}
```
 
Reads as: **"keep the 10 newest noncurrent versions; of the rest, delete any that have been noncurrent for 30+ days."** The current version is never touched and doesn't count toward the 10.
 
### `NoncurrentDays` — what the clock measures
It counts **time spent as a noncurrent version**, starting the moment a newer version *demotes* it — **not** from upload date, **not** from bucket creation.
 
```
Upload v1   → v1 CURRENT      (clock NOT running)
Upload v2   → v1 NONCURRENT   (v1's clock starts at day 0)
30 days     → v1 has NoncurrentDays = 30 → eligible
```
 
A version could be years old in wall-clock time but have `NoncurrentDays = 2` if only just superseded. Each version ages on its own independent clock.
 
### Timing gotchas
- Lifecycle is evaluated **~once a day, asynchronously** — eligible objects may take ~24h to actually delete.
- **Two clocks stack:** a version waits out `NoncurrentDays` (eligibility), *then* up to ~24h (daily evaluation).

| Rule | When does the 11th-oldest version delete? |
|---|---|
| `NewerNoncurrentVersions: 10` only (no days) | Eligible immediately → deleted within ~24h |
| `NewerNoncurrentVersions: 10` + `NoncurrentDays: 30` | Must age 30 days first → *then* deleted within ~24h |
 
### Cost gotcha
Transition requests aren't free (~$0.05 per 1,000 to Glacier). Transitioning millions of tiny objects can cost more than it saves — AWS no longer auto-transitions sub-128 KB objects by default.

If we want only versions and don't care about days, use this:

```json
{
  "Rules": [
    {
      "ID": "keep-2-noncurrent-versions",
      "Status": "Enabled",
      "Filter": {},
      "NoncurrentVersionExpiration": {
        "NewerNoncurrentVersions": 2
      }
    }
  ]
}
```

```bash
aws s3api put-bucket-lifecycle-configuration \
  --bucket <bucket-name> \
  --lifecycle-configuration file://lifecycle.json
```

## Replication (CRR / SRR)
 
A **second, deliberately configured copy** to another bucket. Different from durability (which is free, automatic, multi-AZ).
 
- **CRR (Cross-Region Replication)** — copy to a bucket in a *different* region. DR, compliance/data-residency, lower latency for distant users.
- **SRR (Same-Region Replication)** — copy to a *different* bucket in the *same* region. Log aggregation, prod→test copies, separate-account backups.
- **Requires versioning** enabled on both source and destination.
- **Asynchronous** — objects arrive at the destination a bit later, not instantly.
- Replicates only objects created **after** the rule is enabled (existing objects need S3 Batch Replication to backfill).
- Can replicate **across AWS accounts** — the strong DevSecOps pattern.

### Does deleting in the source delete in the replica?
**By default, NO — and that's a safety feature.**
 
| Action in source | Replicated to destination? |
|---|---|
| New object / overwrite | ✅ Yes (async) |
| Normal delete (delete marker) | ❌ No by default; ✅ marker only, if `DeleteMarkerReplication` enabled |
| Permanent delete (`--version-id`) | ❌ **Never**, no matter what |
 
**Why:** replication is meant to *protect* data. If deletes cascaded, ransomware or a fat-fingered script in the primary would wipe the backup too. Making deletes hard to propagate is intentional. This is why **cross-account replication** is a genuine ransomware/insider-threat defense — compromised credentials in the primary can't reach across to destroy the replica.
 
> **Caveat:** because deletes don't propagate, the replica can accumulate objects the source no longer has, and may grow larger (and cost more) over time. Manage the replica's lifecycle rules independently.
 
### Replication for Terraform state?
 
For "someone deleted it by mistake," **versioning is the cleaner answer** — instant, lag-free, no second bucket, and Terraform never has to know. Replication earns its place for **bucket/region-level disaster**, not accidental deletion (replication is async, so the replica can lag the latest apply).
 
**One-liner:** *versioning protects the object inside the bucket; replication protects against losing the bucket. "Deleted by mistake" is an object problem — reach for versioning.*

## Security
Security is layered — each layer assumes the one before it might fail:

- **Block Public Access** → can't be accidentally exposed. Only turn (part of) it off for a deliberate public case like static website hosting.
- **IAM / bucket policies** → least privilege, only the right identities.
- **Encryption at rest** → useless bytes even if leaked.
- **Versioning + MFA Delete** → can't be destroyed.
- **Replication** → can't be lost entirely.

### The three ways to grant access
| Mechanism | Attached to | Answers | Use when |
|---|---|---|---|
| **IAM policy** | A user / role (identity) | "What can *this identity* do?" | Default — your own org's access |
| **Bucket policy** | The bucket (resource) | "Who can touch *this bucket*?" | Cross-account, conditions (force HTTPS), public buckets |
| **ACL** | Bucket/object (legacy) | Coarse grants | Almost never — AWS recommends disabling |


#### How they combine
Within a single account, access is granted if either the IAM policy OR the bucket policy allows it (and nothing denies it). They're additive(OR) — permission from either side works.

But an explicit Deny in either one always wins. A deny beats any allow, from either policy. This is how you enforce hard rules — e.g. a bucket policy that denies all non-HTTPS traffic overrides every allow anywhere.

So the evaluation logic:

* Any explicit Deny anywhere → denied. (deny always wins)
* Otherwise, an Allow in IAM or bucket policy → allowed.
* No allow anywhere → denied (implicit deny by default).

### Presigned URLs
A time-limited HTTPS link that grants temporary access to a **private** object — no public exposure, no shared credentials. Permission and expiry are baked into the URL's signature.
 
```bash
aws s3 presign s3://my-bucket/private-report.pdf --expires-in 3600
```
 
Uses: temporary download links, time-boxed upload access (presigned PUT), sharing artifacts/logs with someone outside the account without onboarding them to IAM. The object stays private throughout; you never touch BPA.

### MFA Delete
Requires a physical second factor before:
- Permanently deleting any object **version**
- Suspending **versioning** on the bucket

Closes the "anyone with delete permission can permanently nuke a version" gap. Even compromised credentials or a malicious insider can't destroy versioned data without the MFA device.
 
> Can only be enabled by the **root account** — reserve it for genuinely critical buckets (state, backups, compliance archives), not every bucket.

only AWS CLI/SDK can do this not console

```bash
aws s3api put-bucket-versioning \
  --bucket <bucket-name> \
  --versioning-configuration Status=Enabled,MFADelete=Enabled \
  --mfa "<MFA_ARN> <6-digit-code>" \
  --profile <root-profile>
```

verify it worked
```bash
aws s3api get-bucket-versioning \
  --bucket <bucket-name> \
  --profile <root-profile>
```
expected output
```json
{
    "Status": "Enabled",
    "MFADelete": "Disabled"
}
```

Edit S3 bucket policy it should have
```json
{
    "Version": "2012-10-17",
    "Id": "MFADeletePolicy",
    "Statement": [
        {
            "Sid": "DenyDeleteExceptRootUser",
            "Effect": "Deny",
            "NotPrincipal": {
                "AWS": "<root_user_arn>"
            },
            "Action": [
                "s3:DeleteObject",
                "s3:DeleteObjectVersion"
            ],
            "Resource": "arn:aws:s3:::<bucket-name>/*"
        }
    ]
}
```

Now How to delete? only root can delete

```bash
aws s3api delete-object \
  --bucket <bucket-name> \
  --key "s3-version-test.txt" \
  --version-id "version-id" \
  --mfa "<MFA_DEVICE> <fresh_code>" \
  --profile <root-profile>
```

Disable MFA delete
```bash
aws s3api put-bucket-versioning \
  --bucket <bucket-name> \
  --versioning-configuration Status=Enabled,MFADelete=Disabled \
  --mfa "<MFA_ARN> <fresh-6-digit-code>" \
  --profile <root-profile>
```
 
### Worked example — a properly secured tfstate bucket
Every layer at once:
1. **Block Public Access: ON** — never internet-reachable.
2. **Bucket policy** — only CI/CD + engineer roles; deny non-HTTPS.
3. **IAM policy** — least privilege (this one bucket, nothing more).
4. **Encryption at rest** — encrypted
5. **Versioning: ON** — recover accidental overwrite/delete.
6. **MFA Delete** — no permanent version deletion without the token.
7. **Replication (optional)** — CRR for region-level DR.

## Static Website Hosting
 
S3 can serve a website **directly** — no server, no EC2, no nginx. Drop HTML/CSS/JS in a bucket, enable hosting, and S3 serves it. Infinite scale, near-zero cost, nothing to patch.
 
### Static vs dynamic (the boundary)
- **Static** = files served as-is (HTML, CSS, client-side JS). ✅ S3 can do this.
- **Dynamic** = server runs code per request (PHP, Node backend, DB queries, SSR). ❌ S3 cannot — no compute.

### Setup
1. Create a bucket, upload files.
2. Enable static website hosting; set **index document** (`index.html`) and optional **error document**.
3. **Disable Block Public Access** + add a public-read bucket policy (the *one* legitimate BPA-off case).
4. Use the website endpoint: `http://bucket-name.s3-website-region.amazonaws.com`.

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": "*",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::my-website-bucket/*"
  }]
}
```
 
### Block Public Access here
Normally we leave BPA on. Static hosting is the one deliberate exception — we turn it off for a bucket whose entire purpose is to be public. The danger is never public buckets; it's *accidentally* public buckets holding *private* data. **Rule: never put anything private in a website bucket, and never disable BPA on a bucket holding private data.**
 
### Limitations
- **No HTTPS on the native website endpoint** (HTTP only). For HTTPS + custom domain + caching, put **CloudFront** in front (S3 origin + CloudFront + Route 53 — the production pattern).
- **Static only**, **public files only**.