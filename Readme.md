Script that backups mysql databases, it allows to compress with LZMA and encrypt with OpenSSL RSA

== Requirements == 

gem install micro-optparse


== Examples ==


ruby backup.rb -v --database=mydb --dump-options="--no-create-info" --skip-table="logs" --db-username=root --db-password="pass" --rsa-password="zxcvb"


ruby backup.rb -v --all-databases --db-username=root --db-password="pass" --rsa-password="zxcvb"


