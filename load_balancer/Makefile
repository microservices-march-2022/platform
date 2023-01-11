start:
	nginx -c $(shell pwd)/nginx.conf

reload:
	nginx -c $(shell pwd)/nginx.conf -s reload

stop:
	nginx -c $(shell pwd)/nginx.conf -s stop

check:
	nginx -c $(shell pwd)/nginx.conf -t

quit:
	nginx -c $(shell pwd)/nginx.conf -s quit

check_running:
	-ps aux | grep nginx | grep -v grep

logs:
	tail -f /tmp/dev.log