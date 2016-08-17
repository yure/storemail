kill $(cat ~/storemail_api.pid);
starman --pid ~/storemail_api.pid --listen :5001 --access-log /home/storemail/storemail_access.log --error-log /home/storemail/storemail_error.log  --workers 5 /home/storemail/storemail/bin/app.pl --daemonize;
