# komari-backup

## GitHub 备份所需变量

- GH_BACKUP_USER=your_github_username 
- GH_REPO=your_private_repo_name 
- GH_PAT=your_github_personal_access_token 
- GH_EMAIL=your_github_email@example.com

## 原镜像可选变量

- ADMIN_USERNAME=登录用户名
- ADMIN_PASSWORD=登录密码
- KOMARI_ENABLE_CLOUDFLARED=是否开启CF隧道，true/false，默认 false
- KOMARI_CLOUDFLARED_TOKEN=隧道token

## Docker 部署命令

```bash
docker run -d \
  --name komari \
  --restart unless-stopped \
  -p 25774:25774 \
  -v ./komari-data:/app/data \
  -e GH_BACKUP_USER="your_github_username" \
  -e GH_REPO="your_private_repo_name" \
  -e GH_PAT="your_github_personal_access_token" \
  -e GH_EMAIL="your_github_email@example.com" \
  -e ADMIN_USERNAME="yourusername" \
  -e ADMIN_PASSWORD="yourpassword" \
  # 【可选】如果你需要启用 Cloudflare Tunnel，请取消注释并填写以下两行
  # -e KOMARI_ENABLE_CLOUDFLARED="true" \
  # -e KOMARI_CLOUDFLARED_TOKEN="eyJxxxxx" \
  ghcr.io/yutian81/komari-backup:latest
```

或者使用仓库中的 `docker-copmose.yml` 来部署，命令：`docker compose up -d`

