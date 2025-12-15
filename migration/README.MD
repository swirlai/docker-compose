# SWIRL Migration Toolkit – README

This archive contains the tools needed to extract, translate, and load a selected subset of configuration objects from an existing Swirl installation into a newer version of Swirl.

These tools are intended for **one-off controlled migrations** performed on behalf of a customer.
They are not general-purpose administrative commands.

This toolkit contains **three phases**:

1. **Extract** (run on the *old* VM)
2. **Translate** (run on the *new* VM using the new Swirl image)
3. **Load** (run on the *new* VM against the target database)

All three phases run inside the same Swirl Docker image as the product itself, via:

```
migration/run_in_container.sh
```

There are additional support scripts for copying local files and packaging artifacts for transfer.

---

## Directory Contents

```
migration/
    extract.py, extract.sh
    translate.py, translate.sh
    load.py, load.sh
    run_in_container.sh
    copy_files.sh
    package_artifacts.sh
```

Files are read from and written to the `migration/` directory.

---

# 1. Extract Phase (old VM)

Extracts model objects from the *current* Swirl deployment (version 4.x).

### Usage:

```
./migration/run_in_container.sh IMAGE_TAG extract [NETWORK] [ARGS...]
```

### Example

```
./migration/run_in_container.sh swirlai/swirl-search:v4_0_0_0 extract -a
```

### Output

* A descriptive file, e.g. `extract_authenticators.json`
* A canonical file used by translation:

  ```
  migration/extract.json
  ```

---

# 2. Translate Phase (new VM)

Converts old-object JSON into the 4.4 schema, applies defaults, strips sensitive fields, and validates data.

### Usage

```
./migration/run_in_container.sh IMAGE_TAG translate [NETWORK] [ARGS...]
```

Default output:

```
migration/load.json
```

---

# 3. Load Phase (new VM)

Loads translated objects into the new database.

Supports:

* Safe upsert mode (default)
* Optional selective deletion (`-d` + per-model delete flags)

### Usage

```
./migration/run_in_container.sh IMAGE_TAG load [NETWORK] [ARGS...]
```

---

# 4. Copy Non-Database Files (old VM)

Copies `.env` and certificates into timestamped backups:

```
sudo ./migration/copy_files.sh
```

Outputs:

```
migration/env_<timestamp>.bak
migration/certs_<timestamp>/
```

---

# 5. Canonical Extract Files

Each extract operation writes:

* A human-readable filename (e.g., `extract_authenticators.json`)
* A canonical working file:

  ```
  migration/extract.json
  ```

This simplifies translation and later steps.

---

# 6. Packaging Migration Artifacts (`package_artifacts.sh`)

After extraction and optional file-copying, bundle all migration artifacts for transfer to the new VM.

### Usage:

```
./migration/package_artifacts.sh FROM_VERSION TO_VERSION
```

Example:

```
./migration/package_artifacts.sh v4_0_0_0 v4_4_0_0
```

### Output

Creates a tar.gz such as:

```
migration_bundle_v4_0_0_0_to_v4_4_0_0_2025-12-12-153000.tar.gz
```

Contents include:

```
migration/
    extract.json
    extract_*.json
    load.json (if translate already run)
    env_*.bak
    certs_*.bak/
    *.py
    *.sh
```

### Transfer

Copy the bundle to the new VM:

### Example run
```
On the source host machine:
  cd /app
  sudo ./migration/run_in_container.sh swirlai/swirl-search-internal:v4_0_0_0 extract app_swirl authenticators search_providers -n Microsoft
  sudo ./migration/package_artifacts.sh v4_0_0_0 v4_4_0_0
  sudo  mv migration_bundle_v4_0_0_0_to_v4_4_0_0_2025-12-12-160114.tar.gz  ~

On the target host machine:
  cd /app
  cp ~/home/migration_bundle_v4_0_0_0_to_v4_4_0_0_2025-12-12-160114.tar.gz .
  gzip -cd migration_bundle_v4_0_0_0_to_v4_4_0_0_2025-12-12-160114.tar.gz | tar -tf -
  sudo ./migration/run_in_container.sh swirlai/swirl-search-internal:develop translate swirl_network
  sudo  ./migration/run_in_container.sh swirlai/swirl-search-internal:develop load swirl_network
```

```
scp migration_bundle_v4_0_0_0_to_v4_4_0_0_2025-12-12-153000.tar.gz user@newvm:/app/
```

This file contains everything needed to run translate and load on the new environment.

---

# 7. Notes

* Sensitive credential fields are intentionally **not** migrated; they must be re-entered after load.
* Extraction and translation do not modify the running system.
* Load operations modify Swirl database entities and must be used carefully.
