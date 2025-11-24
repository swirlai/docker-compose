### 1. Log in to Docker Hub

Go to:


[Docker Hub](https://hub.docker.com/)


Sign in with your Docker Hub account.

---

### 2. Open the Security Settings

Click your profile icon (top right) → **Account Settings**

Then select:

**Security → Access Tokens**

Or go directly to:


[Security](https://hub.docker.com/settings/security)


---

### 3. Create a New Access Token

Click:

***New Access Token***


---

### 4. Name the Token

Provide a descriptive name, such as:


***Swirl Docker Pull Token***


---

### 5. Select Token Permissions (Read-Only)

Choose the permission level:

- **Read Only**
  Allows pulling images from your Docker Hub repositories without granting write or admin access.

This is the safest setting for automated deployments.

---

### 6. Generate the Token

Click:


***Generate***


Docker Hub will now show the token **once only**.

---

### 7. Copy and Save the Token Securely

Store the token in a secure location:

- a secrets manager
- CI/CD secret store
- Docker credential helper

You will not be able to view it again.

---

### 8. Use the Token to Log In via CLI

Run:

```sh
echo "<YOUR_PAT>" | docker login -u <your-docker-username> --password-stdin
````

or use the Swirl script
```sh
./scripts/docker_loginsh
````

If successful, you will see:

```
Login Succeeded
```

---

You now have a secure, read-only Docker Hub PAT suitable for image pulls in scripts, Swirl deployments, CI/CD pipelines, and container orchestrators.
