#!/bin/bash

# ========= USER INPUTS =========
read -p "Enter new MariaDB Database Name: " dbname
read -p "Enter new MariaDB Root Password: " dbrootpwd
read -p "Enter new Frappe Site Name (e.g. mysite.local): " sitename
read -p "Enter new Site Admin Password: " adminpwd

# ========= INSTALL DEPENDENCIES =========
echo "⚙️ Installing system dependencies..."
sudo apt update
sudo apt install -y git python3-dev python3-pip python3-setuptools python3-distutils \
    python3-venv curl redis-server software-properties-common mariadb-server mariadb-client \
    libmysqlclient-dev xvfb libfontconfig wkhtmltopdf nginx supervisor build-essential \
    libssl-dev libffi-dev

# ========= NODE.JS & YARN via NVM =========
echo "📦 Installing Node.js and Yarn via NVM..."
export NVM_DIR="$HOME/.nvm"
if [ ! -d "$NVM_DIR" ]; then
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi

# Load nvm for current shell
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install Node.js LTS (v18 for ERPNext v15)
nvm install 18
nvm use 18
nvm alias default 18

# Install Yarn globally
npm install -g yarn

# ========= INSTALL BENCH =========
echo "📦 Installing Frappe Bench CLI inside venv..."
pip install --upgrade pip
pip install frappe-bench

# ========= CONFIGURE MARIADB ROOT PASSWORD =========
echo "🔐 Setting MariaDB root password..."
sudo service mysql stop
sudo mysqld_safe --skip-grant-tables &

sleep 5

mysql -u root <<MYSQL_SCRIPT
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '$dbrootpwd';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

sudo pkill -f mysqld_safe
sleep 3
sudo service mysql start

export MYSQL_ROOT_PASSWORD=$dbrootpwd

# ========= CREATE Frappe Bench =========
if [ ! -d "frappe-bench" ]; then
  echo "🚀 Initializing Frappe bench..."
  bench init frappe-bench --frappe-branch version-15 --python "$(which python3)"
fi

cd frappe-bench

# ========= CREATE Frappe Site =========
echo "🌐 Creating site: $sitename"
bench new-site $sitename --mariadb-root-password $dbrootpwd --admin-password $adminpwd --db-name $dbname


# ========= CREATE DB USER & GRANT PERMISSIONS =========
echo "🔐 Creating database user and granting access..."
mysql -u root -p$dbrootpwd <<MYSQL_SCRIPT
CREATE USER IF NOT EXISTS '${sitename}_user'@'localhost' IDENTIFIED BY '${dbrootpwd}';
GRANT ALL PRIVILEGES ON \`${dbname}\`.* TO '${sitename}_user'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# ========= DONE =========
echo "✅ Setup Complete!"
echo "Site: $sitename"
echo "Database: $dbname"
echo "Admin Password: $adminpwd"
echo "DB User: ${sitename}_user"
echo "DB Password: $dbrootpwd"

# ========= START SERVER =========
echo "🚀 Starting Frappe development server..."
bench start
