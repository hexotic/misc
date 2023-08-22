# docker - docker compose install

```sh
sudo apt install -y curl htop git

curl -fsSL https://get.docker.com -o get-docker.sh

chmod u+x get-docker.sh
./get-docker.sh

# The group docker may not be created...
sudo newgrp docker
sudo usermod -aG docker chris
sudo systemctl start docker
sudo systemctl enable docker

sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# log out and log in
```

# Snippets
```sh
docker-compose logs -f -t agent
docker inspect -f "{{.State.Running}}" $CONTAINER_ID
docker inspect -f "{{.State.ExitCode}}" agent
docker inspect agent:latest | jq -r '.[0].Config.Labels.version' | tee /tmp/version.txt)
```
