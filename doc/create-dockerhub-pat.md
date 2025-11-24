## Creating a GitHub Classic Personal Access Token (PAT) — Read-Only

Follow these steps to create a GitHub Classic PAT with read-only access, suitable for pulling private images or repositories.

---

### 1. Log in to GitHub
Go to:

```

[https://github.com/settings/tokens](https://github.com/settings/tokens)

```

Make sure you are logged into the correct GitHub account.

---

### 2. Open the Classic Tokens Page

Click:

**Developer settings → Personal access tokens → Tokens (classic)**

Or use the direct link:

```

[https://github.com/settings/tokens](https://github.com/settings/tokens)

```

Then click:

**Generate new token → Generate new token (classic)**

---

### 3. Give the Token a Name

Enter a descriptive name such as:

```

Swirl Docker Pull Token

```

---

### 4. Set an Expiration

Choose **30 days**, **60 days**, or a custom expiration window based on your security needs.

---

### 5. Select Read-Only Scopes

To create a minimal-privilege, read-only PAT, check **ONLY** the following:

#### Recommended for Docker image pulls or repo read access:

- **repo:status**
- **repo:read**
  - *This automatically includes `repo:read` permissions needed to clone or pull.*

Do **NOT** select write or admin scopes.

Your selected scopes should look like:

- [x] `repo` (Read Only)
  - Includes: repo:status, repo_deployment, public_repo, repo:invite

*(Do NOT select `repo:write`, `repo:admin` or any non-repo scopes unless required.)*

---

### 6. Generate the Token

Scroll to the bottom and click:

```

Generate token

````

---

### 7. Copy and Save the Token

GitHub will display the token **once only**.

Copy it and store it securely:

- in a secrets manager
- as a GitHub Actions secret
- in Docker credential helpers
- **never** in plain text or source control

---

### 8. Use the Token for Docker Login (example)

```sh
echo "<PAT_TOKEN>" | docker login ghcr.io -u <github-username> --password-stdin
````

Or with the Swirl docker login script :
```sh
./scripts/docker_login.sh
````

---

You now have a **read-only, minimal-privilege GitHub Classic PAT** ready for use.
