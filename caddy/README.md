#STEP-BY-STEP

# Login as user admin (1000:1000) into Home-Directory
cd $HOME
# Clone the Repository
git clone https://github.com/ffuhrnew/opencloud-compose/
# Change into the repos directory
cd opencloud-compose
# Make a copy of the central environmental file (here: .env.caddy)
cp .env.caddy .env
# Edit the .env file 
nano .env
# Select the docker-compose: - Option from the Caddy-Section (":caddy/docker-compose.caddy.yml"
# Edit the docker-compose.caddy.yml file
nano docker-compose.caddy.yml
# Fill in the API Key from cloudflare and your emailadress for acme dns challenge
# Install OpenCloud directly via:
docker compose up -d
# OR: Make an istallable stack from all the yml-Files
docker compose config >> stack.yml
# Import the content of stack.yml into portainer
# Start the stack in portainer
# while it is starting you can rush to:
cd /mnt 
sudo chown admin:admin -R docker
sudo chmod 755 -R docker
# Browse to 
https://YOURCOLLABORA.FQDN/browser/dist/admin/admin.html
# Login with Your credentials
# Brose to 
https://YOUROPENCLOUD.FQDN.de/
# Login with Your credentials
# Now everything shall work ...
