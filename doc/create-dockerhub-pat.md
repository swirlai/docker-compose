### 1. Log in to Docker Hub

Go to:

[Docker Hub](https://hub.docker.com/)

Sign in with your Docker Hub account.

---

### 2. Open Your Account Settings

Click your profile icon (top right) and select:
**Account Settings**

In the new tab that opens, select:
**Personal access tokens**

---

### 3. Create a New Personal Access Token

Click:

**Generate New Token**

---

### 4. Name the New Token

Provide a descriptive name, such as:

***SWIRL Docker Pull Token***


---

### 5. Select Token Permissions (Read-Only)

Choose the permission level:

- **Read Only**
  Allows pulling images from your Docker Hub repositories without granting write or admin access.

---

### 6. Generate the New Token

Click:

**Generate**

Docker Hub will now show the token **once only**.

---

### 7. Copy and Save the Token Securely

Store the token in a secure location as you will not be able to view it again.

---

### 8. Use the Token to Log In via CLI

Run:

```sh
echo "<YOUR_PAT>" | docker login -u <your-docker-username> --password-stdin
````

or use the SWIRL Docker Login script:

```sh
./scripts/docker_loginsh
````

If successful, you will see:

```
Login Succeeded
```

---

You now have a secure, read-only Docker Hub PAT suitable for image pulls in scripts for SWIRL deployments.
