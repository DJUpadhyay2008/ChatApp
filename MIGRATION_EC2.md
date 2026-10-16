# Migration Guide: Render to AWS EC2

This guide documents migrating the FastAPI backend from Render to an **AWS EC2 (Ubuntu 24.04 or Amazon Linux 2023)** instance.

**Crucial Architecture Guarantee**: Because the Flutter client (both Android APK and Web) uses configurable endpoints (`API_BASE_URL` and `WS_BASE_URL`), **zero frontend code changes** are required when migrating.

---

## Why Migrate to AWS EC2?
- **No Sleep / Cold Starts**: EC2 instances run continuously 24/7 without the 15-minute inactivity spin-down of Render free tier.
- **Persistent WebSockets**: WebSockets remain connected uninterrupted.
- **AWS Free Tier**: An `t2.micro` or `t3.micro` instance provides 750 hours/month free for the first 12 months.

---

## 1. Launching the EC2 Instance

1. In the AWS Management Console, launch a **t3.micro** or **t2.micro** instance running **Ubuntu 24.04 LTS**.
2. Configure the **Security Group** to allow inbound traffic:
   - Port `22` (SSH) — Restricted to your IP.
   - Port `80` (HTTP) — Anywhere (`0.0.0.0/0`).
   - Port `443` (HTTPS) — Anywhere (`0.0.0.0/0`).
3. Allocate and associate an **Elastic IP** to the instance so its public IP remains permanent across reboots.
4. Point your domain or subdomain DNS (e.g. `api.yourdomain.com`) to the Elastic IP (A record).

---

## 2. Option A: Running with Docker (Recommended)

1. SSH into your EC2 instance:
   ```bash
   ssh -i your-key.pem ubuntu@<ELASTIC_IP>
   ```

2. Install Docker and Docker Compose:
   ```bash
   sudo apt-get update
   sudo apt-get install -y docker.io docker-compose-v2
   sudo usermod -aG docker ubuntu
   ```

3. Clone your repository:
   ```bash
   git clone https://github.com/your-username/ChatApp.git
   cd ChatApp/backend
   ```

4. Create your `.env` file with your production secrets:
   ```bash
   cp .env.example .env
   nano .env
   ```

5. Build and run using the included [`backend/Dockerfile`](./backend/Dockerfile):
   ```bash
   docker build -t private-chat-backend .
   docker run -d --restart unless-stopped --name chat-backend --env-file .env -p 8000:8000 private-chat-backend
   ```

---

## 3. Option B: Running with systemd and Uvicorn

1. Install Python 3.12 and venv:
   ```bash
   sudo apt-get update && sudo apt-get install -y python3 python3-venv python3-pip
   ```

2. Set up the virtual environment:
   ```bash
   cd /home/ubuntu/ChatApp/backend
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -r requirements.txt
   ```

3. Create a systemd service file `/etc/systemd/system/chat-backend.service`:
   ```ini
   [Unit]
   Description=Private Chat FastAPI Backend
   After=network.target

   [Service]
   User=ubuntu
   WorkingDirectory=/home/ubuntu/ChatApp/backend
   EnvironmentFile=/home/ubuntu/ChatApp/backend/.env
   ExecStart=/home/ubuntu/ChatApp/backend/.venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000
   Restart=always
   RestartSec=5

   [Install]
   WantedBy=multi-user.target
   ```

4. Enable and start the service:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now chat-backend
   sudo systemctl status chat-backend
   ```

---

## 4. Reverse Proxy with Nginx & Free SSL (Let's Encrypt)

1. Install Nginx and Certbot:
   ```bash
   sudo apt-get install -y nginx certbot python3-certbot-nginx
   ```

2. Create `/etc/nginx/sites-available/chat-backend`:
   ```nginx
   server {
       server_name api.yourdomain.com;

       location / {
           proxy_pass http://127.0.0.1:8000;
           proxy_http_version 1.1;
           proxy_set_header Upgrade $http_upgrade;
           proxy_set_header Connection "upgrade";
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto $scheme;
           proxy_read_timeout 86400;
       }
   }
   ```

3. Enable the site and obtain SSL:
   ```bash
   sudo ln -s /etc/nginx/sites-available/chat-backend /etc/nginx/sites-enabled/
   sudo nginx -t && sudo systemctl reload nginx
   sudo certbot --nginx -d api.yourdomain.com
   ```

4. Update `ALLOWED_ORIGINS` in your backend `.env` to include your Vercel URL.
5. In your GitHub Actions or Vercel settings, update `API_BASE_URL` to `https://api.yourdomain.com` and `WS_BASE_URL` to `wss://api.yourdomain.com/ws`.
