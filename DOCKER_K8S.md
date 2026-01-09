# Docker & Kubernetes Setup

This guide covers installing Docker Desktop and minikube for container and Kubernetes development.

**Note**: `bootstrap.sh` installs kubectl, helm, and docker-compose automatically. Only install Docker Desktop manually if you need the full GUI and development experience.

---

## Docker Desktop for Linux

### Ubuntu 22.04/24.04/25.04/25.10/26.04+

Per [official Docker docs](https://docs.docker.com/desktop/setup/install/linux/ubuntu/):

```bash
# Step 1: Prerequisites
sudo apt update
sudo apt install -y ca-certificates curl gnome-terminal

# Step 2: Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Step 3: Add the repository to Apt sources
# Uses UBUNTU_CODENAME -> VERSION_CODENAME -> questing fallback for future Ubuntu releases
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-${VERSION_CODENAME:-questing}}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

# Step 4: Download and install Docker Desktop
sudo apt update
wget https://desktop.docker.com/linux/main/amd64/docker-desktop-amd64.deb
sudo apt-get install ./docker-desktop-amd64.deb

# Step 5: Clean up downloaded DEB (optional, saves ~600MB)
rm docker-desktop-amd64.deb
```

### Starting Docker Desktop

After installation, start Docker Desktop:

**Via GUI**: Navigate to Docker Desktop in your GNOME/KDE application menu

**Via terminal**:
```bash
systemctl --user start docker-desktop
```

Accept the Docker Subscription Service Agreement when prompted.

To enable Docker Desktop to start automatically on sign-in:
```bash
systemctl --user enable docker-desktop
```

### Docker Hub Sign-in (Optional - for higher pull limits)

Docker Desktop for Linux uses `pass` to store credentials in GPG-encrypted files. Initialize before signing in:

```bash
# Generate a GPG key (enter name and email when prompted)
gpg --generate-key

# Copy your GPG ID from the output (e.g., "3ABCD1234EF56G78")
# Initialize pass with your GPG ID
pass init YOUR_GPG_ID_HERE
```

Now you can sign in to Docker Desktop with increased pull limits. For more details, see [official sign-in docs](https://docs.docker.com/desktop/setup/sign-in/).

### Other Linux Distributions

For Debian, Fedora, Arch, RHEL, and other distributions, see [official Docker Desktop docs](https://docs.docker.com/desktop/setup/install/linux/).

---

## minikube (Local Kubernetes)

### Installation

```bash
# Download and install minikube
curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64

# Start minikube (requires Docker Desktop with sufficient memory)
minikube start
```

### Troubleshooting

#### Fix minikube memory error on Ubuntu 26.04

If you see `RSRC_INSUFFICIENT_CONTAINER_MEMORY` error, Docker Desktop needs more memory allocated:

1. Open Docker Desktop
2. Go to **Settings** → **Resources** → **Advanced**
3. Increase **Memory** to at least 4GB (default is often too low for Kubernetes)
4. Click **Apply & Restart**
5. Run `minikube delete && minikube start` to recreate the cluster

---

## Windows & macOS

For Windows and macOS, Docker Desktop installation is simpler:

- **Windows**: Download from [docker.com](https://www.docker.com/products/docker-desktop/)
- **macOS**: Download from [docker.com](https://www.docker.com/products/docker-desktop/) or use Homebrew: `brew install --cask docker`

minikube installation is similar across platforms - see [minikube docs](https://minikube.sigs.k8s.io/docs/start/).
