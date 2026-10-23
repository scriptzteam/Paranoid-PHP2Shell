v=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
stamp=$(date +%Y%m%d-%H%M%S)

for file in /etc/php/"$v"/{apache2,cli}/php.ini; do
    sudo cp -a "$file" "$file.bak.$stamp" &&
    sudo sed -i 's/^[[:space:]]*;\?[[:space:]]*session\.upload_progress\.enabled[[:space:]]*=.*/session.upload_progress.enabled = 0/' "$file"
done

sudo systemctl restart apache2
